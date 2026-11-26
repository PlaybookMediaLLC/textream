# Speech-Tracking Benchmark: Plan

**Goal:** measure, with numbers we can trust, how often and for how long Textream's
prompter loses the speaker's place, across the conditions a commercial recording
product will face. Then use those numbers to set a launch bar and point the work
that follows.

**Headline metric:** *lost-place events per 10 minutes of speech*. Every other metric
supports this one or explains it.

## Status (2026-11-25)

**Built:** Phase 0 (one shared matcher) and Phase 1 (Layer A with the synthetic
generator) for all eight dimensions plus a composite take. The harness compiles the
**shipping** matcher (`Textream/Shared/`) and the pre-benchmark matcher (from git
`f9c6c94`) and replays identical simulated sessions through both.

```
cd benchmarks/speech-tracking
go run run.go                 # 30 seeds/case → results/current.md, results/legacy.md (~4 min)
go run run.go -check          # same; exits 1 if any gating case fails (CI regression gate)
CASE="skip 25" go run run.go -seeds 5        # only cases whose name contains the text
CASE="skip 25" TRACE=1 go run run.go -seeds 1  # per-tick truth/pred/transcript, written into results/*.md
```

**Result:** gating cases passing the §8 launch bar went from **4/36 (legacy) to
36/36**. Full tables are in `results/`. Headline numbers (lost-place events per
10 min, legacy → new):

| | legacy | new |
|---|---|---|
| clean read | 0.30 | 0.00 |
| restart sentence | 5.70 | 0.00 |
| ad-lib 45 words | 12.02 | 0.12 |
| skip 10 / 60 words | 15.3 / 30.2 (never recovered) | 0.00 / 0.00 |
| 230 wpm | 2.35 | 0.00 |
| accent proxy, WER≈22% | 1.81 | 0.00 |
| noise proxy, 10 dB | 1.51 | 0.00 |
| competing speech 12% | 9.50 | 0.15 |
| realistic composite | 9.42 | 0.00 |

**§6 hypotheses, as measured on the legacy matcher:** all confirmed. The worst
problem wasn't predicted precisely: *one* misheard word could derail the greedy
whole-transcript alignment and freeze the highlight until the next 55 s recognizer
restart, so even a clean read ended about 6 words off on average. Skips of 6 words or
more never recovered (final error 94–213 words).

**What changed in the matcher** (`Textream/Shared/PromptMatcher.swift`, now used by
both macOS `SpeechRecognizer` and iOS `SpeechFollower`):
- It aligns only the newest ~12 spoken words against the whole script (word-level
  Smith–Waterman), biased toward the current position. An early error can't stick,
  and skips and re-reads are found anywhere in the script.
- Forward steps commit on evidence *past* the current position. Function words weigh
  0.35, so ad-libs and background speech don't creep the highlight forward.
- Far jumps (in either direction) need 3+ matches, a 1.0 score margin over every
  other location (so refrains can't pull it), agreement from the newest 6 words, and
  either a second agreeing partial or overwhelming evidence.
- Contractions are expanded on both sides; fuzzy matching is stricter ("the" no
  longer matches "there").
- The previous recognition session's tail carries across recognizer restarts.
- Cost: about 1 ms per partial on a 10,000-word script (release build).

**Not built yet / limits:**
- **Layer B and the recorded corpus (§5) are not built.** Accent, noise and
  technical rows are *ASR-error proxies* with assumed error rates, not acoustics.
  Layer B with real readers is what calibrates them, and it's still the gate before
  any commercial claim.
- Known residual: a skip that lands within ~3 s of a recognizer restart, followed
  by mostly function words, can take ~5 s to recover (0.2 events/10 min in the
  skip-25 case at 30 seeds; it fails at 10 seeds).
- No number normalization ("2024" vs "twenty twenty-four").
- Verification on this machine: the macOS app builds, and all 14 matcher unit tests
  (7 existing + 7 new in `TextreamiOSTests/PromptMatcherTests.swift`) pass when
  run natively on macOS via SwiftPM. The iOS test suite could **not** be run (no iOS
  platform or simulator runtime installed). iOS sources type-check against the SDK
  except `CameraPreview.swift`, which doesn't build against this SDK for reasons
  unrelated to this change (`AVCaptureDeviceDirectionCoordinator` is missing).

---

## 1. What we're testing (current implementation)

Tracking is a two-stage pipeline:

1. **ASR** produces a cumulative partial transcript: Apple `SFSpeechRecognizer`
   (on-device or server, with `contextualStrings` hints), or a local
   transcribe.cpp model (rolling window, initial-prompt hints).
2. **Matcher** aligns that transcript against the script from `matchStartOffset`
   and moves the highlight forward:
   - macOS: private methods in `Textream/Textream/SpeechRecognizer.swift:1043-1361`
   - iOS: `Textream/TextreamiOS/Speech/PromptMatcher.swift` (a pure struct, already unit-tested)
   - shared heuristics: `SpeechTextAlignment.bestOffset` / `shouldCommit` (the two
     platforms keep **separate, already-diverged copies** of this file)

What the code tells us before any measuring (§6 lists the hypotheses we'll test):

| Mechanism | Limit |
|---|---|
| Word-level resync | skips at most **5 source words** or **5 spoken words** |
| Char-level resync | skips at most **5 characters** |
| Direction | **forward only**; `matcherNeverMovesBackward` is a test that asserts it |
| Re-localization | none. If the speaker gets more than ~5 words away, only a manual tap recovers |
| Commit gate | any step of 15 characters or less commits without confirmation |
| Fuzzy word match | prefix match for words of 3+ chars ("the"/"there", "and"/"android") |
| Normalization | lowercase plus strip punctuation; no handling of numbers, contractions or abbreviations |
| Session resets | SFSpeech task restarts every 55 s and on silence; local engine re-anchors on each window rollover |

## 2. Architecture: two layers

```
 audio + script ──► [Layer B: ASR engine runner] ──► timestamped partials (.jsonl)
                                                         │   (cached fixture)
 script + perturbation ──► [synthetic generator] ────────┤
                                                         ▼
                                    [Layer A: matcher replay] ──► position track ──► metrics ──► report
                                                         ▲
                                       ground-truth position track
```

- **Layer A, matcher replay.** Deterministic and fast; runs in CI. It feeds a
  stream of `(t, partialTranscript)` into the matcher using an injected clock and
  records the highlight position over time. This isolates matcher logic from ASR.
- **Layer B, engine runner.** Runs on a Mac, nightly or on demand. It streams real
  audio files through each engine at real-time pace (partial cadence depends on
  pacing), captures the partials and saves them as Layer A fixtures. Each audio
  clip pays the expensive ASR pass once per engine version.
- **Synthetic generator.** Produces transcript streams straight from a script plus
  a perturbation (skip N words, repeat a sentence, swap in paraphrases, inject
  ASR-style errors, freeze for a pause, reset the transcript as a restart would).
  This gives thousands of cheap cases for fuzzing the matcher logic.

## 3. Metrics

Sample on a 100 ms grid. For each tick, compare the predicted script word index
with the ground-truth word index (the word the speaker is actually on).

| Metric | Definition | Why |
|---|---|---|
| **Lost-place events / 10 min** | an interval where \|error\| > 8 words (about one prompter line) for more than 2 s | the headline metric: "the prompter lost me" |
| Recovery time | time from a disturbance (skip, ad-lib, noise burst, pause end, task restart) until \|error\| ≤ 3 words | separates a momentary wobble from a lost place |
| Never-recovered | the case ends while still lost | needs a manual tap; the worst outcome |
| Lag p50 / p95 | time from the speaker finishing word *w* to the highlight reaching *w* | how responsive it feels |
| **False advance** | highlight runs more than 3 words *ahead* of the speaker | scrolls text away from the reader; worse than lag |
| Drift during silence | words advanced while nobody is speaking | should be 0 |
| Stall | speaker progresses 5+ words while the highlight doesn't move for 3+ s | |
| Position error p50 / p95 | in words | summary statistic |
| Matcher CPU / partial | time per `match()` call, against transcript length | the whole transcript is re-aligned on every partial |

Every result gets these tags: scenario, speaker, accent, speed, SNR, engine,
platform and synthetic-or-real. Reports slice by any tag.

## 4. Benchmark matrix (the eight dimensions)

Each dimension has scripted cases (a real reader following stage directions) and,
where it makes sense, synthetic cases (generator only).

### 4.1 Repeated sentences
- **In the script:** refrains ("Let's take a look at…" appearing 4 times), lists
  with parallel structure, a script that opens and closes with the same sentence.
  Checks that the matcher doesn't latch onto a later copy.
- **By the speaker:** restarting a fumbled sentence; re-reading the previous line;
  repeating one word ("the the"). The current matcher can't move backward, so we
  expect it to sit ahead of the speaker or false-advance.

### 4.2 Intentional paraphrasing
- Light: contractions ("do not" → "don't"), synonyms, dropped filler words.
- Medium: reordered clauses, an added or removed sentence.
- Heavy: a 10–30 s ad-lib, then a return to the script mid-paragraph.
- Disfluencies: "um", "uh", "you know", false starts.
- Pass criterion: no false advance *during* the ad-lib, and recovery within 3 s
  after the speaker returns.

### 4.3 Pauses
- Silence of 2, 5, 15, 30 and 60+ s, at both sentence and mid-sentence boundaries.
- Pauses that cross the 55 s SFSpeech restart and the local-engine window rollover.
- Breathing, mouth clicks or a page turn during the pause (non-speech sound).
- Pass criterion: zero drift during the pause, and the first post-pause words are tracked.

### 4.4 Skipped lines
- Skip 1 word, 3 words, 1 line (~10 words), 1 sentence, 1 paragraph, half a page.
- Skip *backward* (jump back a paragraph to re-read).
- Expected today: skips over 5 words never recover without a tap. This is the
  biggest predicted gap.

### 4.5 Speaking speed
- Real readers at their slow, natural and fast pace (~110 / 150 / 190+ wpm).
- Variable pace inside one take (rush, slow down).
- Augmentation: time-stretch clean takes to 0.8×, 1.2× and 1.4× without changing
  pitch. Tag these `synthetic-speed`, because stretch artifacts can flatter or hurt the ASR.

### 4.6 Accents
- Recruit readers so the core corpus has at least 8 accent groups (e.g. US, UK,
  Indian, Nigerian, Chinese-L1, Spanish-L1, Arabic-L1, French-L1 English), with a
  mix of genders and ages.
- Supplement with public read-speech corpora where the prompt text *is* the ground truth:
  - Mozilla Common Voice (CC0; read prompts; accent metadata). Clips are short,
    so it's best for ASR-level checks and stitched mini-scripts.
  - L2-ARCTIC (non-native English reading ARCTIC prompts). **License is
    non-commercial: needs legal sign-off even for internal use.**
  - Speech Accent Archive (one fixed paragraph, many accents). Also **NC
    licensed**; same caveat.
- Phase 2: non-English scripts in the languages the app advertises (it ships
  language detection).

### 4.7 Background noise
- Mix MUSAN (CC BY 4.0) or DEMAND noise into clean takes at SNR 20, 10, 5 and 0 dB.
- Types: office babble, **competing speech/TV** (worst case, because the ASR
  transcribes it), music with vocals, HVAC/fan, keyboard typing, street, room reverb.
- Plus a small set of *real* recordings in noisy rooms on a laptop built-in mic
  and on a headset/lav, to check that the synthetic mixes predict reality.
- Also verifies that `VoiceActivityDetector` isn't gating out quiet speech or
  passing noise through.

### 4.8 Technical vocabulary
- Scripts dense with jargon: cloud/devops ("Kubernetes", "PostgreSQL", "kubectl"),
  acronyms read as letters vs. words ("SQL" / "sequel", "AWS"), version numbers
  ("v2.3.1"), numbers and dates ("2024", "$4.5M", "30%"), URLs, code identifiers
  (`getUserById`), medical and legal terms, brand names, non-English names.
- Run each one with and without `contextualStrings` / initial-prompt hints to measure what the hints buy us.

### 4.9 Cross-cutting axes
Engine (Apple on-device, Apple server, each local model in `SpeechModelCatalog`)
× platform (macOS, iOS) × mic (built-in, headset). Don't run the full cross
product. Run a fixed **core set** on every engine and the full matrix on the
default engine only.

### 4.10 Realistic composites
5–8 "real job" scripts (YouTube intro, sales demo, keynote section, news read,
training video, wedding toast) read naturally, with whatever mistakes happen.
This is the number we show stakeholders. §4.1–4.8 explain it.

## 5. Corpus and ground truth

**Scripts.** 8 dimension scripts plus 5–8 composites, 300–800 words each, stored
as plain text exactly as a user would paste them, including `[annotations]`.
Each also gets a *reader's version* with stage directions (⏸10s, ~paraphrase~,
~~skip~~, ↺ re-read). The app only ever sees the clean script.

**Recording protocol.** 48 kHz mono WAV, recorded on two mics at the same time
(built-in plus headset) where possible, in a quiet room. Readers do one natural
take and one take following the stage directions. Consent and release forms must
cover commercial benchmarking and retention.

**Ground truth.** For each take:
1. Get word timings for what was *actually said* (forced alignment of a
   human-corrected transcript; WhisperX or Montreal Forced Aligner).
2. Map spoken words to script word indices. Paraphrase spans map to the script
   span they replace, ad-libs map to "no script position" (so error isn't
   scored, but false advance still is), and skips and re-reads show up as
   jumps in the track.
3. Store the result as `truth.jsonl`, one `(t_start, t_end, scriptWordIndex | null)` entry per spoken word.

Step 2 is the manual part. Budget about 15 minutes of human review per take, and
build a tiny review view that plays audio against the track.

**Size, v1.** About 3 hours of real audio (≈12 speakers × ~15 min), multiplied
by noise and speed augmentation, plus synthetic matcher cases.

**Layout.** Built now:
```
benchmarks/speech-tracking/
  PLAN.md
  run.go                  # builds + runs the Swift harness for both matchers
  Sources/main.swift      # simulator, cases, metrics, report (Layer A)
  scripts/<id>.txt        # general, repeated (refrains), technical
  results/current.md, results/legacy.md
```
To add for Layer B:
```
  scripts/<id>.reader.md
  cases/<case-id>/manifest.json   # script, audio, truth, tags
  cases/<case-id>/truth.jsonl
  fixtures/<case-id>/<engine>@<version>.jsonl   # captured partials, replayed by Layer A
```
Audio goes in Git LFS or object storage, not plain git.

## 6. Hypotheses from code review (the benchmark should confirm or kill these)

1. **Skips over 5 words never recover** without a tap: the resync windows are 5
   words / 5 chars and nothing searches the whole script.
2. **Re-reads and restarts leave the highlight ahead of the speaker:** the matcher
   is monotonic by design.
3. **Ad-libs creep forward:** a ≤15-char step commits unconditionally, and the
   3-char prefix fuzzy match is permissive, so common words in an ad-lib can
   ratchet the highlight forward.
4. **Numbers, abbreviations and contractions break word alignment:** "2024" vs
   "twenty twenty-four", "Dr." vs "doctor", "don't" vs "do not". There's no
   normalization layer for these.
5. **One early misalignment persists:** the whole transcript since
   `matchStartOffset` is re-aligned on every partial, so an early wrong resync
   keeps steering the result until the next restart. CPU per partial also grows
   with transcript length.
6. **Session restarts drop words:** speech during an SFSpeech restart (55 s timer,
   end on silence) or a local-window rollover is lost, and tracking has to
   re-acquire.
7. **macOS and iOS behave differently** on identical input because their matchers
   and `SpeechTextAlignment` copies have diverged.

## 7. Phases

| # | Work | Output | Est. |
|---|---|---|---|
| 0 | **Make the matcher benchmarkable.** Move `PromptMatcher` and one `SpeechTextAlignment` into code shared by both targets; make macOS `SpeechRecognizer` call it; move the jump/anchor-prefix trimming into it; inject a clock instead of `Date()` | one matcher that is pure and testable | 2–3 d |
| 1 | **Layer A plus synthetic generator.** Replay harness (Swift CLI or test target), perturbation generator, metrics, markdown report. Baseline the 8 dimensions synthetically | first numbers; confirms or kills §6 #1–5 | ~1 wk |
| 2 | **Corpus v1.** Scripts, reader versions, recruiting 12 speakers, recording, alignment and truth review, noise/speed augmentation | `cases/` populated | 2–3 wk (logistics-bound) |
| 3 | **Layer B engine runner.** Real-time-paced file → engine for Apple on-device, Apple server and 2 local models; capture fixtures | per-engine baseline report | ~1 wk |
| 4 | **Set the launch bar.** Review the baseline with product; lock thresholds (below); wire Layer A into CI as a regression gate (fail if any slice is worse than baseline + tolerance) | go/no-go criteria, CI gate | 2–3 d |

Phases 1 and 2 run in parallel. Phase 1 is useful on its own: by the end of week
one it will show whether hypotheses 1–3 hold.

## 8. Proposed launch bar (calibrate after the Phase 3 baseline)

Default engine, at 180 wpm or slower:

| Condition | Lost-place / 10 min | Recovery | Other |
|---|---|---|---|
| Clean, natural reading | ≤ 0.2 | — | lag p95 ≤ 1.0 s |
| 10 dB noise, any accent group | ≤ 0.5 | ≤ 3 s | no accent group worse than 2× the best group |
| 0–5 dB / competing speech | ≤ 2 | ≤ 5 s | report only; not gating |
| Skip ≤ 1 paragraph | — | ≤ 3 s | never-recovered = 0 |
| Re-read / restart | — | ≤ 3 s | |
| Ad-lib ≤ 30 s | — | ≤ 3 s after return | false advance = 0 |
| Pause up to 60 s | — | first word after pause | drift = 0 |
| Technical script (with hints) | ≤ 0.5 | — | |

## 9. Out of scope for this benchmark

- Fixing the matcher. Phase 1 results will rank the fixes; likely candidates are
  global re-localization by n-gram anchors once lost, bounded backward moves,
  number/contraction normalization, and a stricter commit gate during low-match
  stretches.
- Scroll/animation smoothness and UI rendering.
- ASR word error rate as a goal in itself. We record it as a diagnostic only.

## 10. Open decisions

1. Budget and source for recruiting readers (paid panel vs. staff vs. contractors).
2. Whether NC-licensed corpora (L2-ARCTIC, Speech Accent Archive) are allowed for
   internal benchmarking. If not, real readers carry the accent axis alone.
3. Which local models count as "supported" and get gated, rather than only reported.
4. Where audio lives (LFS vs. bucket) and who can access recordings of people.
