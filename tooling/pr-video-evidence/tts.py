"""Human-sounding text-to-speech synthesis for PR verification videos.

Provider priority (natural neural speech first — never silently degrades to robotic speech):
1. ``kokoro`` (default): Full-precision FP32 local neural TTS (``kokoro-v1.0.onnx``) with
   SHA-256 verified weights, natural prosodic sentence/clause pauses, voice blending
   (e.g. ``af_heart:0.65+af_bella:0.35``), empirically verified spoken technical-term
   normalization, and broadcast voice mastering (-16 LUFS, zero clipping).
2. ``macos-say`` (macOS local fallback using natural/enhanced system voices).
3. ``openai`` (optional approved cloud neural fallback, enabled only when explicitly
   requested via ``--tts-provider openai`` with ``OPENAI_API_KEY``).
4. ``espeak-ng`` (explicit emergency offline fallback only — never chosen silently by ``auto``).
"""

from __future__ import annotations

from dataclasses import dataclass
import hashlib
import inspect
import json
import math
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tempfile
import urllib.request
import wave

from evidence import scan_for_secrets


KOKORO_MODELS: dict[str, dict[str, str]] = {
    "fp32": {
        "filename": "kokoro-v1.0.onnx",
        "url": (
            "https://github.com/thewh1teagle/kokoro-onnx/releases/download/"
            "model-files-v1.0/kokoro-v1.0.onnx"
        ),
        "sha256": "7d5df8ecf7d4b1878015a32686053fd0eebe2bc377234608764cc0ef3636a6c5",
    },
    "int8": {
        "filename": "kokoro-v1.0.int8.onnx",
        "url": (
            "https://github.com/thewh1teagle/kokoro-onnx/releases/download/"
            "model-files-v1.0/kokoro-v1.0.int8.onnx"
        ),
        "sha256": "6e742170d309016e5891a994e1ce1559c702a2ccd0075e67ef7157974f6406cb",
    },
}

KOKORO_VOICES_URL = (
    "https://github.com/thewh1teagle/kokoro-onnx/releases/download/"
    "model-files-v1.0/voices-v1.0.bin"
)
KOKORO_VOICES_SHA256 = "bca610b8308e8d99f32e6fe4197e7ec01679264efed0cac9140fe9c29f1fbf7d"

# Warm, natural Grade-A neural blend (af_heart + af_bella) at calm conversational pace
DEFAULT_KOKORO_VOICE = "af_heart:0.65+af_bella:0.35"
DEFAULT_KOKORO_PRECISION = "fp32"
DEFAULT_KOKORO_SPEED = 0.98
DEFAULT_SENTENCE_PAUSE = 0.30
DEFAULT_CLAUSE_PAUSE = 0.14

ROBOTIC_PROVIDERS = {"espeak-ng", "espeak"}

# Empirically G2P-verified spoken-only pronunciation fixes for Kokoro/local TTS.
# Terms Kokoro already phonemizes accurately natively (AI, API/APIs, URL/URLs, UI/UIs,
# macOS, iOS, iPadOS, HTTP, JSON, MP4, DOM, SHA) are intentionally left untouched.
_SPEECH_REPLACEMENTS: tuple[tuple[re.Pattern[str], str], ...] = (
    (re.compile(r"\bHTTP\s+404\b"), "HTTP four oh four"),
    (re.compile(r"\bHTTP\s+200\b"), "HTTP two hundred"),
    (re.compile(r"\bHTTP\s+500\b"), "HTTP five hundred"),
    (re.compile(r"\bH\.264\b", re.IGNORECASE), "H two sixty four"),
    (re.compile(r"\b1920\s*[x×]\s*1080\b", re.IGNORECASE), "ten eighty P"),
    (re.compile(r"\bAAC\b"), "A.A.C."),
    (re.compile(r"\bCLIs\b"), "C L eyes"),
    (re.compile(r"\bCLI\b"), "C L I"),
    (re.compile(r"\bCI\b"), "C I"),
    (re.compile(r"\bONNX\b"), "onyx"),
    (re.compile(r"\bTTS\b"), "text to speech"),
    (re.compile(r"\bCTA\b"), "call to action"),
    (re.compile(r"\bPRs\b"), "pull requests"),
    (re.compile(r"\bPR\b"), "pull request"),
    (re.compile(r"\bDevX\b"), "dev ex"),
    (re.compile(r"\bAGENTS\.md\b"), "agents dot M D"),
    (re.compile(r"\bSKILL\.md\b"), "skill dot M D"),
    (re.compile(r"\s*->\s*|\s*→\s*"), " to "),
    (re.compile(r"\s*·\s*"), ", "),
)


def prepare_speech_text(text: str, *, provider: str = "kokoro") -> str:
    """Normalize known technical G2P edge cases for natural spoken delivery.

    Captions and transcripts always retain the original verbatim ``text``.
    Cloud neural models (``openai``) handle technical notation natively and only
    receive arrow/bullet cleanup.
    """
    spoken = " ".join(text.split())
    if provider == "openai":
        spoken = re.sub(r"\s*->\s*|\s*→\s*", " to ", spoken)
        spoken = re.sub(r"\s*·\s*", ", ", spoken)
        return " ".join(spoken.split())

    for pattern, replacement in _SPEECH_REPLACEMENTS:
        spoken = pattern.sub(replacement, spoken)
    return " ".join(spoken.split())


@dataclass(frozen=True)
class SynthesizedSegment:
    """Result of synthesizing one narration segment to a mastered local WAV file."""

    index: int
    text: str
    wav_path: Path
    duration_seconds: float
    provider: str
    voice: str
    precision: str = "default"
    human_grade: bool = True


def wav_duration_seconds(path: Path) -> float:
    """Return exact duration in seconds of a WAV file."""
    with wave.open(str(path), "rb") as handle:
        frames = handle.getnframes()
        rate = handle.getframerate()
        if rate <= 0:
            raise ValueError(f"Invalid WAV frame rate {rate} in {path}")
        return frames / float(rate)


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _download_if_missing(
    url: str,
    destination: Path,
    expected_sha256: str | None = None,
    *,
    allow_download: bool = True,
) -> Path:
    """Download ``url`` into ``destination`` atomically and verify pinned SHA-256 digest."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        if not expected_sha256 or _sha256_file(destination) == expected_sha256:
            return destination
        if not allow_download:
            raise RuntimeError(
                f"Cached file {destination} failed SHA-256 verification and downloads are disabled"
            )
        destination.unlink(missing_ok=True)

    if not allow_download:
        raise RuntimeError(
            f"Required model file {destination} is not cached and downloads are disabled"
        )

    fd, tmp_name = tempfile.mkstemp(dir=str(destination.parent), prefix=f".{destination.name}.", suffix=".part")
    tmp_path = Path(tmp_name)
    try:
        with os.fdopen(fd, "wb") as out, urllib.request.urlopen(url, timeout=120) as resp:
            shutil.copyfileobj(resp, out)
        if expected_sha256:
            actual = _sha256_file(tmp_path)
            if actual != expected_sha256:
                raise RuntimeError(
                    f"SHA-256 mismatch for {destination.name}: expected {expected_sha256}, got {actual}"
                )
        os.replace(tmp_path, destination)
        return destination
    except Exception:
        tmp_path.unlink(missing_ok=True)
        raise


def _kokoro_cache_dir() -> Path:
    override = os.environ.get("KOKORO_CACHE_DIR")
    if override:
        return Path(override).expanduser()
    return Path.home() / ".cache" / "kokoro-onnx"


def _kokoro_available(precision: str = DEFAULT_KOKORO_PRECISION, allow_download: bool = True) -> tuple[bool, str]:
    try:
        import kokoro_onnx  # noqa: F401
        import soundfile  # noqa: F401
    except ImportError as exc:
        return False, f"Python package missing ({exc})"

    model_info = KOKORO_MODELS.get(precision)
    if not model_info:
        return False, f"Unsupported Kokoro precision '{precision}'"

    cache = _kokoro_cache_dir()
    model_path = cache / model_info["filename"]
    voices_path = cache / "voices-v1.0.bin"
    if model_path.exists() and voices_path.exists():
        return True, f"{precision} cached at {cache}"
    if not allow_download:
        return False, f"{precision} model weights not cached at {cache}"
    return True, f"package installed; {precision} weights will download to {cache}"


def parse_voice_blend(voice_spec: str) -> list[tuple[str, float]]:
    """Parse single voice ('af_heart') or weighted blend ('af_heart:0.65+af_bella:0.35')."""
    parts = [p.strip() for p in voice_spec.split("+") if p.strip()]
    if not parts:
        raise ValueError("Voice specification cannot be empty")
    parsed: list[tuple[str, float]] = []
    for part in parts:
        if ":" in part:
            raw_name, weight_str = part.split(":", 1)
            name = raw_name.strip()
            if not name:
                raise ValueError(f"Voice name cannot be empty in blend segment {part!r}")
            weight = float(weight_str)
            if not math.isfinite(weight) or weight <= 0.0:
                raise ValueError(f"Voice blend weight must be finite and > 0 (got {weight!r} for {name})")
            parsed.append((name, weight))
        else:
            parsed.append((part, 1.0))
    total = sum(w for _, w in parsed)
    if not math.isfinite(total) or total <= 0.0:
        raise ValueError(f"Invalid total voice blend weight: {total!r}")
    return [(name, w / total) for name, w in parsed]


class TTSEngine:
    """Unified human-first TTS interface (FP32 Kokoro ONNX, macOS say, OpenAI, explicit espeak-ng)."""

    def __init__(
        self,
        provider: str = "auto",
        voice: str | None = None,
        speed: float = DEFAULT_KOKORO_SPEED,
        precision: str = DEFAULT_KOKORO_PRECISION,
        allow_download: bool = True,
    ) -> None:
        self.requested_provider = provider
        self.speed = max(0.75, min(1.35, float(speed)))
        self.precision = precision.lower().strip()
        if self.precision not in KOKORO_MODELS:
            raise ValueError(f"Unsupported Kokoro precision: {precision!r} (choose 'fp32' or 'int8')")
        self.allow_download = allow_download
        self._kokoro_instance = None
        self.provider, self.voice = self._resolve_provider(provider, voice)
        if self.provider == "kokoro":
            # Validate voice/blend syntax eagerly before running expensive captures
            parse_voice_blend(self.voice)
        self.human_grade = self.provider not in ROBOTIC_PROVIDERS

    def _resolve_provider(self, requested: str, voice: str | None) -> tuple[str, str]:
        req = requested.lower().strip()
        if req == "kokoro":
            ok, reason = _kokoro_available(precision=self.precision, allow_download=self.allow_download)
            if not ok:
                raise RuntimeError(f"Kokoro TTS requested but unavailable: {reason}")
            return "kokoro", voice or DEFAULT_KOKORO_VOICE

        if req == "macos-say":
            if platform.system() != "Darwin" or not shutil.which("say"):
                raise RuntimeError("macOS 'say' TTS requested but not available on this host")
            return "macos-say", voice or "Samantha"

        if req == "espeak-ng":
            if not shutil.which("espeak-ng"):
                raise RuntimeError("espeak-ng requested but not installed")
            return "espeak-ng", voice or "en-us"

        if req == "openai":
            if not os.environ.get("OPENAI_API_KEY"):
                raise RuntimeError("OpenAI cloud TTS requested but OPENAI_API_KEY is not set")
            return "openai", voice or "coral"

        if req != "auto":
            raise ValueError(f"Unsupported TTS provider: {requested}")

        # Auto resolution: strictly human-grade neural/OS voices (never silently robotic espeak-ng).
        # Prefer cached requested precision -> cached alternate precision -> downloadable requested -> macos-say.
        cached_req, _ = _kokoro_available(precision=self.precision, allow_download=False)
        if cached_req:
            return "kokoro", voice or DEFAULT_KOKORO_VOICE

        alt_precision = "int8" if self.precision == "fp32" else "fp32"
        cached_alt, _ = _kokoro_available(precision=alt_precision, allow_download=False)
        if not self.allow_download and cached_alt:
            self.precision = alt_precision
            return "kokoro", voice or DEFAULT_KOKORO_VOICE

        dl_ok, _ = _kokoro_available(precision=self.precision, allow_download=self.allow_download)
        if dl_ok:
            return "kokoro", voice or DEFAULT_KOKORO_VOICE

        if platform.system() == "Darwin" and shutil.which("say"):
            return "macos-say", voice or "Samantha"
        raise RuntimeError(
            "No human-grade local TTS provider available. Install 'kokoro-onnx' + 'soundfile' "
            "(recommended FP32 neural TTS), or specify '--tts-provider openai' with OPENAI_API_KEY. "
            "Refusing to silently fall back to robotic espeak-ng (pass '--tts-provider espeak-ng "
            "--tts-fallback-reason \"<explanation>\"' explicitly only if unavoidable)."
        )

    def _get_kokoro(self):
        if self._kokoro_instance is None:
            from kokoro_onnx import Kokoro

            cache = _kokoro_cache_dir()
            model_info = KOKORO_MODELS[self.precision]
            try:
                model_path = _download_if_missing(
                    model_info["url"],
                    cache / model_info["filename"],
                    expected_sha256=model_info["sha256"],
                    allow_download=self.allow_download,
                )
                voices_path = _download_if_missing(
                    KOKORO_VOICES_URL,
                    cache / "voices-v1.0.bin",
                    expected_sha256=KOKORO_VOICES_SHA256,
                    allow_download=self.allow_download,
                )
            except Exception:
                # In auto mode, gracefully fall back to cached int8 weights if FP32 download fails offline
                alt_precision = "int8" if self.precision == "fp32" else "fp32"
                alt_cached, _ = _kokoro_available(precision=alt_precision, allow_download=False)
                if self.requested_provider.lower().strip() == "auto" and alt_cached:
                    self.precision = alt_precision
                    alt_info = KOKORO_MODELS[alt_precision]
                    model_path = _download_if_missing(
                        alt_info["url"],
                        cache / alt_info["filename"],
                        expected_sha256=alt_info["sha256"],
                        allow_download=False,
                    )
                    voices_path = _download_if_missing(
                        KOKORO_VOICES_URL,
                        cache / "voices-v1.0.bin",
                        expected_sha256=KOKORO_VOICES_SHA256,
                        allow_download=False,
                    )
                else:
                    raise
            self._kokoro_instance = Kokoro(str(model_path), str(voices_path))
        return self._kokoro_instance

    def _resolve_kokoro_voice_input(self, kokoro):
        blend = parse_voice_blend(self.voice)
        if len(blend) == 1:
            return blend[0][0]
        style = None
        for name, weight in blend:
            try:
                base_vec = kokoro.get_voice_style(name)
            except KeyError as exc:
                raise ValueError(f"Unknown Kokoro voice name {name!r} in blend {self.voice!r}") from exc
            weighted = base_vec * weight
            style = weighted if style is None else style + weighted
        if hasattr(style, "astype"):
            return style.astype("float32", copy=False)
        return style

    def synthesize(self, text: str, output_wav: Path, index: int = 0) -> SynthesizedSegment:
        """Synthesize human-sounding narration for ``text`` into a mastered 48kHz stereo WAV."""
        clean_caption_text = " ".join(text.split())
        if not clean_caption_text:
            raise ValueError(f"Narration segment {index} cannot be empty")

        spoken_text = prepare_speech_text(clean_caption_text, provider=self.provider)

        # Pre-flight secret scan on BOTH caption text and spoken text BEFORE any TTS call
        secret_hits = scan_for_secrets(clean_caption_text + "\n" + spoken_text)
        if secret_hits:
            raise RuntimeError(
                f"Refusing to synthesize narration segment {index} containing potential secret(s): "
                f"{', '.join(secret_hits)}"
            )

        output_wav.parent.mkdir(parents=True, exist_ok=True)
        raw_wav = output_wav.with_suffix(".raw.wav")
        try:
            if self.provider == "kokoro":
                self._synthesize_kokoro(spoken_text, raw_wav)
            elif self.provider == "macos-say":
                self._synthesize_macos_say(spoken_text, raw_wav)
            elif self.provider == "espeak-ng":
                self._synthesize_espeak(spoken_text, raw_wav)
            elif self.provider == "openai":
                self._synthesize_openai(spoken_text, raw_wav)
            else:
                raise ValueError(f"Unhandled TTS provider: {self.provider}")

            self._master_voice_wav(raw_wav, output_wav)
        finally:
            raw_wav.unlink(missing_ok=True)

        duration = wav_duration_seconds(output_wav)
        return SynthesizedSegment(
            index=index,
            text=clean_caption_text,
            wav_path=output_wav,
            duration_seconds=round(duration, 3),
            provider=self.provider,
            voice=self.voice,
            precision=self.precision if self.provider == "kokoro" else "native",
            human_grade=self.human_grade,
        )

    def _synthesize_kokoro(self, spoken_text: str, raw_wav: Path) -> None:
        import soundfile as sf

        kokoro = self._get_kokoro()
        voice_input = self._resolve_kokoro_voice_input(kokoro)
        kwargs: dict[str, object] = {
            "voice": voice_input,
            "speed": self.speed,
            "lang": "en-us",
        }
        # Only pass 0.6+ prosody kwargs when supported by the installed kokoro-onnx version
        sig_params = inspect.signature(kokoro.create).parameters
        if "trim" in sig_params:
            kwargs["trim"] = True
        if "sentence_pause" in sig_params:
            kwargs["sentence_pause"] = DEFAULT_SENTENCE_PAUSE
        if "clause_pause" in sig_params:
            kwargs["clause_pause"] = DEFAULT_CLAUSE_PAUSE

        samples, sample_rate = kokoro.create(spoken_text, **kwargs)
        sf.write(str(raw_wav), samples, sample_rate, subtype="PCM_16")

    def _synthesize_macos_say(self, spoken_text: str, raw_wav: Path) -> None:
        aiff_path = raw_wav.with_suffix(".aiff")
        wpm = str(int(round(170 * self.speed)))
        try:
            subprocess.run(
                ["say", "-v", self.voice, "-r", wpm, "-o", str(aiff_path), "-f", "-"],
                input=spoken_text,
                check=True,
                capture_output=True,
                text=True,
            )
            subprocess.run(
                ["ffmpeg", "-y", "-i", str(aiff_path), str(raw_wav)],
                check=True,
                capture_output=True,
                text=True,
            )
        finally:
            aiff_path.unlink(missing_ok=True)

    def _synthesize_espeak(self, spoken_text: str, raw_wav: Path) -> None:
        wpm = str(int(round(158 * self.speed)))
        subprocess.run(
            ["espeak-ng", "-v", self.voice, "-s", wpm, "-w", str(raw_wav), "--stdin"],
            input=spoken_text,
            check=True,
            capture_output=True,
            text=True,
        )

    def _synthesize_openai(self, spoken_text: str, raw_wav: Path) -> None:
        api_key = os.environ.get("OPENAI_API_KEY", "")
        if not api_key:
            raise RuntimeError("OPENAI_API_KEY is required for OpenAI TTS fallback")
        secret_hits = scan_for_secrets(spoken_text)
        if secret_hits:
            raise RuntimeError(
                f"Blocked outbound OpenAI TTS request containing potential secret(s): {', '.join(secret_hits)}"
            )
        model = os.environ.get("OPENAI_TTS_MODEL", "gpt-4o-mini-tts")
        body: dict[str, object] = {
            "model": model,
            "voice": self.voice,
            "input": spoken_text,
            "speed": self.speed,
            "response_format": "wav",
        }
        # Only pass `instructions` for models that support it (tts-1 / tts-1-hd reject/ignore it)
        if not model.startswith("tts-1"):
            body["instructions"] = (
                "Speak like a calm, experienced software engineer walking a teammate through a "
                "pull request verification recording. Natural conversational cadence, crisp "
                "enunciation, slight pauses between sentences, zero promotional hype."
            )
        payload = json.dumps(body).encode("utf-8")
        req = urllib.request.Request(
            "https://api.openai.com/v1/audio/speech",
            data=payload,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=60) as resp, raw_wav.open("wb") as out:
            shutil.copyfileobj(resp, out)

    @staticmethod
    def _master_voice_wav(source: Path, dest: Path) -> None:
        """Master voice to broadcast screencast clarity (-16 LUFS, de-rumbled, zero clicks)."""
        if not shutil.which("ffmpeg"):
            shutil.copyfile(source, dest)
            return
        raw_dur = wav_duration_seconds(source)
        filters = [
            "highpass=f=70",
            "acompressor=threshold=-20dB:ratio=2.4:attack=15:release=180:makeup=1.5",
            "loudnorm=I=-16:TP=-1.5:LRA=11",
        ]
        # Clamp fade durations so very short clips never overlap or attenuate to silence
        if raw_dur >= 0.06:
            fade_in = min(0.02, raw_dur * 0.25)
            fade_out = min(0.025, raw_dur * 0.25)
            fade_out_start = max(0.0, raw_dur - fade_out)
            filters.append(f"afade=t=in:st=0:d={fade_in:.3f}")
            filters.append(f"afade=t=out:st={fade_out_start:.3f}:d={fade_out:.3f}")

        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-i",
                str(source),
                "-af",
                ",".join(filters),
                "-ar",
                "48000",
                "-ac",
                "2",
                "-c:a",
                "pcm_s16le",
                str(dest),
            ],
            check=True,
            capture_output=True,
            text=True,
        )


def doctor_tts_status() -> dict[str, object]:
    """Return diagnostic status of all supported TTS backends."""
    fp32_ok, fp32_detail = _kokoro_available(precision="fp32", allow_download=False)
    int8_ok, int8_detail = _kokoro_available(precision="int8", allow_download=False)
    return {
        "kokoro_fp32_cached": fp32_ok,
        "kokoro_fp32_detail": fp32_detail,
        "kokoro_int8_cached": int8_ok,
        "kokoro_int8_detail": int8_detail,
        "default_voice": DEFAULT_KOKORO_VOICE,
        "macos_say": platform.system() == "Darwin" and bool(shutil.which("say")),
        "espeak_ng_emergency_only": bool(shutil.which("espeak-ng")),
        "openai_fallback_configured": bool(os.environ.get("OPENAI_API_KEY")),
    }
