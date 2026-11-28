"""Text-to-speech synthesis for PR verification videos.

Provider priority:
1. ``kokoro`` (default): Local neural TTS via ``kokoro-onnx`` + SHA-256 verified ONNX weights.
2. ``macos-say`` (macOS local fallback) or ``espeak-ng`` (Linux local fallback).
3. ``openai`` (optional approved cloud fallback, enabled only when explicitly requested
   via ``--tts-provider openai`` with ``OPENAI_API_KEY``).
"""

from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
import urllib.request
import wave

from evidence import scan_for_secrets


KOKORO_MODEL_URL = (
    "https://github.com/thewh1teagle/kokoro-onnx/releases/download/"
    "model-files-v1.0/kokoro-v1.0.int8.onnx"
)
KOKORO_MODEL_SHA256 = "6e742170d309016e5891a994e1ce1559c702a2ccd0075e67ef7157974f6406cb"

KOKORO_VOICES_URL = (
    "https://github.com/thewh1teagle/kokoro-onnx/releases/download/"
    "model-files-v1.0/voices-v1.0.bin"
)
KOKORO_VOICES_SHA256 = "bca610b8308e8d99f32e6fe4197e7ec01679264efed0cac9140fe9c29f1fbf7d"

DEFAULT_KOKORO_VOICE = "af_heart"
DEFAULT_KOKORO_SPEED = 1.03


@dataclass(frozen=True)
class SynthesizedSegment:
    """Result of synthesizing one narration segment to a local WAV file."""

    index: int
    text: str
    wav_path: Path
    duration_seconds: float
    provider: str
    voice: str


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


def _download_if_missing(url: str, destination: Path, expected_sha256: str | None = None) -> Path:
    """Download ``url`` into ``destination`` atomically and verify pinned SHA-256 digest."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        if not expected_sha256 or _sha256_file(destination) == expected_sha256:
            return destination
        # Cached artifact is corrupted/truncated; re-download cleanly
        destination.unlink(missing_ok=True)

    fd, tmp_name = tempfile.mkstemp(dir=str(destination.parent), prefix=f".{destination.name}.", suffix=".part")
    tmp_path = Path(tmp_name)
    try:
        with os.fdopen(fd, "wb") as out, urllib.request.urlopen(url, timeout=60) as resp:
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


def _kokoro_available(allow_download: bool = True) -> tuple[bool, str]:
    try:
        import kokoro_onnx  # noqa: F401
        import soundfile  # noqa: F401
    except ImportError as exc:
        return False, f"Python package missing ({exc})"

    cache = _kokoro_cache_dir()
    model_path = cache / "kokoro-v1.0.int8.onnx"
    voices_path = cache / "voices-v1.0.bin"
    if model_path.exists() and voices_path.exists():
        return True, f"cached at {cache}"
    if not allow_download:
        return False, f"model weights not cached at {cache}"
    return True, f"package installed; weights will download to {cache}"


class TTSEngine:
    """Unified TTS interface supporting Kokoro ONNX, local fallbacks, and OpenAI."""

    def __init__(
        self,
        provider: str = "auto",
        voice: str | None = None,
        speed: float = DEFAULT_KOKORO_SPEED,
        allow_download: bool = True,
    ) -> None:
        self.requested_provider = provider
        self.speed = max(0.6, min(1.8, float(speed)))
        self.allow_download = allow_download
        self._kokoro_instance = None
        self.provider, self.voice = self._resolve_provider(provider, voice)

    def _resolve_provider(self, requested: str, voice: str | None) -> tuple[str, str]:
        req = requested.lower().strip()
        if req == "kokoro":
            ok, reason = _kokoro_available(allow_download=self.allow_download)
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
            return "openai", voice or "alloy"

        if req != "auto":
            raise ValueError(f"Unsupported TTS provider: {requested}")

        # Auto resolution: Kokoro -> macOS say -> espeak-ng
        ok, _ = _kokoro_available(allow_download=self.allow_download)
        if ok:
            return "kokoro", voice or DEFAULT_KOKORO_VOICE
        if platform.system() == "Darwin" and shutil.which("say"):
            return "macos-say", voice or "Samantha"
        if shutil.which("espeak-ng"):
            return "espeak-ng", voice or "en-us"
        raise RuntimeError(
            "No local TTS provider available. Install 'kokoro-onnx' + 'soundfile' "
            "(recommended), or install 'espeak-ng', or specify '--tts-provider openai'."
        )

    def _get_kokoro(self):
        if self._kokoro_instance is None:
            from kokoro_onnx import Kokoro

            cache = _kokoro_cache_dir()
            model_path = _download_if_missing(
                KOKORO_MODEL_URL,
                cache / "kokoro-v1.0.int8.onnx",
                expected_sha256=KOKORO_MODEL_SHA256,
            )
            voices_path = _download_if_missing(
                KOKORO_VOICES_URL,
                cache / "voices-v1.0.bin",
                expected_sha256=KOKORO_VOICES_SHA256,
            )
            self._kokoro_instance = Kokoro(str(model_path), str(voices_path))
        return self._kokoro_instance

    def synthesize(self, text: str, output_wav: Path, index: int = 0) -> SynthesizedSegment:
        """Synthesize spoken narration for ``text`` into a 48kHz stereo PCM WAV file."""
        clean_text = " ".join(text.split())
        if not clean_text:
            raise ValueError(f"Narration segment {index} cannot be empty")

        # Pre-flight secret scan BEFORE any TTS call (especially cloud providers)
        secret_hits = scan_for_secrets(clean_text)
        if secret_hits:
            raise RuntimeError(
                f"Refusing to synthesize narration segment {index} containing potential secret(s): "
                f"{', '.join(secret_hits)}"
            )

        output_wav.parent.mkdir(parents=True, exist_ok=True)
        raw_wav = output_wav.with_suffix(".raw.wav")
        try:
            if self.provider == "kokoro":
                self._synthesize_kokoro(clean_text, raw_wav)
            elif self.provider == "macos-say":
                self._synthesize_macos_say(clean_text, raw_wav)
            elif self.provider == "espeak-ng":
                self._synthesize_espeak(clean_text, raw_wav)
            elif self.provider == "openai":
                self._synthesize_openai(clean_text, raw_wav)
            else:
                raise ValueError(f"Unhandled TTS provider: {self.provider}")

            self._normalize_wav(raw_wav, output_wav)
        finally:
            raw_wav.unlink(missing_ok=True)

        duration = wav_duration_seconds(output_wav)
        return SynthesizedSegment(
            index=index,
            text=clean_text,
            wav_path=output_wav,
            duration_seconds=round(duration, 3),
            provider=self.provider,
            voice=self.voice,
        )

    def _synthesize_kokoro(self, text: str, raw_wav: Path) -> None:
        import soundfile as sf

        kokoro = self._get_kokoro()
        samples, sample_rate = kokoro.create(
            text,
            voice=self.voice,
            speed=self.speed,
            lang="en-us",
        )
        sf.write(str(raw_wav), samples, sample_rate, subtype="PCM_16")

    def _synthesize_macos_say(self, text: str, raw_wav: Path) -> None:
        aiff_path = raw_wav.with_suffix(".aiff")
        wpm = str(int(round(175 * self.speed)))
        try:
            subprocess.run(
                ["say", "-v", self.voice, "-r", wpm, "-o", str(aiff_path), "-f", "-"],
                input=text,
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

    def _synthesize_espeak(self, text: str, raw_wav: Path) -> None:
        wpm = str(int(round(160 * self.speed)))
        subprocess.run(
            ["espeak-ng", "-v", self.voice, "-s", wpm, "-w", str(raw_wav), "--stdin"],
            input=text,
            check=True,
            capture_output=True,
            text=True,
        )

    def _synthesize_openai(self, text: str, raw_wav: Path) -> None:
        api_key = os.environ.get("OPENAI_API_KEY", "")
        if not api_key:
            raise RuntimeError("OPENAI_API_KEY is required for OpenAI TTS fallback")
        secret_hits = scan_for_secrets(text)
        if secret_hits:
            raise RuntimeError(
                f"Blocked outbound OpenAI TTS request containing potential secret(s): {', '.join(secret_hits)}"
            )
        payload = json.dumps(
            {
                "model": os.environ.get("OPENAI_TTS_MODEL", "gpt-4o-mini-tts"),
                "voice": self.voice,
                "input": text,
                "speed": self.speed,
                "response_format": "wav",
            }
        ).encode("utf-8")
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
    def _normalize_wav(source: Path, dest: Path) -> None:
        if not shutil.which("ffmpeg"):
            shutil.copyfile(source, dest)
            return
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-i",
                str(source),
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
    kokoro_ok, kokoro_detail = _kokoro_available(allow_download=False)
    return {
        "kokoro_cached": kokoro_ok,
        "kokoro_detail": kokoro_detail,
        "macos_say": platform.system() == "Darwin" and bool(shutil.which("say")),
        "espeak_ng": bool(shutil.which("espeak-ng")),
        "openai_fallback_configured": bool(os.environ.get("OPENAI_API_KEY")),
    }
