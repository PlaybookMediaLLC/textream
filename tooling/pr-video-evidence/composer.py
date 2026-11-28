"""FFmpeg video/audio composer, SRT/WebVTT caption generator, and ffprobe verifier.

Renders final engineering verification MP4 recordings:
- H.264 video (libx264, yuv420p, +faststart)
- AAC stereo audio (48kHz, 160kbps)
- Default 1920x1080 @ 30 fps
- Legible burned-in captions synchronized to spoken narration
- No music, no decorative transitions, no promotional overlays
"""

from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import textwrap
from typing import Any


DEFAULT_WIDTH = 1920
DEFAULT_HEIGHT = 1080
DEFAULT_FPS = 30


@dataclass(frozen=True)
class CaptionCue:
    """Timed narration segment for audio track assembly and SRT/VTT captions."""

    index: int
    start_seconds: float
    end_seconds: float
    text: str
    wav_path: Path


@dataclass(frozen=True)
class VideoProbe:
    """Verified ffprobe stream parameters of the final rendered MP4."""

    codec: str
    audio_codec: str
    width: int
    height: int
    fps: float
    duration_seconds: float
    audio_duration_seconds: float
    size_bytes: int
    sha256: str


def _parse_duration(value: Any, fallback: float = 0.0) -> float:
    """Safely parse ffprobe duration strings, gracefully handling 'N/A' or empty values."""
    if value is None:
        return fallback
    text = str(value).strip()
    if not text or text.upper() == "N/A":
        return fallback
    try:
        parsed = float(text)
        return parsed if parsed >= 0.0 else fallback
    except ValueError:
        return fallback


def _probe_raw_duration(raw_video_path: Path) -> float:
    """Return duration of raw capture video in seconds (handles WebM 'N/A' headers)."""
    if not shutil.which("ffprobe"):
        raise RuntimeError("ffprobe is required to inspect captured video duration")

    # Try container format duration first
    res = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(raw_video_path),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    dur = _parse_duration(res.stdout, fallback=0.0)
    if dur > 0.0:
        return dur

    # Fallback: probe stream duration or tags (common for Chromium WebM captures)
    res_stream = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=duration:stream_tags=DURATION",
            "-of",
            "json",
            str(raw_video_path),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    data = json.loads(res_stream.stdout or "{}")
    streams = data.get("streams") or []
    if streams:
        stream_dur = _parse_duration(streams[0].get("duration"), fallback=0.0)
        if stream_dur > 0.0:
            return stream_dur
        tag_dur = str((streams[0].get("tags") or {}).get("DURATION") or "").strip()
        if ":" in tag_dur:
            parts = tag_dur.split(":")
            if len(parts) == 3:
                try:
                    return int(parts[0]) * 3600.0 + int(parts[1]) * 60.0 + float(parts[2])
                except ValueError:
                    pass
    return 0.0


def _format_srt_time(seconds: float) -> str:
    ms_total = max(0, int(round(seconds * 1000)))
    hours, rem = divmod(ms_total, 3_600_000)
    minutes, rem = divmod(rem, 60_000)
    secs, ms = divmod(rem, 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d},{ms:03d}"


def _format_vtt_time(seconds: float) -> str:
    return _format_srt_time(seconds).replace(",", ".")


def _wrap_caption(text: str, max_chars: int = 68) -> list[str]:
    """Split a long spoken sentence into readable 1-2 line caption chunks."""
    words = text.split()
    if not words:
        return []
    lines = textwrap.wrap(" ".join(words), width=max_chars)
    chunks: list[str] = []
    for i in range(0, len(lines), 2):
        chunks.append("\n".join(lines[i : i + 2]))
    return chunks


def expand_caption_chunks(cues: list[CaptionCue]) -> list[tuple[float, float, str]]:
    """Split long cues proportionally into 2-line max display chunks for legibility."""
    expanded: list[tuple[float, float, str]] = []
    for cue in cues:
        chunks = _wrap_caption(cue.text)
        if not chunks:
            continue
        if len(chunks) == 1:
            expanded.append((cue.start_seconds, cue.end_seconds, chunks[0]))
            continue
        total_chars = sum(len(c) for c in chunks)
        span = max(0.2, cue.end_seconds - cue.start_seconds)
        cursor = cue.start_seconds
        for idx, chunk in enumerate(chunks):
            weight = len(chunk) / float(total_chars)
            next_cursor = cue.end_seconds if idx == len(chunks) - 1 else cursor + span * weight
            expanded.append((cursor, next_cursor, chunk))
            cursor = next_cursor
    return expanded


def write_captions_and_transcript(
    cues: list[CaptionCue],
    srt_path: Path,
    vtt_path: Path,
    transcript_path: Path,
) -> None:
    """Write SRT, WebVTT, and plain-text timestamped transcript files."""
    expanded = expand_caption_chunks(cues)

    srt_lines: list[str] = []
    vtt_lines: list[str] = ["WEBVTT", ""]
    for idx, (start_s, end_s, chunk) in enumerate(expanded, start=1):
        srt_lines.extend(
            [
                str(idx),
                f"{_format_srt_time(start_s)} --> {_format_srt_time(end_s)}",
                chunk,
                "",
            ]
        )
        vtt_lines.extend(
            [
                f"{_format_vtt_time(start_s)} --> {_format_vtt_time(end_s)}",
                chunk,
                "",
            ]
        )

    transcript_lines = [
        f"[{_format_vtt_time(cue.start_seconds)} - {_format_vtt_time(cue.end_seconds)}] {cue.text}"
        for cue in cues
    ]

    srt_path.write_text("\n".join(srt_lines), encoding="utf-8")
    vtt_path.write_text("\n".join(vtt_lines), encoding="utf-8")
    transcript_path.write_text("\n".join(transcript_lines) + "\n", encoding="utf-8")


def _write_ass_subtitles(cues: list[CaptionCue], ass_path: Path, width: int, height: int) -> None:
    """Generate clean, high-contrast ASS subtitles for crisp ffmpeg burn-in."""
    expanded = expand_caption_chunks(cues)

    def fmt_ass(seconds: float) -> str:
        cs_total = max(0, int(round(seconds * 100)))
        hours, rem = divmod(cs_total, 360_000)
        minutes, rem = divmod(rem, 6_000)
        secs, cs = divmod(rem, 100)
        return f"{hours}:{minutes:02d}:{secs:02d}.{cs:02d}"

    header = textwrap.dedent(
        f"""\
        [Script Info]
        ScriptType: v4.00+
        PlayResX: {width}
        PlayResY: {height}
        ScaledBorderAndShadow: yes

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: Default,Sans,34,&H00F8FAFC,&H00F8FAFC,&H99090D16,&H99090D16,0,0,0,0,100,100,0,0,3,14,0,2,96,96,34,1

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        """
    )
    lines = [header.rstrip()]
    for start_s, end_s, chunk in expanded:
        escaped = (
            chunk.replace("\\", "\\\\")
            .replace("{", "\\{")
            .replace("}", "\\}")
            .replace("\n", "\\N")
        )
        lines.append(f"Dialogue: 0,{fmt_ass(start_s)},{fmt_ass(end_s)},Default,,0,0,0,,{escaped}")
    ass_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def assemble_narration_track(cues: list[CaptionCue], output_wav: Path, total_duration: float) -> Path:
    """Place each synthesized narration WAV at its exact cue start timestamp."""
    if not shutil.which("ffmpeg"):
        raise RuntimeError("ffmpeg is required to assemble narration audio")
    if not cues:
        raise ValueError("At least one narration cue is required")

    cmd: list[str] = ["ffmpeg", "-y"]
    for cue in cues:
        cmd.extend(["-i", str(cue.wav_path)])

    filter_parts: list[str] = []
    mix_labels: list[str] = []
    for idx, cue in enumerate(cues):
        delay_ms = max(0, int(round(cue.start_seconds * 1000)))
        label = f"a{idx}"
        filter_parts.append(f"[{idx}:a]adelay={delay_ms}|{delay_ms},aresample=48000[{label}]")
        mix_labels.append(f"[{label}]")

    mix_expr = (
        f"{''.join(mix_labels)}amix=inputs={len(cues)}:duration=longest:normalize=0,"
        f"apad=whole_dur={total_duration:.3f},atrim=0:{total_duration:.3f}[aout]"
    )
    filter_parts.append(mix_expr)

    cmd.extend(
        [
            "-filter_complex",
            ";".join(filter_parts),
            "-map",
            "[aout]",
            "-ar",
            "48000",
            "-ac",
            "2",
            "-c:a",
            "pcm_s16le",
            str(output_wav),
        ]
    )
    subprocess.run(cmd, check=True, capture_output=True, text=True)
    return output_wav


def probe_video(video_path: Path) -> VideoProbe:
    """Inspect final MP4 via ffprobe and compute SHA-256."""
    if not shutil.which("ffprobe"):
        raise RuntimeError("ffprobe is required to verify rendered MP4 output")

    result = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_streams",
            "-show_format",
            "-of",
            "json",
            str(video_path),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    data = json.loads(result.stdout)
    streams = data.get("streams", [])
    v_stream = next((s for s in streams if s.get("codec_type") == "video"), None)
    a_stream = next((s for s in streams if s.get("codec_type") == "audio"), None)
    if v_stream is None:
        raise RuntimeError(f"Rendered video {video_path} is missing a video stream")
    if a_stream is None:
        raise RuntimeError(f"Rendered video {video_path} is missing an audio stream")

    rate_str = str(v_stream.get("avg_frame_rate") or v_stream.get("r_frame_rate") or "0/1")
    num_str, _, den_str = rate_str.partition("/")
    den_val = _parse_duration(den_str or "1", fallback=1.0)
    fps = _parse_duration(num_str, fallback=0.0) / den_val if den_val > 0.0 else 0.0

    fmt_dur = _parse_duration(
        data.get("format", {}).get("duration"),
        fallback=_parse_duration(v_stream.get("duration"), fallback=0.0),
    )
    aud_dur = _parse_duration(a_stream.get("duration"), fallback=fmt_dur)

    digest = hashlib.sha256()
    with video_path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)

    return VideoProbe(
        codec=str(v_stream.get("codec_name", "")),
        audio_codec=str(a_stream.get("codec_name", "")),
        width=int(v_stream.get("width", 0)),
        height=int(v_stream.get("height", 0)),
        fps=round(fps, 2),
        duration_seconds=round(fmt_dur, 3),
        audio_duration_seconds=round(aud_dur, 3),
        size_bytes=video_path.stat().st_size,
        sha256=digest.hexdigest(),
    )


def render_final_mp4(
    raw_video_path: Path,
    cues: list[CaptionCue],
    output_mp4: Path,
    work_dir: Path,
    width: int = DEFAULT_WIDTH,
    height: int = DEFAULT_HEIGHT,
    fps: int = DEFAULT_FPS,
    burn_captions: bool = True,
) -> VideoProbe:
    """Compose raw capture video + synchronized narration + captions into final H.264/AAC MP4."""
    if not shutil.which("ffmpeg"):
        raise RuntimeError("ffmpeg is required to render final MP4")
    if not shutil.which("ffprobe"):
        raise RuntimeError("ffprobe is required to inspect video duration and streams")

    work_dir = work_dir.resolve()
    raw_video_abs = raw_video_path.resolve()
    output_mp4_abs = output_mp4.resolve()
    work_dir.mkdir(parents=True, exist_ok=True)
    output_mp4_abs.parent.mkdir(parents=True, exist_ok=True)

    raw_duration = _probe_raw_duration(raw_video_abs)
    last_cue_end = max((c.end_seconds for c in cues), default=0.0)
    target_duration = max(raw_duration, last_cue_end + 0.6)

    narration_wav = work_dir / "narration_track.wav"
    assemble_narration_track(cues, narration_wav, total_duration=target_duration)

    ass_filename = "captions.ass"
    ass_path = work_dir / ass_filename
    _write_ass_subtitles(cues, ass_path, width=width, height=height)

    vf_filters = [
        f"scale={width}:{height}:force_original_aspect_ratio=decrease",
        f"pad={width}:{height}:(ow-iw)/2:(oh-ih)/2:color=#0B0E14",
        f"fps={fps}",
    ]
    if raw_duration > 0.0 and target_duration > raw_duration + 0.05:
        pad_tail = round(target_duration - raw_duration, 3)
        vf_filters.append(f"tpad=stop_mode=clone:stop_duration={pad_tail}")
    elif raw_duration == 0.0:
        # Unknown WebM container duration: clone final frame safely up to target_duration
        vf_filters.append("tpad=stop_mode=clone:stop_duration=3.0")

    if burn_captions:
        # Execute ffmpeg with cwd=work_dir and a clean relative filename to avoid filter-escaping bugs
        vf_filters.append(f"ass={ass_filename}")

    cmd = [
        "ffmpeg",
        "-y",
        "-i",
        str(raw_video_abs),
        "-i",
        str(narration_wav),
        "-map",
        "0:v:0",
        "-map",
        "1:a:0",
        "-vf",
        ",".join(vf_filters),
        "-c:v",
        "libx264",
        "-preset",
        "medium",
        "-crf",
        "20",
        "-pix_fmt",
        "yuv420p",
        "-r",
        str(fps),
        "-c:a",
        "aac",
        "-b:a",
        "160k",
        "-ar",
        "48000",
        "-ac",
        "2",
        "-movflags",
        "+faststart",
        "-t",
        f"{target_duration:.3f}",
        str(output_mp4_abs),
    ]
    subprocess.run(cmd, cwd=str(work_dir), check=True, capture_output=True, text=True)
    return probe_video(output_mp4_abs)


def extract_review_frames(
    video_mp4: Path,
    cues: list[CaptionCue],
    frames_dir: Path,
    total_duration: float | None = None,
) -> list[Path]:
    """Extract one PNG frame at the midpoint of each narration cue for visual QA."""
    frames_dir.mkdir(parents=True, exist_ok=True)
    max_seek = max(0.0, (total_duration - 0.15)) if total_duration and total_duration > 0.2 else None
    extracted: list[Path] = []
    for cue in cues:
        midpoint = cue.start_seconds + max(0.25, (cue.end_seconds - cue.start_seconds) * 0.5)
        if max_seek is not None:
            midpoint = min(midpoint, max_seek)
        frame_path = frames_dir / f"scene_{cue.index + 1:02d}.png"
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-ss",
                f"{midpoint:.3f}",
                "-i",
                str(video_mp4),
                "-frames:v",
                "1",
                str(frame_path),
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        if frame_path.exists():
            extracted.append(frame_path)
    return extracted
