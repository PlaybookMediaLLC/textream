"""Evidence manifest builder, secret scanner, and PR description Markdown renderer."""

from __future__ import annotations

from datetime import datetime, timezone
import json
from pathlib import Path
import re
from typing import Any


SCHEMA_VERSION = "1.0.0"
DEFAULT_PROFILE = "engineering-verification"
MARKER_START = "<!-- pr-video-evidence:start -->"
MARKER_END = "<!-- pr-video-evidence:end -->"

# Patterns that must never appear in manifests, transcripts, captions, TTS prompts, or PR bodies
SECRET_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("github_pat", re.compile(r"\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}\b")),
    ("github_fine_grained_pat", re.compile(r"\bgithub_pat_[A-Za-z0-9_]{20,}\b")),
    ("openai_key", re.compile(r"\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b")),
    ("aws_access_key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("private_key_block", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----")),
    ("bearer_token", re.compile(r"Authorization[\"']?\s*[:=]\s*[\"']?Bearer\s+[A-Za-z0-9._\-]{16,}", re.IGNORECASE)),
    (
        "apple_app_password",
        re.compile(r"APPLE_APP_PASSWORD[\"']?\s*[:=]\s*[\"']?[a-z]{4}-[a-z]{4}-[a-z]{4}-[a-z]{4}", re.IGNORECASE),
    ),
    (
        "macos_signing_secret",
        re.compile(
            r"(?:MACOS_CERT_PASSWORD|MACOS_CERT_P12_BASE64|APPLE_NOTARY_KEY_BASE64)[\"']?\s*[:=]\s*[\"']?[A-Za-z0-9+/=_\-]{8,}",
            re.IGNORECASE,
        ),
    ),
)


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def format_mm_ss(seconds: float) -> str:
    total = max(0, int(round(seconds)))
    mins, secs = divmod(total, 60)
    return f"{mins:02d}:{secs:02d}"


def scan_for_secrets(text: str) -> list[str]:
    """Return list of matched secret pattern names found in ``text``."""
    hits: list[str] = []
    for name, pattern in SECRET_PATTERNS:
        if pattern.search(text):
            hits.append(name)
    return hits


def build_manifest(
    *,
    repository: str,
    branch: str,
    commit_sha: str,
    pr_number: int | None,
    application_route: str,
    test_environment: str,
    acceptance_criteria: list[dict[str, Any]],
    assertion_results: list[dict[str, Any]],
    test_suites: list[dict[str, Any]],
    video: dict[str, Any] | None,
    tts: dict[str, Any] | None,
    artifacts: dict[str, Any],
    review_report: dict[str, Any],
    known_limitations: list[str],
    waiver: dict[str, Any] | None = None,
    captured_at: str | None = None,
) -> dict[str, Any]:
    """Build a schema-compliant pr-video-evidence manifest dictionary."""
    return {
        "schema_version": SCHEMA_VERSION,
        "profile": DEFAULT_PROFILE,
        "repository": repository,
        "branch": branch,
        "commit_sha": commit_sha,
        "pr_number": pr_number,
        "captured_at": captured_at or utc_now_iso(),
        "application_route": application_route,
        "test_environment": test_environment,
        "acceptance_criteria": acceptance_criteria,
        "assertion_results": assertion_results,
        "test_suites": test_suites,
        "video": video,
        "tts": tts,
        "artifacts": artifacts,
        "review_report": review_report,
        "known_limitations": known_limitations,
        "waiver": waiver,
    }


def _sanitize_video_for_pr(video: dict[str, Any] | None, video_url: str | None) -> dict[str, Any] | None:
    """Return a copy of video metadata safe for public PR descriptions (no absolute local paths)."""
    if not isinstance(video, dict):
        return None
    sanitized = dict(video)
    raw_url = str(video_url if video_url is not None else sanitized.get("url") or "").strip()
    if raw_url.startswith("file://") or not raw_url:
        sanitized["url"] = "attached-in-review-thread"
    else:
        sanitized["url"] = raw_url

    # Replace absolute host path with filename-only basename so local usernames never leak
    raw_path = str(sanitized.get("path") or "").strip()
    if raw_path:
        sanitized["path"] = Path(raw_path).name
    return sanitized


def render_pr_markdown(manifest: dict[str, Any], video_url: str | None = None) -> str:
    """Render Section-16 PR Evidence Summary Markdown + machine-readable metadata envelope."""
    effective_manifest = json.loads(json.dumps(manifest))
    effective_manifest["video"] = _sanitize_video_for_pr(effective_manifest.get("video"), video_url)

    commit_sha = effective_manifest.get("commit_sha", "")
    video = effective_manifest.get("video")
    waiver = effective_manifest.get("waiver")
    tts = effective_manifest.get("tts") or {}
    review = effective_manifest.get("review_report") or {}

    lines: list[str] = []
    lines.append("### Narrated verification")
    if waiver:
        lines.append(f"Recording: Waived — {waiver.get('reason', 'documented non-demonstrable change')}")
    else:
        url = str((video or {}).get("url") or "attached-in-review-thread")
        if url.startswith(("http://", "https://")):
            lines.append(f"Recording: [Playable demonstration]({url})")
        else:
            lines.append(f"Recording: `{url}` (delivered as playable attachment in active review thread)")
        if video:
            lines.append(
                f"Specs: `{video.get('codec', 'h264')}` / `{video.get('audio_codec', 'aac')}` · "
                f"`{video.get('width', 0)}×{video.get('height', 0)}` @ `{video.get('fps', 0)} fps` · "
                f"`{video.get('duration_seconds', 0)}s` · TTS: `{tts.get('provider', 'unknown')}` (`{tts.get('voice', '')}`)"
            )
    lines.append(f"Commit: `{commit_sha}`")
    lines.append("")

    lines.append("### Demonstrated behavior")
    lines.append("| Acceptance criterion | Timestamp | Verification |")
    lines.append("| --- | --- | --- |")
    criteria = effective_manifest.get("acceptance_criteria") or []
    if criteria:
        for item in criteria:
            criterion = " ".join(str(item.get("criterion", "")).split()).replace("|", "\\|")
            ts = str(item.get("timestamp", "00:00"))
            status = "Passed" if item.get("passed") else "Failed"
            lines.append(f"| {criterion} | {ts} | {status} |")
    else:
        lines.append("| Documented waiver | N/A | Waived |")
    lines.append("")

    lines.append("### Automated checks")
    for suite in effective_manifest.get("test_suites") or []:
        cmd = suite.get("command", "")
        status = str(suite.get("status", "unknown")).capitalize()
        detail = " ".join(str(suite.get("detail", "")).split())
        suffix = f" ({detail})" if detail else ""
        lines.append(f"- `{cmd}` — **{status}**{suffix}")
    lines.append("")

    lines.append("### Consolidated engineering review")
    reviewers = review.get("reviewer_identities") or []
    findings = review.get("findings_by_severity") or {}
    lines.append(f"- **Reviewers:** {', '.join(reviewers) if reviewers else 'None recorded'}")
    lines.append(
        f"- **Findings:** P0={findings.get('P0', 0)}, P1={findings.get('P1', 0)}, "
        f"P2={findings.get('P2', 0)}, P3={findings.get('P3', 0)} "
        f"(Unresolved blocking: {len(review.get('unresolved_blocking_findings') or [])})"
    )
    lines.append(f"- **Recommendation:** {review.get('final_recommendation', 'pending')}")
    lines.append("")

    lines.append("### Known limitations")
    limitations = effective_manifest.get("known_limitations") or []
    if limitations:
        for lim in limitations:
            lines.append(f"- {' '.join(str(lim).split())}")
    else:
        lines.append("- None identified for this commit.")
    lines.append("")

    envelope_payload = {
        "schema_version": effective_manifest.get("schema_version"),
        "profile": effective_manifest.get("profile"),
        "repository": effective_manifest.get("repository"),
        "branch": effective_manifest.get("branch"),
        "commit_sha": effective_manifest.get("commit_sha"),
        "pr_number": effective_manifest.get("pr_number"),
        "captured_at": effective_manifest.get("captured_at"),
        "application_route": effective_manifest.get("application_route"),
        "test_environment": effective_manifest.get("test_environment"),
        "acceptance_criteria": effective_manifest.get("acceptance_criteria"),
        "assertion_results": effective_manifest.get("assertion_results"),
        "test_suites": effective_manifest.get("test_suites"),
        "video": effective_manifest.get("video"),
        "tts": effective_manifest.get("tts"),
        "review_report": effective_manifest.get("review_report"),
        "known_limitations": effective_manifest.get("known_limitations"),
        "waiver": effective_manifest.get("waiver"),
    }

    lines.append("<details>")
    lines.append("<summary>PR Video Evidence Manifest (machine-readable)</summary>")
    lines.append("")
    lines.append(MARKER_START)
    lines.append("```json")
    lines.append(json.dumps(envelope_payload, indent=2))
    lines.append("```")
    lines.append(MARKER_END)
    lines.append("</details>")
    return "\n".join(lines) + "\n"


def extract_manifest_from_pr_body(body: str) -> dict[str, Any] | None:
    """Extract JSON object manifest between ordered pr-video-evidence markers."""
    start = body.find(MARKER_START)
    if start < 0:
        return None
    content_start = start + len(MARKER_START)
    end = body.find(MARKER_END, content_start)
    if end < 0:
        return None

    segment = body[content_start:end].strip()
    if segment.startswith("```"):
        segment_lines = segment.splitlines()
        if segment_lines and segment_lines[0].startswith("```"):
            segment_lines = segment_lines[1:]
        if segment_lines and segment_lines[-1].strip() == "```":
            segment_lines = segment_lines[:-1]
        segment = "\n".join(segment_lines).strip()

    parsed = json.loads(segment)
    if not isinstance(parsed, dict):
        raise ValueError(f"Expected JSON object in pr-video-evidence block, got {type(parsed).__name__}")
    return parsed
