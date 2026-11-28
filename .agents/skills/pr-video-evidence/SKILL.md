---
name: pr-video-evidence
description: >
  Use for every implementation task, feature, bug fix, refactor,
  and pull request, including subsequent review corrections.
  Produce narrated video evidence of the actual implementation,
  with visual annotations, passing assertions, synchronized
  captions, independent engineering review, and playable thread
  attachments before declaring work complete or marking a pull
  request ready for review.
---

# Narrated PR Video Evidence

## 1. Objective
Enable asynchronous engineering review without requiring the reviewer to check out branches, start applications, reproduce workflows, or manually verify every implementation.

Every applicable implementation must be accompanied by a concise, narrated, visually annotated recording that demonstrates the actual working functionality.

The reviewer should be able to inspect the code, watch the recording, annotate specific video frames, submit feedback, and review a corrected implementation.

This is a mandatory engineering verification workflow, not a marketing video production workflow.

## 2. When to Execute
Execute this skill:
- Before marking any pull request ready for review.
- Before reporting an implementation as complete.
- After implementing a feature or fixing a bug.
- After addressing pull request review comments.
- After receiving visual annotations or review feedback.
- After changes that invalidate previous verification evidence.

Execute automatically, even when the user has not explicitly requested a recording, demonstration, or verification. Do not wait for the reviewer to request evidence.

## 3. Understand the Implementation
Before recording:
1. Read the original task and acceptance criteria.
2. Inspect the implementation and relevant code changes.
3. Identify every affected user-facing workflow.
4. Identify relevant backend, Swift core, or CLI/CI behavior and side effects.
5. Identify important edge cases and failure states.
6. Determine what observable evidence demonstrates that each acceptance criterion has been satisfied.

Create a verification plan mapping acceptance criteria to tests, browser/app/terminal actions, and observable results. Do not merely demonstrate the happy path when the change also affects permissions, validation, entitlements, signing, error handling, or data persistence.

## 4. Prepare the Verification Environment
Use the actual implementation from the current branch:
- Start the required application and dependent services in an isolated environment.
- Use the repository's established setup and seed scripts (e.g., `-DanteSeedDemoScripts` for Dante macOS/iOS, isolated localhost HTTP server for `docs/` or LAN Remote/Director surfaces).
- Use isolated, deterministic test fixtures.
- Authenticate using approved test accounts or isolated local credentials.
- Verify the application is healthy before recording.
- Use fictional or sanitized data.
- Prevent real external side effects (payments, emails, notifications, App Store uploads, or live releases).

Never bypass authentication, permissions, entitlements, or application validation to make a demonstration succeed. Never substitute a mock interface for a working application. If environment setup fails, investigate and resolve the failure where possible; otherwise report the exact blocker.

## 5. Execute Automated Verification
Run all applicable repository-mandated checks, including:
- Type checking and compiler checks (`xcodebuild` on macOS hosts).
- Linting / static checks.
- Unit tests:
  - `python3 -B -m unittest discover -s tests -p 'test_*.py' -v`
  - `TextreamTests` (macOS) and `TextreamiOSTests` (iOS Simulator) on macOS hosts.
- Integration, contract, and benchmark tests:
  - `(cd benchmarks/speech-tracking && go run run.go -check)` when speech/matcher files change.
  - `(cd benchmarks/desktop && go run run.go micro)` when macOS rendering/broadcast files change.
- End-to-end tests and security/signing checks (`tests/test_release_signing.py`).

Reuse existing test infrastructure. For each demonstrated workflow, assert the expected result using the application UI, API/CLI response, file/state output, or another appropriate verification mechanism. A successful video recording does not replace automated tests. Never claim a behavior works unless it has been observed and verified.

---

## Mandatory Independent Engineering Review
Narrated video evidence must be generated only after the implementation has passed independent engineering review. A successful demonstration is not sufficient evidence of architectural correctness, security, maintainability, or production readiness.

### 1. Discover Repository-Specific Reviewers
Before implementation, inspect the repository's:
- `AGENTS.md`
- `CLAUDE.md`
- Nested product-specific instruction files
- `.claude/agents/`, `.claude/skills/`, `.claude/prompts/`
- `.agents/skills/`
- Other repository-defined review procedures

Load all applicable repository instructions. Identify the available review agents, their responsibilities, invocation conditions, and required quality gates. Reuse existing reviewer definitions rather than replacing them with generic prompts. Current repository and product-specific guardrails take precedence over outdated assumptions.

### 2. Review Orchestration
After implementation and initial verification, assemble an independent review team. The implementing agent acts as the review coordinator and dispatches independent reviewers in parallel where responsibilities do not require sequential execution.

Each reviewer must receive:
- Original task and acceptance criteria.
- Base branch and current commit SHA.
- Actual implementation diff.
- Relevant architecture and repository instructions.
- Affected components, callers, and execution paths.
- Existing and newly added tests.
- Initial verification results.
- Known risks and unresolved questions.

Reviewers must inspect the actual source code and tests — never rely solely on the implementing agent's summary. Reviewers should initially operate in read-only mode. The implementing agent coordinates all remediation to prevent conflicting edits. Do not recursively dispatch additional review teams from review-only subagents.

### 3. Mandatory Core Review Team
For every substantive code change in this repository (`PlaybookMediaLLC/textream`), dispatch the following three core review roles independently:

#### Senior Engineering Reviewer (`senior-code-critic`)
Responsibilities:
- Implementation correctness and architectural integrity.
- Maintainability, security, performance, error handling, concurrency, and race conditions.
- Test quality and coverage; unnecessary complexity.
- Must provide a critical assessment with concrete findings and a merge recommendation.

#### Structural & Blast-Radius Reviewer (`review-changes`)
Inspect:
- Risk-scored changed functions, callers, and callees.
- Affected execution flows, shared dependencies, and impact radius.
- Existing test coverage and untested high-risk behavior.
- Use code-graph tooling if available; otherwise explicitly report that limitation and perform targeted source-based impact analysis. Never fabricate graph results.

#### Simplicity & Production-Quality Reviewer (`ponytail-review`)
Evaluate in strict priority order:
1. Correctness.
2. Safety (sandbox, entitlements, signing, privacy, secrets).
3. Behavior under expected production load.
4. Adequate testing.
5. Performance.
6. Simplicity.

Identify unnecessary abstractions, duplicated code, unnecessary dependencies, speculative functionality, dead code, and maintainability problems. Every finding must cite a concrete failure scenario or demonstrable unnecessary cost. Prefer the smallest correction that solves the problem.

### 4. Specialist Reviewer Selection
Dispatch additional domain specialists according to affected functionality and risk profile (never omit an applicable specialist merely because the core team reported no findings):
- **SwiftUI / macOS / iOS UI & Accessibility:** Runtime lifecycle, layout, Dark/Light appearance, notch/floating overlays, iOS camera framing, accessibility.
- **Speech / Audio / Performance:** `PromptMatcher`, `LocalSpeechEngine`, `SpeechRecognizer`, `VoiceActivityDetector`, speech-tracking benchmarks, latency/memory.
- **Networking, Security, Signing & Privacy:** `BrowserServer`, `DirectorServer`, `OBSWebSocketClient`, `dante://` URLs, App Sandbox entitlements, `Textream/build.sh` Developer ID signing & Apple notarization, CI workflows & secrets, `PrivacyInfo.xcprivacy`.
- **Web, Docs & DevX Tooling:** `docs/`, `tooling/pr-video-evidence/`, `.github/workflows/`.
- **Code Quality Remediation:** Invoke targeted cleanup only when review identifies concrete duplication, type-safety, or complexity defects — never introduce unrelated refactoring.

### 5. Cross-Agent Compatibility
These review procedures must work across every supported coding agent and model (Antigravity, Claude Code, Codex, Capy, etc.). When native custom subagents exist, invoke them directly; otherwise dispatch independent read-only subagents carrying the full reviewer mandate. Never claim a reviewer was dispatched when no independent review occurred. If independent review is required but unavailable, report the blocker and keep the PR in draft.

### 6. Review Findings and Severity
Require every reviewer to provide structured findings containing:
- Reviewer identity
- Finding identifier
- Severity (`P0`, `P1`, `P2`, `P3`)
- File path and line numbers
- Affected behavior
- Concrete failure scenario
- Evidence supporting the finding
- Recommended correction
- Required verification

Severity definitions:
- **P0 — Critical:** Data/financial corruption, credential/secret exposure, signing/sandbox bypass, unauthorized actions, or critical failures. **Blocks readiness.**
- **P1 — High:** Material correctness, security, authorization, reliability, or evidence-integrity defects. **Blocks readiness.**
- **P2 — Medium:** Recoverable inconsistencies, limited operational failures, maintainability risks, and meaningful edge cases. Resolve before merge unless explicitly accepted by the authorized reviewer.
- **P3 — Low:** Non-critical readability, naming, and cleanup observations. Must not distract from higher-risk defects.

### 7. Consolidate and Adjudicate Findings
Collect all reviewer results into one consolidated review report:
- Deduplicate overlapping findings and verify against actual source code.
- Resolve disagreements using evidence; reject unsupported or speculative findings with documented justification.
- Identify shared root causes and prioritize corrections by severity.
- Neither blindly accept nor dismiss findings without code evidence.

### 8. Mandatory Remediation and Re-Review
Resolve all blocking (`P0`/`P1`) and applicable `P2` findings. Follow test-first / non-tautological testing standards. After remediation:
1. Rerun all relevant automated tests.
2. Return the corrected implementation to the applicable independent reviewers.
3. Require independent verification that original findings are resolved and no new defects were introduced.
4. Repeat until all blocking findings are closed.

Never self-certify blocking findings, weaken tests, or bypass quality gates. If review cannot converge, keep the PR in draft and report the unresolved findings.

### 9. Final Repository Quality Gates
Run all applicable Dante for Creators quality gates:
- `python3 -B -m unittest discover -s tests -p 'test_*.py' -v`
- `python3 tooling/pr-video-evidence/cli.py validate ...`
- On macOS / CI runners: `xcodebuild test` (`TextreamTests`, `TextreamiOSTests`), `benchmarks/speech-tracking`, and `benchmarks/desktop` where applicable.
- Do not weaken existing signing gates, benchmark bars, or CI protections.

### 10. Review Evidence Manifest
Preserve a structured review record (`review_report` inside `manifest.json` and `review-report.md`) containing:
- Repository, base branch, reviewed commit SHA
- Reviewer identities, reviewer source definitions, specialist selection rationale, review scope
- Findings by severity (`P0`, `P1`, `P2`, `P3`)
- Corrections applied and findings independently verified as resolved
- Accepted exceptions and their authorization
- Outstanding findings
- Automated verification results and final review recommendation

Store the report alongside the narrated video evidence; both must describe the exact same commit.

### 11. Narrated Video Generation
Generate the final narrated recording only after independent engineering review is complete, all blocking findings are resolved, applicable quality gates pass, and the final head commit SHA is identified. Include demonstration beats covering important defects caught and fixed during review where relevant. Deliver both the playable narrated video and consolidated review report in the review thread.

### 12. Subsequent Review Iterations
When human feedback results in implementation changes: reassess blast radius, dispatch core and applicable specialist reviewers, resolve findings, rerun verification, regenerate the narrated video, update the consolidated review report, and bind all evidence to the new commit SHA. Never reuse stale approvals or videos.

### 13. Final Readiness Gate
An implementation must not be declared complete or marked ready for review until:
- Core review team executed
- Applicable specialist reviewers executed
- Review findings consolidated
- P0 and P1 findings independently verified as resolved
- P2 findings resolved or explicitly accepted
- Repository quality gates passed
- Security / signing / platform invariants verified where applicable
- Review report attached and narrated video delivered (or justified waiver documented)
- Evidence bound to the exact current commit SHA and remaining limitations disclosed
- Never merge without explicit human authorization.

---

## 6. Build the Demonstration Storyboard
Build a structured storyboard JSON (`beats` / `scenes`) before recording. Each beat identifies:
- `acceptance_criterion`
- `route` (application route or starting state)
- `action` (browser or terminal action)
- `target` (element selector or control)
- `expected_result`
- `assertion` (automated assertion confirming the result)
- `narration` (spoken engineering narration)
- `annotation` (bounding box, label, callout number, arrow, spotlight, restrained zoom)
- `estimated_duration`

Organize around what the reviewer needs to verify, not the order code was written. Prioritize evidence over presentation.

## 7. Capture the Actual Application
- For web surfaces (`docs/`, LAN Remote/Director UI) and live verification dashboards, use Playwright + Chromium via `tooling/pr-video-evidence/playwright_capture.py`.
- For native macOS / iOS Simulator apps, record the actual running app (`xcrun simctl io <UDID> recordVideo` / `screencapture -v`) and pass the raw recording into `tooling/pr-video-evidence/cli.py narrate`.
- Record real interactions: navigation, cursor movement, clicking, form/input states, dialog interactions, data updates, validation/error states, recovery, and persisted state.
- Do not record long installs or compilation waits; do not remove footage that exposes a genuine failure.

## 8. Visual Annotations
Make it immediately apparent which part of the interface is under discussion:
- Element bounding boxes and animated highlights
- Visible cursor movement and click indicators
- Arrows and numbered callouts
- Restrained camera zooms and optional spotlights around relevant components
- Brief explanatory callout tags derived from real Playwright locator coordinates
- Annotations must never obscure critical text, values, or results. Preserve unmodified raw footage alongside the annotated/final render.

## 9. Spoken Narration
- Narration **must sound genuinely human** — warm, calm, conversational, and free of robotic cadence, mispronounced acronyms, or audio clipping.
- Default local TTS engine: full-precision **FP32 Kokoro ONNX** (`kokoro-v1.0.onnx` via `tooling/pr-video-evidence/tts.py`) using a blended Grade-A neural voice (`af_heart:0.65+af_bella:0.35`), natural pace (`0.98`), prosodic sentence/clause pauses, spoken technical-term normalization (captions stay verbatim), and `-16 LUFS` broadcast loudness mastering.
- Local fallback on macOS: enhanced/neural `macos-say` voices. Never silently degrade to robotic `espeak-ng` (explicit emergency fallback requires a documented `tts.fallback_reason` and triggers a validator warning).
- Optional approved cloud neural fallback: `--tts-provider openai` (`gpt-4o-mini-tts`, only when explicitly configured with `OPENAI_API_KEY`; pre-flight secret scanning blocks sensitive data).
- Generate narration per beat, measure exact audio duration, and drive scene timing from actual speech duration.
- Use direct, factual engineering language explaining what changed, why, what the user does, what the app does in response, which acceptance criterion is verified, and any edge cases or limitations. Zero promotional fluff.

## 10. Audio and Video Synchronization
- Narration, recorded actions, visual annotations, cursor movements, and captions share one timeline driven by measured segment durations.
- Ensure no truncated speech, no unintended silent gaps, no clipping, aligned highlights/captions, and adequate reading time.
- Preserve separate raw video, audio segments, transcript, SRT, and WebVTT tracks.

## 11. Recording Specifications
Default output profile (`engineering-verification`):
- Container: **MP4** (`+faststart`)
- Video codec: **H.264** (`libx264`, `yuv420p`)
- Audio codec: **AAC** (`48 kHz`, stereo, `160 kbps`)
- Resolution & frame rate: **1920 × 1080 at 30 fps** (16:9)
- Captions: legible burned-in subtitles + `.srt` and `.vtt` sidecars
- Background music: **none**
- Target duration: **30–120 seconds** for straightforward changes (split larger implementations into multiple focused clips rather than rushing or cutting verification).

## 12. Backend, Swift Core, and Infrastructure Implementations
For changes without a standalone web UI (Swift core, CLI scripts, GitHub Actions workflows, benchmarks, release signing), record real observable behavior through:
- Live terminal sessions & test execution (`tooling/pr-video-evidence/scenarios/terminal_verification.py`)
- API/CLI requests and responses
- Benchmark and contract assertions
- Error handling and recovery paths

Narrate and highlight relevant outputs, redacting any credentials. For genuinely non-demonstrable changes, document an explicit `waiver` (`reason` + `equivalent_artifacts`) — never silently skip verification.

## 13. Evidence Integrity
Bind every recording in `manifest.json` to:
- Repository name, branch name, exact head `commit_sha`, PR number (once assigned)
- Capture timestamp (UTC ISO-8601), application environment, routes/endpoints
- Demonstrated acceptance criteria, test commands, assertion results, known limitations
- Independent review manifest (`review_report`)

Never reuse an earlier commit's recording after relevant code changes. Never fabricate tests, footage, or results.

## 14. Review the Recording Before Delivery
Before delivering, inspect:
- `ffprobe` streams (`h264`, `aac`, `1920x1080`, `30 fps`, duration & audio sync)
- Extracted scene keyframes (`review_frames/scene_*.png`) visually
- Legibility of UI and burned-in captions, accuracy of highlights, synchronization of narration
- Zero exposed credentials or sensitive data
- Exact match to head `commit_sha`

If inspection fails, fix and regenerate — never present silent, broken, or incomplete evidence.

## 15. Deliver Evidence
- Deliver the actual playable `.mp4` directly in the active review thread / artifact channel so the reviewer can play and annotate individual frames (never provide only a text description).
- Include the accessible recording link and structured PR evidence block in the pull request description without exposing private recordings on public hosts.
- Retain raw recording, transcript, captions (`.srt`, `.vtt`), annotation metadata, `manifest.json`, Playwright `trace.zip`, keyframes, and test results outside Git (`.pr-evidence/` is gitignored).
- Never commit binary recording artifacts to the repository.

## 16. Pull Request Evidence Summary
Include this exact structure in every applicable pull request description (generated automatically by `python3 tooling/pr-video-evidence/cli.py markdown`):

```markdown
### Narrated verification
Recording: [Playable demonstration](<video-url>)
Commit: `<exact-verified-commit-sha>`

### Demonstrated behavior
| Acceptance criterion | Timestamp | Verification |
| --- | --- | --- |
| Criterion | 00:00 | Passed |

### Automated checks
- `<command>` — **Passed** / **Skipped** (reason)

### Consolidated engineering review
- **Reviewers:** `senior-code-critic`, `review-changes`, `ponytail-review` (+ specialists)
- **Findings:** P0=0, P1=0, P2=0, P3=0 (Unresolved blocking: 0)
- **Recommendation:** approved

### Known limitations
Document any unverified behavior, platform limitations, or outstanding concerns.

<details>
<summary>PR Video Evidence Manifest (machine-readable)</summary>
<!-- pr-video-evidence:start -->
```json
{ "...": "generated automatically by cli.py markdown" }
```
<!-- pr-video-evidence:end -->
</details>
```

## 17. Visual Feedback Loop
When a reviewer submits video frame annotations or PR comments:
1. Inspect every annotated frame, timestamp, and comment.
2. Retrieve the corresponding recording and commit context.
3. Locate affected implementation files and translate feedback into concrete acceptance criteria.
4. Implement corrections and add/update regression tests.
5. Repeat independent engineering review and automated verification.
6. Generate a fresh narrated recording for the new head commit SHA (preserving earlier recordings as history; never reusing outdated videos).
7. Attach the updated recording in the same thread, update the PR evidence summary, and explicitly list addressed vs. remaining comments.

## 18. Dante for Creators (`PlaybookMediaLLC/textream`) Integration
Inspect and reuse existing repository infrastructure rather than duplicating it:
- `tooling/pr-video-evidence/cli.py` (invoked via `npm run devx:video-evidence` or `python3 tooling/pr-video-evidence/cli.py`)
- `Textream/TextreamTests/DanteScreenshotCaptureTests.swift` and `.github/workflows/capture-screenshots.yml` (static macOS/iOS Dark & Light screenshots)
- `tests/test_release_signing.py` and `tests/test_pr_video_evidence.py`
- `benchmarks/speech-tracking/` and `benchmarks/desktop/`
- `.github/workflows/pr-video-evidence.yml` (CI verification check named `pr-video-evidence`)
- Preserve silent marketing assets (`docs/video.mp4`, `docs/video.gif`) untouched under their own marketing profile.

## 19. Failure Handling
If any mandatory step fails, investigate and fix where possible. If blocked, report the exact blocker, commands attempted, error output, what remains unverified, and required action. Keep the PR in **draft**. Never bypass verification or invent evidence.

## 20. Definition of Done
An implementation is ready for review only when:
- [ ] Original acceptance criteria are addressed.
- [ ] Core and applicable specialist independent reviews are complete and all P0/P1 findings are independently verified resolved.
- [ ] Applicable automated tests pass.
- [ ] Actual implementation behavior has been verified.
- [ ] Relevant failure states and edge cases have been examined.
- [ ] Narrated recording has been generated (or documented waiver provided for strictly non-demonstrable changes).
- [ ] Visual annotations (cursor, clicks, highlights, callouts, zooms) are accurate.
- [ ] Captions and narration are synchronized.
- [ ] Recording has passed `ffprobe` and visual keyframe inspection.
- [ ] Evidence corresponds to the exact head commit SHA.
- [ ] Playable recording and consolidated review report are delivered in the active review thread.
- [ ] Pull request evidence summary and machine-readable metadata block are updated.
- [ ] Limitations are explicitly documented.
- [ ] No sensitive information is exposed and no binary recordings are committed to Git.
- [ ] Never merge a pull request without explicit human authorization.
