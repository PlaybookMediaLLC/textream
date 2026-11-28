#!/usr/bin/env python3
"""Unified CLI for Dante for Creators (`PlaybookMediaLLC/textream`) PR video evidence.

Subcommands:
  doctor    Verify ffmpeg, ffprobe, Playwright Chromium, and TTS backends.
  record    Start isolated app surface, run tests, record Playwright session with
            visual annotations + Kokoro TTS narration, render H.264/AAC MP4,
            extract review keyframes, and emit manifest.json + pr-evidence.md.
  narrate   Ingest native macOS/iOS Simulator raw video, synthesize synchronized
            narration + captions, render H.264/AAC MP4, and emit manifest + markdown.
  markdown  Render Section-16 PR description markdown from an existing manifest.
  validate  Validate PR evidence manifest or PR description (used locally and in CI).
"""

from __future__ import annotations

import argparse
from functools import partial
import http.server
import json
import os
from pathlib import Path
import platform
import shutil
import socketserver
import subprocess
import sys
import threading
import time
from typing import Any
from urllib.parse import urlparse
import urllib.request

# Ensure sibling modules resolve cleanly when invoked directly as a script
SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from composer import (  # noqa: E402
    CaptionCue,
    DEFAULT_FPS,
    DEFAULT_HEIGHT,
    DEFAULT_WIDTH,
    extract_review_frames,
    render_final_mp4,
    write_captions_and_transcript,
)
from evidence import (  # noqa: E402
    build_manifest,
    format_mm_ss,
    render_pr_markdown,
    scan_for_secrets,
)
from playwright_capture import capture_storyboard_with_playwright  # noqa: E402
from tts import (  # noqa: E402
    DEFAULT_KOKORO_PRECISION,
    DEFAULT_KOKORO_SPEED,
    ROBOTIC_PROVIDERS,
    TTSEngine,
    doctor_tts_status,
)
from validator import (  # noqa: E402
    ValidationResult,
    git_changed_files,
    validate_manifest,
    validate_pr_body,
)


REPO_ROOT = SCRIPT_DIR.parents[1]
DEFAULT_TEST_TIMEOUT_SECONDS = 600


def _git_output(args: list[str], fallback: str = "") -> str:
    try:
        res = subprocess.run(
            ["git", *args],
            cwd=str(REPO_ROOT),
            check=True,
            capture_output=True,
            text=True,
        )
        return res.stdout.strip()
    except Exception:
        return fallback


def _detect_repository() -> str:
    remote = _git_output(["config", "--get", "remote.origin.url"])
    if "github.com" in remote:
        part = remote.split("github.com", 1)[1].lstrip(":/")
        if part.endswith(".git"):
            part = part[:-4]
        return part
    return "PlaybookMediaLLC/textream"


class _QuietStaticHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format: str, *args: Any) -> None:  # noqa: A002
        return


class _ThreadingHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def _resolve_repo_static_dir(rel_directory: str) -> Path:
    """Resolve static server directory safely within REPO_ROOT."""
    candidate = (REPO_ROOT / rel_directory).resolve()
    repo_abs = REPO_ROOT.resolve()
    if not candidate.is_relative_to(repo_abs):
        raise ValueError(f"Static server directory escapes repository root: {rel_directory!r}")
    if not candidate.is_dir():
        raise FileNotFoundError(f"Static server directory does not exist: {candidate}")
    return candidate


def _start_static_server(directory: Path) -> tuple[_ThreadingHTTPServer, str]:
    handler = partial(_QuietStaticHandler, directory=str(directory.resolve()))
    server = _ThreadingHTTPServer(("127.0.0.1", 0), handler)
    port = server.server_address[1]
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server, f"http://127.0.0.1:{port}"


def _wait_for_http(url: str, timeout_s: float = 20.0) -> None:
    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https"):
        raise ValueError(f"Unsupported URL scheme for health check: {url!r}")
    deadline = time.monotonic() + timeout_s
    last_err: Exception | None = None
    while time.monotonic() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=2.0) as resp:
                if 200 <= resp.status < 400:
                    return
        except Exception as exc:
            last_err = exc
            time.sleep(0.2)
    raise RuntimeError(f"Isolated target server at {url} did not become healthy: {last_err}")


def _run_scenario_tests(test_commands: list[dict[str, Any]]) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    current_os = platform.system().lower()
    for item in test_commands:
        raw_cmd = item["command"]
        display_cmd = " ".join(raw_cmd) if isinstance(raw_cmd, list) else str(raw_cmd)
        required_os = str(item.get("platform", "any")).lower()
        timeout_s = int(item.get("timeout_seconds") or DEFAULT_TEST_TIMEOUT_SECONDS)

        if required_os != "any" and required_os != current_os:
            results.append(
                {
                    "command": display_cmd,
                    "status": "skipped",
                    "exit_code": None,
                    "detail": item.get("skip_reason")
                    or f"Requires {required_os} host (current host is {current_os}); verified on CI runner.",
                }
            )
            continue

        try:
            proc = subprocess.run(
                raw_cmd,
                cwd=str(REPO_ROOT),
                shell=isinstance(raw_cmd, str),
                text=True,
                capture_output=True,
                timeout=timeout_s,
            )
            tail = " ".join((proc.stdout + "\n" + proc.stderr).strip().splitlines()[-3:])
            results.append(
                {
                    "command": display_cmd,
                    "status": "passed" if proc.returncode == 0 else "failed",
                    "exit_code": proc.returncode,
                    "detail": tail[:220] if tail else ("passed" if proc.returncode == 0 else "failed"),
                }
            )
        except subprocess.TimeoutExpired:
            results.append(
                {
                    "command": display_cmd,
                    "status": "failed",
                    "exit_code": -1,
                    "detail": f"Timed out after {timeout_s}s",
                }
            )
    return results


def _load_review_report(path: Path | None, commit_sha: str, repository: str) -> dict[str, Any]:
    if path is not None:
        if not path.exists():
            raise FileNotFoundError(f"Review report file not found: {path}")
        return json.loads(path.read_text(encoding="utf-8"))
    return {
        "repository": repository,
        "base_branch": "master",
        "reviewed_commit_sha": commit_sha,
        "reviewer_identities": [],
        "reviewer_source_definitions": [],
        "specialist_selection_rationale": "Pending independent review report (--review-report).",
        "review_scope": "Pending",
        "findings_by_severity": {"P0": 0, "P1": 0, "P2": 0, "P3": 0},
        "corrections_applied": [],
        "findings_verified_resolved": [],
        "accepted_exceptions": [],
        "unresolved_blocking_findings": ["independent-review-pending"],
        "outstanding_findings": [],
        "final_recommendation": "pending",
    }


def _validate_tts_fallback(tts_engine: TTSEngine, fallback_reason: str | None) -> None:
    """Fail fast before capture/render if robotic espeak-ng lacks a valid fallback reason."""
    if tts_engine.provider in ROBOTIC_PROVIDERS:
        reason = (fallback_reason or "").strip()
        if len(reason) < 12:
            raise ValueError(
                "Explicit robotic fallback ('espeak-ng') requires --tts-fallback-reason "
                "with a clear explanation (>=12 chars) so downstream validation can pass."
            )


def _tts_metadata(tts_engine: TTSEngine, fallback_reason: str | None = None) -> dict[str, Any]:
    meta: dict[str, Any] = {
        "provider": tts_engine.provider,
        "voice": tts_engine.voice,
        "precision": tts_engine.precision if tts_engine.provider == "kokoro" else "native",
        "human_grade": tts_engine.human_grade,
    }
    clean_reason = (fallback_reason or "").strip()
    if clean_reason and tts_engine.provider in ROBOTIC_PROVIDERS:
        meta["fallback_reason"] = clean_reason
    return meta


def _scan_generated_artifacts(manifest: dict[str, Any], *text_paths: Path, extra_text: str = "") -> None:
    blobs = [json.dumps(manifest), extra_text]
    for path in text_paths:
        if path.exists():
            blobs.append(path.read_text(encoding="utf-8"))
    hits = scan_for_secrets("\n".join(blobs))
    if hits:
        raise RuntimeError(f"Secret material detected in generated evidence: {', '.join(hits)}")


def _ffmpeg_capabilities() -> dict[str, bool]:
    ffmpeg_bin = shutil.which("ffmpeg")
    if not ffmpeg_bin:
        return {"libx264": False, "aac": False, "ass_filter": False}
    enc = subprocess.run([ffmpeg_bin, "-hide_banner", "-encoders"], capture_output=True, text=True)
    flt = subprocess.run([ffmpeg_bin, "-hide_banner", "-filters"], capture_output=True, text=True)
    return {
        "libx264": "libx264" in enc.stdout,
        "aac": " aac " in enc.stdout,
        "ass_filter": " ass " in flt.stdout,
    }


def cmd_doctor(_args: argparse.Namespace) -> int:
    pw_ok = False
    pw_detail = ""
    try:
        import playwright  # noqa: F401

        pw_ok = True
        pw_detail = os.environ.get("PLAYWRIGHT_BROWSERS_PATH", "default")
    except ImportError as exc:
        pw_detail = str(exc)

    ff_caps = _ffmpeg_capabilities()
    report = {
        "python": sys.version.split()[0],
        "platform": platform.platform(),
        "ffmpeg": shutil.which("ffmpeg"),
        "ffprobe": shutil.which("ffprobe"),
        "ffmpeg_capabilities": ff_caps,
        "playwright_installed": pw_ok,
        "playwright_browsers_path": pw_detail,
        "tts": doctor_tts_status(),
    }
    print(json.dumps(report, indent=2))
    missing = [k for k in ("ffmpeg", "ffprobe") if not report[k]]
    if missing or not pw_ok or not all(ff_caps.values()):
        return 1
    return 0


def cmd_record(args: argparse.Namespace) -> int:
    scenario_path = Path(args.scenario).resolve()
    scenario = json.loads(scenario_path.read_text(encoding="utf-8"))
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    work_dir = output_dir / "_work"
    work_dir.mkdir(parents=True, exist_ok=True)

    repository = args.repository or _detect_repository()
    branch = args.branch or _git_output(["rev-parse", "--abbrev-ref", "HEAD"], fallback="unknown")
    commit_sha = args.commit_sha or _git_output(["rev-parse", "HEAD"], fallback="unknown")
    commit_short = commit_sha[:8]

    # Validate explicit --review-report early before doing expensive capture
    review_report = _load_review_report(
        Path(args.review_report) if args.review_report else None,
        commit_sha=commit_sha,
        repository=repository,
    )

    # 1. Execute automated test suites configured in scenario
    test_suites = _run_scenario_tests(scenario.get("test_commands") or [])
    failed_suites = [s for s in test_suites if s["status"] == "failed"]
    if failed_suites and not args.allow_failed_tests:
        print(
            json.dumps({"error": "Automated test suite failed", "test_suites": test_suites}, indent=2),
            file=sys.stderr,
        )
        return 2

    # 2. Pre-synthesize narration segments so scene durations match speech accurately
    beats = scenario.get("beats") or []
    if not beats:
        raise ValueError(f"Scenario {scenario_path} must contain at least one beat")

    tts_engine = TTSEngine(
        provider=args.tts_provider,
        voice=args.voice,
        speed=args.speed,
        precision=args.kokoro_precision,
    )
    _validate_tts_fallback(tts_engine, args.tts_fallback_reason)
    synthesized = []
    for idx, beat in enumerate(beats):
        wav_path = work_dir / f"beat_{idx + 1:02d}.wav"
        seg = tts_engine.synthesize(str(beat["narration"]), wav_path, index=idx)
        synthesized.append(seg)

    # 3. Start isolated target surface (static dir, custom server command, or explicit --base-url)
    static_server: _ThreadingHTTPServer | None = None
    server_proc: subprocess.Popen[str] | None = None
    server_log_handle = None
    base_url = args.base_url
    try:
        server_cfg = scenario.get("server") or {}
        if not base_url:
            if server_cfg.get("type") == "static":
                static_dir = _resolve_repo_static_dir(str(server_cfg["directory"]))
                static_server, base_url = _start_static_server(static_dir)
                _wait_for_http(base_url + str(server_cfg.get("health_path", "/")))
            elif server_cfg.get("type") == "command":
                port_file = work_dir / "server_url.txt"
                port_file.unlink(missing_ok=True)
                server_log_path = work_dir / "server.log"
                server_log_handle = server_log_path.open("w", encoding="utf-8")
                env = os.environ.copy()
                env["PR_EVIDENCE_URL_FILE"] = str(port_file)
                env["PR_EVIDENCE_COMMIT"] = commit_sha
                env["PR_EVIDENCE_BRANCH"] = branch
                env["PR_EVIDENCE_TEST_RESULTS"] = json.dumps(test_suites)
                server_proc = subprocess.Popen(
                    server_cfg["command"],
                    cwd=str(REPO_ROOT),
                    env=env,
                    stdout=server_log_handle,
                    stderr=subprocess.STDOUT,
                    text=True,
                )
                deadline = time.monotonic() + 20.0
                while time.monotonic() < deadline:
                    if port_file.exists():
                        candidate_url = port_file.read_text(encoding="utf-8").strip()
                        if candidate_url:
                            base_url = candidate_url
                            break
                    if server_proc.poll() is not None:
                        server_log_handle.flush()
                        err = server_log_path.read_text(encoding="utf-8")[-800:]
                        raise RuntimeError(f"Scenario server exited prematurely: {err}")
                    time.sleep(0.15)
                if not base_url:
                    raise RuntimeError("Scenario server did not publish PR_EVIDENCE_URL_FILE in time")
                _wait_for_http(base_url + str(server_cfg.get("health_path", "/")))
            else:
                raise ValueError("Specify --base-url or configure 'server' in the scenario JSON")

        # 4. Run live Playwright browser capture with annotations
        capture = capture_storyboard_with_playwright(
            base_url=base_url,
            beats=beats,
            narration_durations=[s.duration_seconds for s in synthesized],
            output_dir=output_dir,
            commit_short=commit_short,
            viewport_width=args.width,
            viewport_height=args.height,
        )
    finally:
        if static_server is not None:
            static_server.shutdown()
            static_server.server_close()
        if server_proc is not None:
            server_proc.terminate()
            try:
                server_proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server_proc.kill()
                server_proc.wait(timeout=5)
        if server_log_handle is not None:
            server_log_handle.close()

    # 5. Build timed caption cues anchored to observed beat start times
    cues: list[CaptionCue] = []
    for beat_rec, seg in zip(capture.beats, synthesized):
        cues.append(
            CaptionCue(
                index=beat_rec.index,
                start_seconds=beat_rec.start_seconds,
                end_seconds=round(beat_rec.start_seconds + seg.duration_seconds, 3),
                text=seg.text,
                wav_path=seg.wav_path,
            )
        )

    srt_path = output_dir / "captions.srt"
    vtt_path = output_dir / "captions.vtt"
    transcript_path = output_dir / "transcript.txt"
    write_captions_and_transcript(cues, srt_path, vtt_path, transcript_path)

    final_mp4 = output_dir / "evidence.mp4"
    probe = render_final_mp4(
        raw_video_path=capture.raw_video_path,
        cues=cues,
        output_mp4=final_mp4,
        work_dir=work_dir,
        width=args.width,
        height=args.height,
        fps=args.fps,
        burn_captions=not args.no_burn_captions,
    )

    review_frames = extract_review_frames(
        final_mp4,
        cues,
        output_dir / "review_frames",
        total_duration=probe.duration_seconds,
    )

    acceptance_criteria = [
        {
            "criterion": b.acceptance_criterion,
            "timestamp": format_mm_ss(b.start_seconds),
            "route": b.route,
            "passed": b.passed,
            "detail": b.observed_detail,
        }
        for b in capture.beats
    ]
    assertion_results = [
        {
            "beat": b.index + 1,
            "description": b.assertion_description,
            "expected": b.expected_result,
            "observed": b.observed_detail,
            "passed": b.passed,
        }
        for b in capture.beats
    ]

    known_limitations = list(scenario.get("known_limitations") or [])
    if args.limitation:
        known_limitations.extend(args.limitation)

    manifest = build_manifest(
        repository=repository,
        branch=branch,
        commit_sha=commit_sha,
        pr_number=args.pr_number,
        application_route=str(scenario.get("application_route") or "/"),
        test_environment=str(
            scenario.get("test_environment")
            or f"{platform.system()} {platform.release()} · Chromium Playwright (isolated localhost) · TTS: {tts_engine.provider}"
        ),
        acceptance_criteria=acceptance_criteria,
        assertion_results=assertion_results,
        test_suites=test_suites,
        video={
            "path": str(final_mp4),
            "url": args.video_url or "attached-in-review-thread",
            "codec": probe.codec,
            "audio_codec": probe.audio_codec,
            "width": probe.width,
            "height": probe.height,
            "fps": probe.fps,
            "duration_seconds": probe.duration_seconds,
            "audio_duration_seconds": probe.audio_duration_seconds,
            "size_bytes": probe.size_bytes,
            "sha256": probe.sha256,
        },
        tts=_tts_metadata(tts_engine, args.tts_fallback_reason),
        artifacts={
            "raw_video": str(capture.raw_video_path),
            "trace": str(capture.trace_path),
            "transcript": str(transcript_path),
            "captions_srt": str(srt_path),
            "captions_vtt": str(vtt_path),
            "annotations": str(output_dir / "annotations.json"),
            "review_frames": [str(p) for p in review_frames],
            "console_errors": capture.console_errors,
            "page_errors": capture.page_errors,
        },
        review_report=review_report,
        known_limitations=known_limitations,
    )

    pr_markdown = render_pr_markdown(manifest, video_url=args.video_url)
    _scan_generated_artifacts(
        manifest,
        transcript_path,
        srt_path,
        vtt_path,
        output_dir / "annotations.json",
        extra_text=pr_markdown,
    )

    manifest_path = output_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    md_path = output_dir / "pr-evidence.md"
    md_path.write_text(pr_markdown, encoding="utf-8")

    failed_assertions = [a for a in assertion_results if not a["passed"]]
    status_label = "failed" if failed_assertions else "ok"
    print(
        json.dumps(
            {
                "status": status_label,
                "output_mp4": str(final_mp4),
                "manifest": str(manifest_path),
                "markdown": str(md_path),
                "review_frames": [str(p) for p in review_frames],
                "probe": probe.__dict__,
                "tts": _tts_metadata(tts_engine, args.tts_fallback_reason),
                "assertions_passed": len(assertion_results) - len(failed_assertions),
                "assertions_total": len(assertion_results),
            },
            indent=2,
        )
    )
    if failed_assertions and not args.allow_failed_assertions:
        return 3
    return 0


def cmd_narrate(args: argparse.Namespace) -> int:
    """Ingest native macOS/iOS Simulator raw video and compose narrated H.264/AAC MP4."""
    input_video = Path(args.input_video).resolve()
    if not input_video.exists():
        raise FileNotFoundError(f"Input video not found: {input_video}")
    scenario_path = Path(args.scenario).resolve()
    scenario = json.loads(scenario_path.read_text(encoding="utf-8"))
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    work_dir = output_dir / "_work"
    work_dir.mkdir(parents=True, exist_ok=True)

    repository = args.repository or _detect_repository()
    branch = args.branch or _git_output(["rev-parse", "--abbrev-ref", "HEAD"], fallback="unknown")
    commit_sha = args.commit_sha or _git_output(["rev-parse", "HEAD"], fallback="unknown")

    review_report = _load_review_report(
        Path(args.review_report) if args.review_report else None,
        commit_sha=commit_sha,
        repository=repository,
    )

    test_suites = _run_scenario_tests(scenario.get("test_commands") or [])
    failed_suites = [s for s in test_suites if s["status"] == "failed"]
    if failed_suites and not args.allow_failed_tests:
        print(
            json.dumps({"error": "Automated test suite failed", "test_suites": test_suites}, indent=2),
            file=sys.stderr,
        )
        return 2

    beats = scenario.get("beats") or []
    if not beats:
        raise ValueError(f"Scenario {scenario_path} must contain at least one beat")

    tts_engine = TTSEngine(
        provider=args.tts_provider,
        voice=args.voice,
        speed=args.speed,
        precision=args.kokoro_precision,
    )
    _validate_tts_fallback(tts_engine, args.tts_fallback_reason)

    cues: list[CaptionCue] = []
    cursor_s = 0.25
    prev_end = 0.0
    acceptance_criteria: list[dict[str, Any]] = []
    assertion_results: list[dict[str, Any]] = []

    for idx, beat in enumerate(beats):
        wav_path = work_dir / f"beat_{idx + 1:02d}.wav"
        seg = tts_engine.synthesize(str(beat["narration"]), wav_path, index=idx)
        start_s = float(beat["start_seconds"]) if "start_seconds" in beat else cursor_s
        if start_s < prev_end:
            raise ValueError(
                f"Narration beat {idx + 1} start_seconds ({start_s}s) overlaps previous cue end ({prev_end}s)"
            )
        end_s = round(start_s + seg.duration_seconds, 3)
        cues.append(
            CaptionCue(
                index=idx,
                start_seconds=start_s,
                end_seconds=end_s,
                text=seg.text,
                wav_path=seg.wav_path,
            )
        )
        prev_end = end_s
        cursor_s = round(end_s + 0.45, 3)

        # Require explicit beat verification boolean (defaults to False if unverified)
        if "verified" in beat:
            beat_passed = bool(beat["verified"])
            observed_detail = str(beat.get("observed_result") or beat.get("expected_result") or "Verified on native capture")
        else:
            beat_passed = False
            observed_detail = "Unverified: set 'verified': true on beat after verifying native capture outcome"

        acceptance_criteria.append(
            {
                "criterion": str(beat.get("acceptance_criterion", f"Criterion {idx + 1}")),
                "timestamp": format_mm_ss(start_s),
                "route": str(beat.get("route", scenario.get("application_route", "native-app"))),
                "passed": beat_passed,
                "detail": observed_detail,
            }
        )
        assertion_results.append(
            {
                "beat": idx + 1,
                "description": str(beat.get("expected_result", f"Beat {idx + 1} verified")),
                "expected": str(beat.get("expected_result", "")),
                "observed": observed_detail,
                "passed": beat_passed,
            }
        )

    srt_path = output_dir / "captions.srt"
    vtt_path = output_dir / "captions.vtt"
    transcript_path = output_dir / "transcript.txt"
    write_captions_and_transcript(cues, srt_path, vtt_path, transcript_path)

    final_mp4 = output_dir / "evidence.mp4"
    probe = render_final_mp4(
        raw_video_path=input_video,
        cues=cues,
        output_mp4=final_mp4,
        work_dir=work_dir,
        width=args.width,
        height=args.height,
        fps=args.fps,
        burn_captions=not args.no_burn_captions,
    )
    review_frames = extract_review_frames(
        final_mp4,
        cues,
        output_dir / "review_frames",
        total_duration=probe.duration_seconds,
    )

    known_limitations = list(scenario.get("known_limitations") or [])
    if args.limitation:
        known_limitations.extend(args.limitation)

    manifest = build_manifest(
        repository=repository,
        branch=branch,
        commit_sha=commit_sha,
        pr_number=args.pr_number,
        application_route=str(scenario.get("application_route") or "native-app"),
        test_environment=str(
            scenario.get("test_environment")
            or f"{platform.system()} native capture · TTS: {tts_engine.provider}"
        ),
        acceptance_criteria=acceptance_criteria,
        assertion_results=assertion_results,
        test_suites=test_suites,
        video={
            "path": str(final_mp4),
            "url": args.video_url or "attached-in-review-thread",
            "codec": probe.codec,
            "audio_codec": probe.audio_codec,
            "width": probe.width,
            "height": probe.height,
            "fps": probe.fps,
            "duration_seconds": probe.duration_seconds,
            "audio_duration_seconds": probe.audio_duration_seconds,
            "size_bytes": probe.size_bytes,
            "sha256": probe.sha256,
        },
        tts=_tts_metadata(tts_engine, args.tts_fallback_reason),
        artifacts={
            "raw_video": str(input_video),
            "transcript": str(transcript_path),
            "captions_srt": str(srt_path),
            "captions_vtt": str(vtt_path),
            "review_frames": [str(p) for p in review_frames],
        },
        review_report=review_report,
        known_limitations=known_limitations,
    )

    pr_markdown = render_pr_markdown(manifest, video_url=args.video_url)
    _scan_generated_artifacts(manifest, transcript_path, srt_path, vtt_path, extra_text=pr_markdown)

    manifest_path = output_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    md_path = output_dir / "pr-evidence.md"
    md_path.write_text(pr_markdown, encoding="utf-8")

    failed_assertions = [a for a in assertion_results if not a["passed"]]
    print(
        json.dumps(
            {
                "status": "failed" if failed_assertions else "ok",
                "output_mp4": str(final_mp4),
                "manifest": str(manifest_path),
                "markdown": str(md_path),
                "review_frames": [str(p) for p in review_frames],
                "probe": probe.__dict__,
                "tts": _tts_metadata(tts_engine, args.tts_fallback_reason),
                "assertions_passed": len(assertion_results) - len(failed_assertions),
                "assertions_total": len(assertion_results),
            },
            indent=2,
        )
    )
    if failed_assertions and not args.allow_failed_assertions:
        return 3
    return 0


def cmd_markdown(args: argparse.Namespace) -> int:
    manifest = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    if args.pr_number is not None:
        manifest["pr_number"] = args.pr_number
    md = render_pr_markdown(manifest, video_url=args.video_url)
    if args.output:
        Path(args.output).write_text(md, encoding="utf-8")
    else:
        print(md, end="")
    return 0


def cmd_validate(args: argparse.Namespace) -> int:
    changed_files: list[str] | None = None
    try:
        if args.base_ref:
            changed_files = git_changed_files(REPO_ROOT, args.base_ref, args.head_ref)

        if args.pr_body_file:
            pr_body = Path(args.pr_body_file).read_text(encoding="utf-8")
            result = validate_pr_body(
                pr_body,
                expected_sha=args.expected_sha,
                changed_files=changed_files,
            )
        elif args.manifest:
            manifest_path = Path(args.manifest)
            if not manifest_path.exists():
                result = validate_manifest(
                    None,
                    expected_sha=args.expected_sha,
                    changed_files=changed_files,
                )
            else:
                manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
                result = validate_manifest(
                    manifest,
                    expected_sha=args.expected_sha,
                    changed_files=changed_files,
                )
        else:
            result = ValidationResult(
                passed=False,
                errors=["Provide either --manifest or --pr-body-file to validate."],
                checked_commit=args.expected_sha or "",
            )
    except (json.JSONDecodeError, ValueError, OSError, subprocess.CalledProcessError) as exc:
        result = ValidationResult(
            passed=False,
            errors=[f"Validation error: {exc}"],
            checked_commit=args.expected_sha or "",
        )

    print(json.dumps(result.to_dict(), indent=2))
    return 0 if result.passed else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="devx:video-evidence",
        description="Dante for Creators narrated PR video evidence pipeline",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_doc = sub.add_parser("doctor", help="Check local capture, ffmpeg, and TTS dependencies")
    p_doc.set_defaults(func=cmd_doctor)

    for name, fn, help_text in (
        ("record", cmd_record, "Record isolated web/terminal scenario with Playwright + TTS"),
        ("narrate", cmd_narrate, "Narrate and caption an existing native macOS/iOS video"),
    ):
        p = sub.add_parser(name, help=help_text)
        if name == "narrate":
            p.add_argument("--input-video", required=True, help="Raw .mov/.mp4 recording")
        else:
            p.add_argument("--base-url", help="Existing isolated server URL (overrides scenario server)")
        p.add_argument("--allow-failed-tests", action="store_true")
        p.add_argument("--allow-failed-assertions", action="store_true")
        p.add_argument("--scenario", required=True, help="Path to storyboard scenario JSON")
        p.add_argument("--output-dir", default=".pr-evidence/latest", help="Output directory (gitignored)")
        p.add_argument("--tts-provider", default="auto", choices=["auto", "kokoro", "macos-say", "espeak-ng", "openai"])
        p.add_argument("--voice", default=None, help="Optional TTS voice or Kokoro blend (e.g. af_heart:0.65+af_bella:0.35)")
        p.add_argument("--kokoro-precision", default=DEFAULT_KOKORO_PRECISION, choices=["fp32", "int8"], help="Kokoro ONNX model precision (default: fp32)")
        p.add_argument("--tts-fallback-reason", default=None, help="Required explanation if emergency robotic espeak-ng fallback is used")
        p.add_argument("--speed", type=float, default=DEFAULT_KOKORO_SPEED, help="TTS speaking speed multiplier (default: 0.98)")
        p.add_argument("--width", type=int, default=DEFAULT_WIDTH)
        p.add_argument("--height", type=int, default=DEFAULT_HEIGHT)
        p.add_argument("--fps", type=int, default=DEFAULT_FPS)
        p.add_argument("--no-burn-captions", action="store_true")
        p.add_argument("--review-report", help="Path to consolidated independent review report JSON")
        p.add_argument("--video-url", help="Accessible video link for PR description")
        p.add_argument("--pr-number", type=int, default=None)
        p.add_argument("--repository", default=None)
        p.add_argument("--branch", default=None)
        p.add_argument("--commit-sha", default=None)
        p.add_argument("--limitation", action="append", default=[])
        p.set_defaults(func=fn)

    p_md = sub.add_parser("markdown", help="Generate PR description evidence markdown")
    p_md.add_argument("--manifest", required=True)
    p_md.add_argument("--video-url", default=None)
    p_md.add_argument("--pr-number", type=int, default=None)
    p_md.add_argument("--output", default=None)
    p_md.set_defaults(func=cmd_markdown)

    p_val = sub.add_parser("validate", help="Validate PR evidence freshness, metadata, tests, and hygiene")
    p_val.add_argument("--manifest", default=None)
    p_val.add_argument("--pr-body-file", default=None)
    p_val.add_argument("--expected-sha", default=None)
    p_val.add_argument("--base-ref", default=None, help="Git base ref for binary-artifact diff check")
    p_val.add_argument("--head-ref", default="HEAD")
    p_val.set_defaults(func=cmd_validate)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
