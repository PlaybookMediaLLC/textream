"""Deterministic validator for the `pr-video-evidence` CI check and local gate.

Validates:
1. No newly committed binary recording artifacts in git diff (preserving legacy
   marketing assets such as docs/video.mp4 and docs/video.gif).
2. Presence of a schema-valid JSON object evidence manifest (from file or PR body).
3. Exact commit SHA freshness (evidence.commit_sha == expected HEAD SHA).
4. Required metadata fields (repository, branch, captured_at, application_route,
   test_environment, acceptance_criteria, assertion_results, test_suites, review_report).
5. Video compliance (H.264 + AAC, 1920x1080, 30fps, non-zero video & audio duration,
   TTS provider, accessible reference without file:// leaks in PR bodies) OR a valid
   documented waiver with equivalent artifacts.
6. Passing test suites (allowlisted statuses, >=1 passed suite unless waived) and assertions.
7. Independent engineering review completion (all mandatory core roles, matching
   reviewed_commit_sha, zero unresolved P0/P1 findings, allowlisted approval status).
8. Zero exposed secrets/credentials in the manifest or PR description (even when
   manifest parsing fails).
"""

from __future__ import annotations

from dataclasses import dataclass, field
import json
from pathlib import Path
import subprocess
from typing import Any

from evidence import DEFAULT_PROFILE, extract_manifest_from_pr_body, scan_for_secrets


FORBIDDEN_MEDIA_EXTENSIONS = {
    ".mp4",
    ".mov",
    ".webm",
    ".mkv",
    ".avi",
    ".wav",
    ".m4a",
    ".aac",
    ".mp3",
}

# Explicitly preserved legacy silent marketing assets in this repository
PRESERVED_MARKETING_MEDIA = {
    "docs/video.mp4",
    "docs/video.gif",
}

REQUIRED_TOP_LEVEL_FIELDS = (
    "schema_version",
    "profile",
    "repository",
    "branch",
    "commit_sha",
    "captured_at",
    "application_route",
    "test_environment",
    "acceptance_criteria",
    "assertion_results",
    "test_suites",
    "review_report",
)

MANDATORY_CORE_REVIEWERS = {
    "senior-code-critic",
    "review-changes",
    "ponytail-review",
}

APPROVED_RECOMMENDATIONS = {
    "approved",
    "approved_with_notes",
    "approved_with_comments",
}

ALLOWED_TEST_STATUSES = {
    "passed",
    "skipped",
}


@dataclass
class ValidationResult:
    """Structured outcome of validating PR video evidence."""

    passed: bool
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    checked_commit: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {
            "passed": self.passed,
            "checked_commit": self.checked_commit,
            "errors": self.errors,
            "warnings": self.warnings,
        }


def _safe_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _safe_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def find_forbidden_committed_media(changed_files: list[str]) -> list[str]:
    """Return any changed files that violate the no-binary-recordings policy."""
    violations: list[str] = []
    for raw_path in changed_files:
        norm = raw_path.strip().replace("\\", "/")
        if not norm or norm in PRESERVED_MARKETING_MEDIA:
            continue
        p = Path(norm)
        ext = p.suffix.lower()
        parts_lower = {part.lower() for part in p.parts}
        if ext in FORBIDDEN_MEDIA_EXTENSIONS:
            violations.append(norm)
        elif (
            p.name.lower() == "trace.zip"
            or ".pr-evidence" in parts_lower
            or norm.lower().startswith("artifacts/pr-evidence/")
        ):
            violations.append(norm)
    return violations


def git_changed_files(repo_root: Path, base_ref: str, head_ref: str = "HEAD") -> list[str]:
    """Return file paths added/modified between ``base_ref`` and ``head_ref``."""
    for ref_name, ref_val in (("base_ref", base_ref), ("head_ref", head_ref)):
        if not ref_val or ref_val.startswith("-"):
            raise ValueError(f"Invalid git ref for {ref_name}: {ref_val!r}")
    result = subprocess.run(
        [
            "git",
            "-c",
            "core.quotePath=false",
            "diff",
            "-z",
            "--name-only",
            "--diff-filter=ACMR",
            f"{base_ref}...{head_ref}",
            "--",
        ],
        cwd=str(repo_root),
        check=True,
        capture_output=True,
    )
    raw = result.stdout.decode("utf-8", errors="surrogateescape")
    return [entry for entry in raw.split("\0") if entry]


def validate_manifest(
    manifest: Any,
    *,
    expected_sha: str | None = None,
    changed_files: list[str] | None = None,
    raw_text_to_scan: str = "",
    pr_context: bool = False,
) -> ValidationResult:
    """Validate an evidence manifest against all policy requirements."""
    errors: list[str] = []
    warnings: list[str] = []

    if changed_files is not None:
        for path in find_forbidden_committed_media(changed_files):
            errors.append(
                f"Binary recording/evidence artifact must not be committed to Git: '{path}'"
            )

    if raw_text_to_scan:
        raw_secret_hits = scan_for_secrets(raw_text_to_scan)
        if raw_secret_hits:
            errors.append(
                f"Potential secret/credential material detected in PR text ({', '.join(raw_secret_hits)}). "
                "Redact and regenerate."
            )

    if manifest is None:
        errors.append(
            "Missing PR video evidence manifest. Run 'python3 -B tooling/pr-video-evidence/cli.py record' "
            "and embed the generated markdown block in the PR description."
        )
        return ValidationResult(passed=False, errors=errors, warnings=warnings, checked_commit=expected_sha or "")

    if not isinstance(manifest, dict):
        errors.append(f"PR video evidence manifest must be a JSON object (got {type(manifest).__name__}).")
        return ValidationResult(passed=False, errors=errors, warnings=warnings, checked_commit=expected_sha or "")

    # 1. Required fields
    for key in REQUIRED_TOP_LEVEL_FIELDS:
        if key not in manifest or manifest[key] is None or manifest[key] == "":
            errors.append(f"Missing required manifest field: '{key}'")

    if manifest.get("profile") != DEFAULT_PROFILE:
        errors.append(
            f"Manifest profile must be '{DEFAULT_PROFILE}' (got '{manifest.get('profile')}')"
        )

    # 2. Exact commit SHA freshness
    manifest_sha = str(manifest.get("commit_sha", "")).strip()
    if expected_sha:
        exp = expected_sha.strip()
        if not manifest_sha:
            errors.append("Manifest 'commit_sha' is empty.")
        elif manifest_sha != exp:
            errors.append(
                f"Stale evidence: manifest commit_sha '{manifest_sha}' does not match "
                f"expected head commit '{exp}'. Regenerate narrated evidence for the current commit."
            )

    # 3. Video vs. documented waiver
    video = manifest.get("video")
    waiver = manifest.get("waiver")
    has_valid_waiver_obj = isinstance(waiver, dict)
    if waiver is not None and not has_valid_waiver_obj:
        errors.append("Manifest 'waiver' must be an object or null.")
    elif has_valid_waiver_obj:
        reason = str(waiver.get("reason", "")).strip()
        equiv = waiver.get("equivalent_artifacts")
        if len(reason) < 12:
            errors.append("Waiver 'reason' must clearly explain why video evidence is inapplicable.")
        if not isinstance(equiv, list) or not equiv:
            errors.append("Waiver must include at least one item in 'equivalent_artifacts'.")
    else:
        if not isinstance(video, dict):
            errors.append("Manifest must include a 'video' object (or a documented 'waiver').")
        else:
            codec = str(video.get("codec", "")).lower()
            audio_codec = str(video.get("audio_codec", "")).lower()
            width = _safe_int(video.get("width"))
            height = _safe_int(video.get("height"))
            fps = _safe_float(video.get("fps"))
            duration = _safe_float(video.get("duration_seconds"))
            audio_duration = _safe_float(video.get("audio_duration_seconds"))

            if codec != "h264":
                errors.append(f"Video codec must be 'h264' (got '{codec}').")
            if audio_codec != "aac":
                errors.append(f"Audio codec must be 'aac' (got '{audio_codec}').")
            if width < 1280 or height < 720:
                errors.append(f"Video resolution too low ({width}x{height}); default is 1920x1080.")
            elif (width, height) != (1920, 1080):
                warnings.append(f"Video resolution is {width}x{height} (default standard is 1920x1080).")
            if fps < 24.0:
                errors.append(f"Video frame rate too low ({fps} fps); default is 30 fps.")
            if duration <= 0.0:
                errors.append("Video duration must be greater than 0 seconds.")
            elif duration < 15.0:
                warnings.append(f"Video duration ({duration:.1f}s) is shorter than typical 30-120s window.")
            elif duration > 180.0:
                warnings.append(
                    f"Video duration ({duration:.1f}s) exceeds 180s; consider splitting into focused clips."
                )
            if audio_duration <= 0.0:
                errors.append("Narrated video must include a non-empty audio stream (audio_duration_seconds > 0).")
            elif duration > 0.0 and abs(duration - audio_duration) > 2.0:
                warnings.append(
                    f"Audio duration ({audio_duration:.1f}s) differs from video duration ({duration:.1f}s) by >2s."
                )

            url_str = str(video.get("url") or "").strip()
            path_str = str(video.get("path") or "").strip()
            if pr_context:
                if not url_str:
                    errors.append("PR video metadata must include an accessible 'url' or delivered attachment marker.")
                elif url_str.startswith("file://"):
                    errors.append(
                        "PR video 'url' must not be a local 'file://' path; provide an accessible link or 'attached-in-review-thread'."
                    )
            else:
                if not url_str and not path_str:
                    errors.append("Video metadata must include an accessible 'url' or local 'path'.")

            tts = manifest.get("tts")
            if not isinstance(tts, dict) or not str(tts.get("provider") or "").strip():
                errors.append("Narrated video evidence must record 'tts.provider' (e.g., 'kokoro').")
            else:
                tts_provider = str(tts.get("provider") or "").strip().lower()
                is_robotic = tts_provider in {"espeak-ng", "espeak"} or tts.get("human_grade") is False
                if is_robotic:
                    raw_reason = tts.get("fallback_reason")
                    fallback_reason = raw_reason.strip() if isinstance(raw_reason, str) else ""
                    if len(fallback_reason) < 12:
                        errors.append(
                            "Robotic or non-human-grade TTS ('espeak-ng') is disallowed without a documented "
                            "string 'tts.fallback_reason' (>=12 chars). Use full-precision Kokoro ONNX neural TTS."
                        )
                    else:
                        warnings.append(
                            f"Robotic fallback TTS ('{tts_provider}') was used: {fallback_reason}"
                        )

    # 4. Acceptance criteria & assertions
    criteria = manifest.get("acceptance_criteria")
    if not isinstance(criteria, list):
        errors.append("Manifest 'acceptance_criteria' must be a list.")
    else:
        if not has_valid_waiver_obj and not criteria:
            errors.append("Manifest must list at least one demonstrated entry in 'acceptance_criteria'.")
        for idx, item in enumerate(criteria):
            if not isinstance(item, dict):
                errors.append(f"acceptance_criteria[{idx}] must be an object.")
            elif not item.get("passed"):
                errors.append(f"Acceptance criterion failed: '{item.get('criterion', 'unknown')}'")

    assertions = manifest.get("assertion_results")
    if not isinstance(assertions, list):
        errors.append("Manifest 'assertion_results' must be a list.")
    else:
        if not has_valid_waiver_obj and not assertions:
            errors.append("Manifest must record at least one verified check in 'assertion_results'.")
        for idx, assertion in enumerate(assertions):
            if not isinstance(assertion, dict):
                errors.append(f"assertion_results[{idx}] must be an object.")
            elif not assertion.get("passed"):
                errors.append(f"Assertion failed: '{assertion.get('description', 'unknown')}'")

    # 5. Automated test suites
    suites = manifest.get("test_suites")
    if not isinstance(suites, list) or not suites:
        errors.append("Manifest must record executed automated verification commands in 'test_suites'.")
    else:
        passed_suites = 0
        for idx, suite in enumerate(suites):
            if not isinstance(suite, dict):
                errors.append(f"test_suites[{idx}] must be an object.")
                continue
            status = str(suite.get("status", "")).lower().strip()
            if status not in ALLOWED_TEST_STATUSES:
                errors.append(
                    f"Automated test suite '{suite.get('command', 'unknown')}' has disallowed status '{status or 'missing'}'."
                )
            elif status == "passed":
                passed_suites += 1
            elif status == "skipped" and not str(suite.get("detail") or "").strip():
                errors.append(
                    f"Skipped test suite '{suite.get('command', 'unknown')}' must explain why in 'detail'."
                )
        if passed_suites == 0 and not has_valid_waiver_obj:
            errors.append("At least one automated test suite in 'test_suites' must pass.")

    # 6. Independent engineering review gate
    review = manifest.get("review_report")
    if not isinstance(review, dict):
        errors.append("Manifest must include 'review_report' from independent engineering review.")
    else:
        reviewers = review.get("reviewer_identities")
        if not isinstance(reviewers, list) or not reviewers:
            errors.append("Independent engineering review requires a non-empty list in 'reviewer_identities'.")
        else:
            normalized_reviewers = {str(r).strip().lower() for r in reviewers if str(r).strip()}
            missing_core = sorted(MANDATORY_CORE_REVIEWERS - normalized_reviewers)
            if missing_core:
                errors.append(
                    f"Independent engineering review missing mandatory core reviewer(s): {', '.join(missing_core)}."
                )

        reviewed_sha = str(review.get("reviewed_commit_sha") or "").strip()
        target_sha = (expected_sha or manifest_sha).strip()
        if not reviewed_sha:
            errors.append("Independent engineering review must record 'reviewed_commit_sha'.")
        elif target_sha and reviewed_sha != target_sha:
            errors.append(
                f"Stale independent review: reviewed_commit_sha '{reviewed_sha}' does not match "
                f"commit '{target_sha}'."
            )

        unresolved = review.get("unresolved_blocking_findings")
        if unresolved is None:
            unresolved = []
        if not isinstance(unresolved, list):
            errors.append("review_report.unresolved_blocking_findings must be a list.")
        elif unresolved:
            errors.append(
                f"Unresolved blocking (P0/P1) review findings remain: {', '.join(map(str, unresolved))}"
            )

        rec = str(review.get("final_recommendation", "")).lower().strip()
        if rec not in APPROVED_RECOMMENDATIONS:
            errors.append(
                f"Independent engineering review recommendation must be approved "
                f"(got '{rec or 'missing'}'; allowed: {', '.join(sorted(APPROVED_RECOMMENDATIONS))})."
            )

    # 7. Secret & credential redaction scan on manifest JSON
    manifest_secret_hits = scan_for_secrets(json.dumps(manifest))
    if manifest_secret_hits:
        errors.append(
            f"Potential secret/credential material detected in evidence manifest ({', '.join(manifest_secret_hits)}). "
            "Redact and regenerate."
        )

    return ValidationResult(
        passed=len(errors) == 0,
        errors=errors,
        warnings=warnings,
        checked_commit=expected_sha or manifest_sha,
    )


def validate_pr_body(
    pr_body: str,
    *,
    expected_sha: str | None = None,
    changed_files: list[str] | None = None,
) -> ValidationResult:
    """Parse and validate embedded PR video evidence manifest from a PR description."""
    try:
        manifest = extract_manifest_from_pr_body(pr_body)
    except (json.JSONDecodeError, ValueError) as exc:
        errors = [f"Malformed JSON in pr-video-evidence PR description block: {exc}"]
        if changed_files is not None:
            for path in find_forbidden_committed_media(changed_files):
                errors.append(
                    f"Binary recording/evidence artifact must not be committed to Git: '{path}'"
                )
        secret_hits = scan_for_secrets(pr_body)
        if secret_hits:
            errors.append(
                f"Potential secret/credential material detected in PR text ({', '.join(secret_hits)}). "
                "Redact and regenerate."
            )
        return ValidationResult(
            passed=False,
            errors=errors,
            checked_commit=expected_sha or "",
        )
    return validate_manifest(
        manifest,
        expected_sha=expected_sha,
        changed_files=changed_files,
        raw_text_to_scan=pr_body,
        pr_context=True,
    )
