# Engineering & Agent Verification Policy — Dante for Creators

This repository (`PlaybookMediaLLC/textream`, **Dante for Creators**) enforces a permanent, evidence-driven engineering verification workflow across every branch, pull request, coding agent, and model.

---

## 1. Repository Architecture & Existing Infrastructure

| Surface | Path | Verification / Capture |
| --- | --- | --- |
| Shared Swift core (Smart Follow, Script Library, Presets, Sync, Exports, Protocols) | `Textream/Shared/` | `xcodebuild test` (`TextreamTests`, `TextreamiOSTests`), speech-tracking benchmark |
| macOS app (`Textream` scheme, Universal `arm64 + x86_64`, App Sandbox + Hardened Runtime) | `Textream/Textream/` | `TextreamTests`, `TextreamUITests`, `DanteScreenshotCaptureTests.swift` |
| iOS / iPadOS app (`TextreamiOS` scheme, iOS 26.0+) | `Textream/TextreamiOS/` | `TextreamiOSTests`, iOS Simulator (`xcrun simctl`), `.github/workflows/capture-screenshots.yml` |
| LAN Remote & Director web surfaces | `Textream/Textream/BrowserServer.swift`, `DirectorServer.swift` | Playwright capture against live server or isolated harness |
| Marketing & Creator Guide web site | `docs/` (`index.html`, `docs/index.html`, `support.html`, `privacy.html`) | Playwright capture against isolated HTTP server |
| Release signing & notarization scripts | `Textream/build.sh`, `.github/workflows/release.yml`, `fastlane/` | `python3 -B -m unittest discover -s tests -p 'test_release_signing.py' -v` |
| Speech-tracking & desktop benchmarks | `benchmarks/speech-tracking/`, `benchmarks/desktop/` | `go run run.go -check`, `go run run.go micro` |
| Engineering PR video verification pipeline | `tooling/pr-video-evidence/` | `npm run devx:video-evidence` / `python3 tooling/pr-video-evidence/cli.py` |

### Preserved Assets & Non-Duplication Rules
- **Preserve silent marketing media:** `docs/video.mp4` and `docs/video.gif` are silent marketing assets. Do **not** alter, replace, or apply engineering verification duration/narration constraints to marketing media.
- **Integrate with existing capture tooling:** macOS/iOS static screenshot captures live in `Textream/TextreamTests/DanteScreenshotCaptureTests.swift` and `.github/workflows/capture-screenshots.yml`. Narrated engineering PR verification extends this infrastructure through `tooling/pr-video-evidence/` (profile: `engineering-verification`) rather than creating conflicting capture stacks.
- **Architectural invariants:** Never weaken App Sandbox entitlements, Developer ID signing / Apple notarization gates (`REQUIRE_NOTARIZATION=1`), privacy manifests (`PrivacyInfo.xcprivacy`), or speech-tracking benchmark regression thresholds.

---

## 2. Mandatory Implementation, Independent Review & Narrated Video Evidence

**Every implementation thread — across every branch, contributor, agent, and model — MUST execute the `pr-video-evidence` skill (`.agents/skills/pr-video-evidence/SKILL.md`) before declaring implementation work complete or marking a pull request ready for review.**

### 2.1 Independent Engineering Review (Mandatory Before Video & PR Readiness)
Every substantive implementation MUST undergo independent engineering review before generating final readiness evidence:
1. **Mandatory core review roles** (dispatch as independent subagents):
   - `senior-code-critic` — implementation correctness, architectural integrity, security, performance, concurrency, error handling, maintainability, and test quality.
   - `review-changes` — structural and blast-radius analysis (changed functions, callers/callees, affected execution flows, shared dependencies, coverage gaps; uses code-graph tooling if available, otherwise explicit source-based impact analysis).
   - `ponytail-review` — simplicity and production-quality evaluation in strict priority order: (1) correctness, (2) safety (macOS/iOS sandbox, entitlements, signing, privacy, secrets), (3) behavior under production load, (4) adequate testing, (5) performance, and (6) simplicity.
2. **Domain specialists** (dispatch according to affected surface):
   - SwiftUI / UI / Accessibility specialist for macOS or iOS view changes.
   - Speech / Audio / Performance specialist for `PromptMatcher`, `LocalSpeechEngine`, `SpeechRecognizer`, or `benchmarks/`.
   - Networking / Security specialist for `BrowserServer`, `DirectorServer`, `OBSWebSocketClient`, `dante://` deep links, or CI secrets.
   - Web / Docs / DevX specialist for `docs/`, `tooling/`, or `.github/workflows/`.
3. **Separation of duties:**
   - The implementing agent MUST NOT be the sole reviewer of its own implementation.
   - Review-only subagents MUST NOT recursively initiate the full implementation or video-recording workflow.
   - Consolidate all findings, resolve every blocking defect, and return corrections for independent re-review before recording final PR video evidence.

### 2.2 Mandatory Verification Procedure (Every Pull Request)
For every pull request:
1. **Inspect scope:** Review the original task, acceptance criteria, implementation diff, and all affected functionality.
2. **Run actual implementation:** Start the actual application or target surface from the proposed implementation in an isolated environment with seeded test data. Never use simulated UIs or reconstructed mockups.
3. **Execute applicable automated tests:**
   - Python / tooling / signing tests: `python3 -B -m unittest discover -s tests -p 'test_*.py' -v`
   - macOS unit tests (on macOS): `xcodebuild test -project Textream/Textream.xcodeproj -scheme Textream -destination 'platform=macOS' -only-testing:TextreamTests CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM="" CODE_SIGN_STYLE=Manual`
   - iOS unit tests (on macOS): `xcodebuild test -project Textream/Textream.xcodeproj -scheme TextreamiOS -destination 'platform=iOS Simulator,...' -only-testing:TextreamiOSTests CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM="" CODE_SIGN_STYLE=Manual`
   - Speech-tracking gate (when speech/matcher files change): `cd benchmarks/speech-tracking && go run run.go -check`
   - Desktop micro benchmark (when macOS rendering/broadcast files change): `cd benchmarks/desktop && go run run.go micro`
   - If a platform-specific suite cannot execute in the current host (for example, `xcodebuild` on a Linux VM), record the exact platform limitation explicitly in the evidence manifest and verify via GitHub Actions macOS runners — never claim a skipped test passed.
4. **Generate narrated video evidence:** Invoke `.agents/skills/pr-video-evidence/SKILL.md` and run `tooling/pr-video-evidence/cli.py` (or `npm run devx:video-evidence`) to produce a narrated, visually annotated MP4 demonstrating the actual running implementation.
5. **Review the rendered recording:** Inspect `ffprobe` streams, verify extracted scene keyframes visually, check readability, captions, audio synchronization, and ensure zero secrets or sensitive data appear.
6. **Deliver evidence:**
   - Attach/deliver the playable MP4 video, consolidated engineering review report, and verification results in the active review thread.
   - Include an accessible video link and the machine-readable `pr-video-evidence` metadata block (generated by `cli.py markdown`) in the pull request description.
7. **Readiness gate:** Mark the pull request ready for review **only** after independent review, applicable automated tests, and narrated video evidence all pass for the exact head commit SHA. Keep incomplete or blocked pull requests in **draft**.

---

## 3. Video Production & Narration Standards

- **Real running application only:** Use Playwright (`tooling/pr-video-evidence/playwright_capture.py`) for web, LAN Remote/Director, and live terminal/verification surfaces, or native macOS / iOS Simulator capture (`xcrun simctl io recordVideo` / `screencapture`) ingested via `cli.py narrate`. Never submit mockups or fake screens.
- **Required visual & audio elements:**
  - Clear, synchronized spoken narration.
  - Visible cursor movements and click indicators (for interactive UI demos).
  - Bounding boxes or highlights around relevant interface elements.
  - Legible burned-in captions plus SRT and WebVTT caption sidecars.
  - Smooth, restrained zooming where necessary for readability.
  - Actual user interactions and observed results, including relevant error states and edge cases.
  - Explicit demonstration of each acceptance criterion.
- **Technical specification:**
  - Container/codecs: **MP4** with **H.264** (`libx264`, `yuv420p`, `+faststart`) video and **AAC** audio.
  - Resolution & frame rate: **1920 × 1080 at 30 fps** by default.
  - Duration: Concise, typically **30–120 seconds** for a straightforward change; split larger implementations into multiple focused recordings.
  - **No** background music, promotional language, unnecessary transitions, or decorative animations.
- **Text-to-Speech (TTS) & Human Voice Quality:**
  - Narration MUST sound like a natural, calm human engineer — never robotic, clipped, or rushed.
  - Default local provider: full-precision **FP32 Kokoro ONNX** (`kokoro-v1.0.onnx` via `kokoro-onnx`) with natural blended neural voice (`af_heart:0.65+af_bella:0.35`), calm conversational pace (`0.98`), natural sentence/clause pauses, spoken acronym normalization (keeping captions verbatim), and broadcast `-16 LUFS` audio mastering.
  - Local fallback on macOS: enhanced/neural `macos-say` voices.
  - Optional approved cloud neural TTS fallback (`openai` `gpt-4o-mini-tts` via `OPENAI_API_KEY`) only when explicitly requested via `--tts-provider openai`.
  - Robotic `espeak-ng` is **never** selected automatically and is rejected by `pr-video-evidence` CI unless an explicit `tts.fallback_reason` is documented.
- **Narration standards:**
  - Explain: (1) what was broken or missing, (2) what changed, (3) how the new behavior works, (4) what happens on user interaction, (5) which acceptance criteria are being demonstrated, and (6) any limitations or outstanding concerns.
  - Strictly describe **observed behavior**. Never claim an operation succeeded unless verified.
  - Synchronize spoken narration directly with the visible action and highlight; never narrate a feature while showing an unrelated screen.

---

## 4. Evidence Integrity, Security & Non-UI Changes

- **Mandatory metadata** (stored in `manifest.json` and embedded in the PR description):
  - Repository and branch
  - Exact head commit SHA (`commit_sha`)
  - Pull request number (once assigned)
  - Capture timestamp (UTC ISO-8601)
  - Application route / target surface
  - Test environment
  - Acceptance criteria
  - Assertion and test suite results
  - Independent review summary (reviewers, blocking defects resolved)
- **Preserved artifacts** (retained in `.pr-evidence/<run-id>/` and/or review thread artifacts, **never** committed to Git):
  - Raw footage (`.webm` / `.mov`)
  - Final rendered `.mp4`
  - Transcript (`.txt`), SRT (`.srt`), and WebVTT (`.vtt`) captions
  - Playwright trace (`trace.zip`) when browser-captured
  - Extracted scene keyframes for visual QA
- **Security & hygiene:**
  - Never expose credentials, tokens, Apple certificates/passwords, API keys, financial data, or real customer data.
  - **Never commit binary recording artifacts** (`.mp4`, `.mov`, `.webm`, `.wav`, `.m4a`, trace `.zip`) to the repository. `.gitignore` excludes `.pr-evidence/` and `artifacts/pr-evidence/`, and the `pr-video-evidence` CI check rejects newly committed media artifacts.
- **Backend, Swift core, and infrastructure changes:**
  - Demonstrate behavior via real terminal recordings, API/CLI invocations, unit/contract/benchmark test runs, or structured verification dashboards rendered through the same narrated MP4 pipeline (`tooling/pr-video-evidence/scenarios/terminal_verification.py`).
  - For genuinely non-demonstrable changes (e.g., pure typo/license metadata edits), document an explicit `waiver` (`reason` + `equivalent_artifacts`) in the evidence manifest and PR description. Never silently skip verification.

---

## 5. Pull Request Feedback Loop & Merge Policy

When a human reviewer annotates a video or submits review comments:
1. Inspect every marked frame, timestamp, and associated comment.
2. Locate the corresponding implementation files.
3. Convert all feedback into concrete acceptance criteria.
4. Implement the corrections.
5. Repeat applicable independent reviews and rerun all relevant automated verification.
6. Generate a **new** narrated video against the **new head commit SHA**. Never reuse an earlier commit's recording as evidence that subsequent changes work.
7. Deliver the updated recording in the same review thread and update the PR description evidence block.
8. Explicitly list which review comments have been addressed and which remain outstanding.
9. Repeat until approved.

### Strict Enforcement Rules
- **GitHub Actions check:** `.github/workflows/pr-video-evidence.yml` runs the `pr-video-evidence` check on every pull request to validate evidence availability, commit SHA freshness, required metadata, independent review sign-off, binary-artifact cleanliness, and applicable test results.
- **Failure handling:** If the recording or verification pipeline fails, report the exact blocker, keep the PR in **draft**, and never fabricate evidence or bypass quality gates.
- **Merge authorization:** Never merge any pull request without explicit human authorization.
