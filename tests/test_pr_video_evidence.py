"""Unit and contract tests for the Dante for Creators PR video evidence pipeline."""

from __future__ import annotations

import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
TOOLING = ROOT / "tooling" / "pr-video-evidence"
if str(TOOLING) not in sys.path:
    sys.path.insert(0, str(TOOLING))

import cli  # noqa: E402
from composer import (  # noqa: E402
    CaptionCue,
    _parse_duration,
    write_captions_and_transcript,
)
from evidence import (  # noqa: E402
    MARKER_END,
    MARKER_START,
    build_manifest,
    extract_manifest_from_pr_body,
    render_pr_markdown,
    scan_for_secrets,
)
from playwright_capture import build_route_url  # noqa: E402
import tts  # noqa: E402
from validator import (  # noqa: E402
    find_forbidden_committed_media,
    git_changed_files,
    validate_manifest,
    validate_pr_body,
)


def _sample_manifest(commit_sha: str = "a" * 40) -> dict:
    return build_manifest(
        repository="PlaybookMediaLLC/textream",
        branch="feat/pr-video-evidence-workflow",
        commit_sha=commit_sha,
        pr_number=19,
        application_route="/ -> /docs/ -> /support.html",
        test_environment="Ubuntu 24.04 · Chromium Playwright (isolated localhost)",
        acceptance_criteria=[
            {
                "criterion": "Landing page renders and navigates to Creator Guide",
                "timestamp": "00:00",
                "route": "/",
                "passed": True,
                "detail": "Observed Creator Guide heading",
            }
        ],
        assertion_results=[
            {
                "beat": 1,
                "description": "Hero heading visible",
                "expected": "Stay on script",
                "observed": "visible=True",
                "passed": True,
            }
        ],
        test_suites=[
            {
                "command": "python3 -B -m unittest discover -s tests -p 'test_*.py' -v",
                "status": "passed",
                "exit_code": 0,
                "detail": "Ran 18 tests\nOK",
            },
            {
                "command": "xcodebuild test -scheme Textream",
                "status": "skipped",
                "exit_code": None,
                "detail": "Requires macOS host; verified on GitHub Actions macos-26 runner",
            },
        ],
        video={
            "path": "/home/tester/.pr-evidence/latest/evidence.mp4",
            "url": "https://example.invalid/evidence.mp4",
            "codec": "h264",
            "audio_codec": "aac",
            "width": 1920,
            "height": 1080,
            "fps": 30.0,
            "duration_seconds": 48.2,
            "audio_duration_seconds": 48.2,
            "size_bytes": 2_400_000,
            "sha256": "b" * 64,
        },
        tts={"provider": "kokoro", "voice": "af_heart"},
        artifacts={
            "raw_video": ".pr-evidence/latest/raw_capture.webm",
            "trace": ".pr-evidence/latest/trace.zip",
            "transcript": ".pr-evidence/latest/transcript.txt",
            "captions_srt": ".pr-evidence/latest/captions.srt",
            "captions_vtt": ".pr-evidence/latest/captions.vtt",
        },
        review_report={
            "repository": "PlaybookMediaLLC/textream",
            "base_branch": "master",
            "reviewed_commit_sha": commit_sha,
            "reviewer_identities": ["senior-code-critic", "review-changes", "ponytail-review"],
            "findings_by_severity": {"P0": 0, "P1": 0, "P2": 0, "P3": 1},
            "unresolved_blocking_findings": [],
            "final_recommendation": "approved",
        },
        known_limitations=["macOS Xcode suite skipped on Linux devbox."],
    )


class PRVideoEvidenceValidatorTests(unittest.TestCase):
    def test_valid_manifest_round_trips_and_sanitizes_local_paths(self) -> None:
        sha = "1234567890abcdef1234567890abcdef12345678"
        manifest = _sample_manifest(commit_sha=sha)
        manifest["video"]["url"] = "file:///home/tester/.pr-evidence/latest/evidence.mp4"
        md = render_pr_markdown(manifest)

        self.assertIn("### Narrated verification", md)
        self.assertIn("### Demonstrated behavior", md)
        self.assertIn("### Automated checks", md)
        self.assertIn("### Consolidated engineering review", md)
        self.assertIn("### Known limitations", md)
        # Local usernames/paths and file:// URLs must not leak into PR markdown
        self.assertNotIn("/home/tester", md)
        self.assertNotIn("file://", md)
        # Multi-line test suite detail must collapse onto one markdown bullet line
        self.assertIn("(Ran 18 tests OK)", md)

        extracted = extract_manifest_from_pr_body(md)
        self.assertIsNotNone(extracted)
        assert extracted is not None
        self.assertEqual(extracted["commit_sha"], sha)
        self.assertEqual(extracted["video"]["path"], "evidence.mp4")

        res = validate_pr_body(md, expected_sha=sha, changed_files=["AGENTS.md", "docs/index.html"])
        self.assertTrue(res.passed, res.errors)
        self.assertEqual(res.errors, [])

    def test_stale_commit_sha_is_rejected(self) -> None:
        manifest = _sample_manifest(commit_sha="a" * 40)
        res = validate_manifest(manifest, expected_sha="b" * 40)
        self.assertFalse(res.passed)
        self.assertTrue(any("Stale evidence" in e for e in res.errors))

    def test_review_and_test_gate_allowlists_prevent_bypasses(self) -> None:
        sha = "a" * 40
        manifest = _sample_manifest(commit_sha=sha)
        manifest["review_report"]["final_recommendation"] = "pending"
        manifest["review_report"]["reviewed_commit_sha"] = "0" * 40
        manifest["review_report"]["reviewer_identities"] = ["self"]
        manifest["test_suites"] = [{"command": "pytest", "status": "error", "detail": "boom"}]
        manifest["video"]["audio_duration_seconds"] = 0.0
        manifest["assertion_results"] = []

        res = validate_manifest(manifest, expected_sha=sha)
        self.assertFalse(res.passed)
        joined = "\n".join(res.errors)
        self.assertIn("recommendation must be approved", joined)
        self.assertIn("Stale independent review", joined)
        self.assertIn("missing mandatory core reviewer", joined)
        self.assertIn("disallowed status 'error'", joined)
        self.assertIn("At least one automated test suite", joined)
        self.assertIn("audio_duration_seconds > 0", joined)
        self.assertIn("assertion_results", joined)

    def test_pr_body_rejects_file_url_in_video_metadata(self) -> None:
        sha = "a" * 40
        manifest = _sample_manifest(commit_sha=sha)
        manifest["video"]["url"] = "file:///tmp/demo.mp4"
        raw_body = f"{MARKER_START}\n```json\n{json.dumps(manifest)}\n```\n{MARKER_END}"
        res = validate_pr_body(raw_body, expected_sha=sha)
        self.assertFalse(res.passed)
        self.assertTrue(any("file://" in e for e in res.errors))

    def test_untrusted_malformed_pr_bodies_do_not_crash_and_still_run_security_checks(self) -> None:
        # 1. Reversed markers return None
        reversed_body = f"{MARKER_END} hello {MARKER_START} {{\"a\": 1}}"
        self.assertIsNone(extract_manifest_from_pr_body(reversed_body))

        # 2. Non-dict JSON payloads never raise unhandled exceptions
        for payload in ("[]", "123", '"hello"', "null"):
            with self.subTest(payload=payload):
                body = f"{MARKER_START}\n{payload}\n{MARKER_END}"
                res = validate_pr_body(body, expected_sha="a" * 40)
                self.assertFalse(res.passed)

        # 3. Wrong nested field types never raise AttributeError/ValueError
        bad_types = _sample_manifest()
        bad_types["waiver"] = True
        bad_types["video"] = {"codec": "h264", "audio_codec": "aac", "width": "1920px", "fps": "bad"}
        bad_types["tts"] = "kokoro"
        bad_types["acceptance_criteria"] = ["not-a-dict"]
        bad_types["assertion_results"] = "bad"
        bad_types["test_suites"] = ["pytest"]
        bad_types["review_report"] = "approved"
        res_types = validate_manifest(bad_types, expected_sha="a" * 40)
        self.assertFalse(res_types.passed)
        self.assertGreaterEqual(len(res_types.errors), 5)

        # 4. Malformed JSON STILL reports forbidden committed media and leaked secrets
        fake_pat = "ghp_" + "A1b2C3d4E5f6G7h8I9j0K1l2"
        corrupt_body = f"{MARKER_START}\n{{not-valid-json}}\n{MARKER_END}\nleaked={fake_pat}"
        res_corrupt = validate_pr_body(
            corrupt_body,
            expected_sha="a" * 40,
            changed_files=["recordings/demo.mp4"],
        )
        self.assertFalse(res_corrupt.passed)
        joined = "\n".join(res_corrupt.errors)
        self.assertIn("Malformed JSON", joined)
        self.assertIn("recordings/demo.mp4", joined)
        self.assertIn("github_pat", joined)

    def test_video_spec_violations_are_rejected(self) -> None:
        manifest = _sample_manifest()
        manifest["video"]["codec"] = "vp9"
        manifest["video"]["audio_codec"] = "opus"
        manifest["video"]["width"] = 640
        manifest["video"]["fps"] = 10
        manifest["tts"] = {}
        res = validate_manifest(manifest, expected_sha="a" * 40)
        self.assertFalse(res.passed)
        joined = "\n".join(res.errors)
        self.assertIn("h264", joined)
        self.assertIn("aac", joined)
        self.assertIn("resolution", joined)
        self.assertIn("frame rate", joined)
        self.assertIn("tts.provider", joined)

    def test_documented_waiver_passes_and_empty_waiver_fails(self) -> None:
        manifest = _sample_manifest()
        manifest["video"] = None
        manifest["tts"] = None
        manifest["acceptance_criteria"] = []
        manifest["assertion_results"] = []
        manifest["waiver"] = {
            "reason": "License copyright year text-only change with zero runtime impact.",
            "equivalent_artifacts": ["git diff LICENSE", "CI unit tests passed"],
        }
        ok = validate_manifest(manifest, expected_sha="a" * 40)
        self.assertTrue(ok.passed, ok.errors)

        manifest["waiver"] = {"reason": "skip", "equivalent_artifacts": []}
        bad = validate_manifest(manifest, expected_sha="a" * 40)
        self.assertFalse(bad.passed)
        self.assertGreaterEqual(len(bad.errors), 2)

    def test_secret_scanner_blocks_env_and_json_credentials(self) -> None:
        fake_pat = "ghp_" + "A1b2C3d4E5f6G7h8I9j0K1l2"
        self.assertIn("github_pat", scan_for_secrets(f"token={fake_pat}"))
        json_apple = json.dumps(
            {
                "APPLE_APP_PASSWORD": "abcd-efgh-ijkl-mnop",
                "MACOS_CERT_PASSWORD": "super-secret-cert-pass",
            }
        )
        hits = scan_for_secrets(json_apple)
        self.assertIn("apple_app_password", hits)
        self.assertIn("macos_signing_secret", hits)

    def test_binary_media_guard_blocks_recordings_including_non_ascii_paths(self) -> None:
        changed = [
            "AGENTS.md",
            "docs/video.mp4",
            "docs/video.gif",
            "recordings/démo.mp4",
            "nested/.pr-evidence/run/output.txt",
            "TRACE.ZIP",
            "tmp/audio.wav",
        ]
        violations = find_forbidden_committed_media(changed)
        self.assertNotIn("docs/video.mp4", violations)
        self.assertNotIn("docs/video.gif", violations)
        self.assertIn("recordings/démo.mp4", violations)
        self.assertIn("nested/.pr-evidence/run/output.txt", violations)
        self.assertIn("TRACE.ZIP", violations)
        self.assertIn("tmp/audio.wav", violations)

        # Verify git_changed_files handles non-ASCII filenames with core.quotePath=false -z
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
            subprocess.run(["git", "config", "user.email", "test@example.invalid"], cwd=repo, check=True)
            subprocess.run(["git", "config", "user.name", "Test"], cwd=repo, check=True)
            (repo / "README.md").write_text("base\n", encoding="utf-8")
            subprocess.run(["git", "add", "README.md"], cwd=repo, check=True)
            subprocess.run(["git", "commit", "-q", "-m", "base"], cwd=repo, check=True)
            base_sha = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip()

            media_file = repo / "démo.mp4"
            media_file.write_bytes(b"fake")
            subprocess.run(["git", "add", "démo.mp4"], cwd=repo, check=True)
            subprocess.run(["git", "commit", "-q", "-m", "add media"], cwd=repo, check=True)

            diff_files = git_changed_files(repo, base_sha, "HEAD")
            self.assertIn("démo.mp4", diff_files)
            self.assertIn("démo.mp4", find_forbidden_committed_media(diff_files))

    def test_caption_generation_and_duration_parsing(self) -> None:
        self.assertEqual(_parse_duration("N/A", fallback=0.0), 0.0)
        self.assertEqual(_parse_duration("", fallback=1.5), 1.5)
        self.assertEqual(_parse_duration(None, fallback=2.0), 2.0)
        self.assertAlmostEqual(_parse_duration("12.345"), 12.345)

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            cues = [
                CaptionCue(
                    index=0,
                    start_seconds=0.0,
                    end_seconds=4.5,
                    text="Clicking the Creator Guide CTA navigates to the live documentation route.",
                    wav_path=root / "0.wav",
                ),
                CaptionCue(
                    index=1,
                    start_seconds=5.0,
                    end_seconds=9.25,
                    text="Requesting a missing route returns HTTP 404 deterministically.",
                    wav_path=root / "1.wav",
                ),
            ]
            srt = root / "captions.srt"
            vtt = root / "captions.vtt"
            txt = root / "transcript.txt"
            write_captions_and_transcript(cues, srt, vtt, txt)

            self.assertIn("00:00:00,000 --> 00:00:04,500", srt.read_text(encoding="utf-8"))
            self.assertTrue(vtt.read_text(encoding="utf-8").startswith("WEBVTT\n"))
            self.assertIn("HTTP 404 deterministically", txt.read_text(encoding="utf-8"))

    def test_tts_checksum_verification_secret_blocking_and_hyphen_safety(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            dest = Path(tmp) / "model.bin"
            payload = b"hello kokoro model payload"
            good_sha = hashlib.sha256(payload).hexdigest()

            class _FakeResp(io.BytesIO):
                def __enter__(self):
                    return self

                def __exit__(self, *args):
                    return False

            with mock.patch.object(tts.urllib.request, "urlopen", return_value=_FakeResp(payload)):
                with self.assertRaises(RuntimeError):
                    tts._download_if_missing("https://example.invalid/m", dest, expected_sha256="0" * 64)
                self.assertFalse(dest.exists())

            with mock.patch.object(tts.urllib.request, "urlopen", return_value=_FakeResp(payload)):
                result = tts._download_if_missing("https://example.invalid/m", dest, expected_sha256=good_sha)
                self.assertEqual(result, dest)
                self.assertEqual(dest.read_bytes(), payload)

            # Secret blocking before OpenAI outbound HTTP call
            with mock.patch.dict(os.environ, {"OPENAI_API_KEY": "test-dummy-key"}):
                engine = tts.TTSEngine(provider="openai")
                fake_pat = "ghp_" + "A1b2C3d4E5f6G7h8I9j0K1l2"
                with mock.patch.object(tts.urllib.request, "urlopen") as mock_open:
                    with self.assertRaises(RuntimeError):
                        engine.synthesize(f"Leaked token {fake_pat}", Path(tmp) / "out.wav")
                    mock_open.assert_not_called()

            # Leading-hyphen narration uses --stdin with espeak-ng
            with mock.patch.object(tts.shutil, "which", side_effect=lambda x: "/usr/bin/espeak-ng" if x == "espeak-ng" else None):
                eng = tts.TTSEngine(provider="espeak-ng")
                with mock.patch.object(tts.subprocess, "run") as mock_run:
                    eng._synthesize_espeak("-DanteSeedDemoScripts enables seeded demo scripts", Path(tmp) / "raw.wav")
                    called_argv = mock_run.call_args[0][0]
                    self.assertIn("--stdin", called_argv)
                    self.assertEqual(mock_run.call_args[1]["input"], "-DanteSeedDemoScripts enables seeded demo scripts")

    def test_cli_validate_handles_corrupt_json_and_path_traversal_guards(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            bad_manifest = Path(tmp) / "bad.json"
            bad_manifest.write_text("{corrupt", encoding="utf-8")
            proc = subprocess.run(
                [sys.executable, "-B", str(TOOLING / "cli.py"), "validate", "--manifest", str(bad_manifest)],
                capture_output=True,
                text=True,
            )
            self.assertEqual(proc.returncode, 1)
            data = json.loads(proc.stdout)
            self.assertFalse(data["passed"])
            self.assertTrue(any("Validation error" in e for e in data["errors"]))

            with self.assertRaises(ValueError):
                cli._resolve_repo_static_dir("../../etc")
            with self.assertRaises(FileNotFoundError):
                cli._load_review_report(Path(tmp) / "does-not-exist.json", "a" * 40, "PlaybookMediaLLC/textream")

        self.assertEqual(build_route_url("http://127.0.0.1:8080", "docs/"), "http://127.0.0.1:8080/docs/")
        self.assertEqual(build_route_url("http://127.0.0.1:8080/", "/support.html"), "http://127.0.0.1:8080/support.html")

    def test_terminal_verification_console_serves_200_and_404(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            url_file = Path(tmp) / "server_url.txt"
            env = os.environ.copy()
            env["PR_EVIDENCE_URL_FILE"] = str(url_file)
            env["PR_EVIDENCE_COMMIT"] = "abcdef1234567890"
            env["PR_EVIDENCE_BRANCH"] = "feat/test"
            env["PR_EVIDENCE_TEST_RESULTS"] = json.dumps(
                [{"command": "python3 -B -m unittest", "status": "passed", "detail": "OK <escaped>"}]
            )
            proc = subprocess.Popen(
                [sys.executable, "-B", str(TOOLING / "scenarios" / "terminal_verification.py")],
                env=env,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            try:
                deadline = time.monotonic() + 10.0
                base_url = ""
                while time.monotonic() < deadline:
                    if url_file.exists() and url_file.read_text(encoding="utf-8").strip():
                        base_url = url_file.read_text(encoding="utf-8").strip()
                        break
                    time.sleep(0.1)
                self.assertTrue(base_url.startswith("http://127.0.0.1:"))

                with urllib.request.urlopen(base_url + "/", timeout=5) as resp:
                    self.assertEqual(resp.status, 200)
                    body = resp.read().decode("utf-8")
                    self.assertIn("abcdef123456", body)
                    self.assertIn("OK &lt;escaped&gt;", body)

                with self.assertRaises(urllib.error.HTTPError) as ctx:
                    urllib.request.urlopen(base_url + "/missing", timeout=5)
                self.assertEqual(ctx.exception.code, 404)
            finally:
                proc.terminate()
                proc.wait(timeout=5)

    def test_repository_policy_and_workflow_files_are_wired(self) -> None:
        agents_md = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
        claude_md = (ROOT / "CLAUDE.md").read_text(encoding="utf-8")
        skill_md = (ROOT / ".agents/skills/pr-video-evidence/SKILL.md").read_text(encoding="utf-8")
        workflow = (ROOT / ".github/workflows/pr-video-evidence.yml").read_text(encoding="utf-8")
        gitignore = (ROOT / ".gitignore").read_text(encoding="utf-8")

        self.assertIn("pr-video-evidence", agents_md)
        self.assertIn("senior-code-critic", agents_md)
        self.assertIn("review-changes", agents_md)
        self.assertIn("ponytail-review", agents_md)
        self.assertIn("AGENTS.md", claude_md)
        self.assertIn("name: pr-video-evidence", skill_md)
        self.assertIn("name: pr-video-evidence", workflow)
        self.assertIn("concurrency:", workflow)
        self.assertIn(".pr-evidence/", gitignore)
        self.assertIn("__pycache__/", gitignore)


if __name__ == "__main__":
    unittest.main()
