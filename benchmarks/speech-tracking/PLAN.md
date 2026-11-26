# Speech-Tracking Benchmark: Plan

**Goal:** measure, with numbers we can trust, how often and for how long Textream's
prompter loses the speaker's place, across the conditions a commercial recording
product will face. Then use those numbers to set a launch bar and point the work
that follows.

**Headline metric:** *lost-place events per 10 minutes of speech*. Every other metric
supports this one or explains it.

## Status (2026-11-26)

**Every phase is built and passing.**
- **Phase 0:** one shared matcher.
- **Phase 1:** Layer A, simulated.
- **Phases 2–3:** Layer B, real audio through the app's real recognizers: Apple on-device and two
  recommended local transcribe.cpp models. Synthetic voices stand in for recruited readers, and a
  validated ingest path takes real readers' takes.
- **Phase 4:** launch bar plus CI gate.

| | legacy matcher (`f9c6c94`) | shipping code |
|---|---|---|
| Layer A, simulated speakers + ASR (30 seeds/case) | **0/37** gating cases pass | **37/37** |
| Layer B, real audio → Apple on-device, Nemotron, Canary | **22/42** | **42/42** |
| iOS unit tests (simulator, iOS 26.1) | — | **104/104** (95 existing + 9 new) |
| macOS app build | — | ✅ |

### Running it

```
cd benchmarks/speech-tracking
go run run.go                       # Layer A (30 seeds) + replay all Layer B fixtures, both matchers → results/*.md
go run run.go -check                # same; exits 1 if any gating case fails (CI: .github/workflows/speech-tracking.yml)
go run run.go -record apple-on-device        # re-record Layer B, full matrix (real time, ~75 min, macOS, speech permission)
go run run.go -record /path/model.gguf       # core cases (§4.9) with a local model through the app's LocalSpeechEngine
CASE="skip" go run run.go           # only cases whose name/fixture id contains the text
.build/release/bench reader-scripts .                            # stage-direction scripts for human readers
.build/release/bench ingest-audio . <case> <reader> take.wav     # a person's take → scored fixture (auto-aligned truth)
```

It's a SwiftPM package. `Sources/bench/Shared` and `Sources/bench/LocalSpeechEngine.swift` are
symlinks to the app's code, so it always measures what ships. Fixtures (`fixtures/<case>/`:
`case.json`, `truth.json`, `<engine>.jsonl`) are replayed in CI without audio or recognizers.
Local models: the catalog's recommended Nemotron 3.5 Streaming 0.6B (`Q8_0`, native streaming) and
Canary 180M Flash (`Q8_0`, rolling window), downloaded at their pinned revisions and SHA-256 checked.

### Layer B: what it is

Each case's performance (the same speaker model as Layer A: skips, re-reads, ad-libs, pauses,
paraphrase, fillers) is spoken by a macOS voice: US, UK, two Indian, Australian, Irish and South
African English, plus French, German, Spanish and Mandarin voices reading English as non-native
proxies. It's mixed with 4-talker babble, a competing "TV" talker, or HVAC rumble at a set SNR, and
streamed in real time into the recognizer the way the app drives it (Apple: partials, `.dictation`,
the app's contextual strings, a new task every 55 s or when one ends; local: the app's
`LocalSpeechEngine` with its language and prompt rules). Ground truth comes from the synthesis. Each
row also reports the recognizer's own WER and latency, to separate recognizer limits from matcher
problems (not available for rolling-window engines, which re-transcribe overlapping audio).

| Engine · dimension | Case | Lost/10 min legacy → new | Lag p95 (s) legacy → new | Pass legacy → new |
|---|---|---|---|---|
| apple-on-device · accent | Australian English (Karen) [Karen, WER 4%, ASR lag 0.4 s] | 0.00 → 0.00 | 0.75 → 0.74 | ✅ → ✅ |
| apple-on-device · accent | Indian English (Rishi) [Rishi, WER 3%, ASR lag 0.4 s] | 0.00 → 0.00 | 0.87 → 0.82 | ✅ → ✅ |
| apple-on-device · accent | Indian English (Tara) [Tara, WER 3%, ASR lag 0.1 s] | 0.00 → 0.00 | 0.69 → 0.72 | ✅ → ✅ |
| apple-on-device · accent | Irish English (Moira) [Moira, WER 6%, ASR lag 0.4 s] | 0.00 → 0.00 | 0.73 → 0.79 | ✅ → ✅ |
| apple-on-device · accent | South African English (Tessa) [Tessa, WER 53%, ASR lag 0.4 s] | 0.00 → 0.00 | 0.80 → 0.83 | ✅ → ✅ |
| apple-on-device · accent | UK English (Daniel) [Daniel, WER 4%, ASR lag 0.4 s] | 0.00 → 0.00 | 0.75 → 0.79 | ✅ → ✅ |
| apple-on-device · accent (non-native proxy) | French voice reading English [Thomas, WER 50%, ASR lag 7.1 s] | 5.76 → 17.27 | 8.90 → 5.29 | report → report |
| apple-on-device · accent (non-native proxy) | German voice reading English [Anna, WER 27%, ASR lag 6.7 s] | 0.00 → 0.00 | 1.35 → 1.72 | ✅ → report |
| apple-on-device · accent (non-native proxy) | Mandarin voice reading English [Tingting, WER 11%, ASR lag -0.1 s] | 0.00 → 0.00 | 1.07 → 1.16 | ✅ → ✅ |
| apple-on-device · accent (non-native proxy) | Spanish voice reading English [Mónica, WER 4%, ASR lag 0.5 s] | 0.00 → 0.00 | 0.74 → 0.77 | ✅ → ✅ |
| apple-on-device · baseline | clean read, US voice [Samantha, WER 4%, ASR lag 0.5 s] | 0.00 → 0.00 | 0.76 → 0.78 | ✅ → ✅ |
| apple-on-device · composite | realistic take, UK voice, babble 15 dB [Daniel, WER 11%, ASR lag 0.9 s] | 17.25 → 0.00 | 8.66 → 1.23 | ❌ → ✅ |
| apple-on-device · noise | 4-talker babble, 10 dB [Samantha, WER 7%, ASR lag 1.0 s] | 0.00 → 0.00 | 1.02 → 1.14 | ✅ → ✅ |
| apple-on-device · noise | 4-talker babble, 5 dB [Samantha, WER 18%, ASR lag 0.6 s] | 6.66 → 0.00 | 1.77 → 1.65 | report → report |
| apple-on-device · noise | HVAC rumble, 5 dB [Samantha, WER 4%, ASR lag 0.3 s] | 6.66 → 0.00 | 0.70 → 0.77 | ❌ → ✅ |
| apple-on-device · noise | competing talker (TV), 10 dB [Samantha, WER 6%, ASR lag 0.4 s] | 0.00 → 0.00 | 0.80 → 0.85 | ✅ → ✅ |
| apple-on-device · noise | competing talker (TV), 5 dB [Samantha, WER 6%, ASR lag 0.5 s] | 0.00 → 0.00 | 0.81 → 0.88 | ✅ → ✅ |
| apple-on-device · paraphrase | ad-lib 15 and 40 words [Samantha, WER 3%, ASR lag 0.5 s] | 11.40 → 0.00 | 0.75 → 0.85 | ❌ → ✅ |
| apple-on-device · paraphrase | contractions, synonyms, fillers [Karen, WER 8%, ASR lag -0.7 s] | 6.40 → 0.00 | 6.17 → 0.99 | ❌ → ✅ |
| apple-on-device · pauses | pauses 5 s, 20 s, 60 s [Samantha, WER 4%, ASR lag 16.6 s] | 10.25 → 0.00 | 0.66 → 0.80 | ❌ → ✅ |
| apple-on-device · repeated | re-read 12 words ×2, jump back 30 [Samantha, WER 5%, ASR lag 0.3 s] | 5.48 → 0.00 | 0.70 → 0.74 | ❌ → ✅ |
| apple-on-device · repeated | refrains + restart sentence ×3 [Daniel, WER 3%, ASR lag 0.5 s] | 0.00 → 0.00 | 0.71 → 0.67 | ✅ → ✅ |
| apple-on-device · skips | skip 10, 25, 60 words [Rishi, WER 3%, ASR lag 0.3 s] | 26.49 → 0.00 | 8.97 → 0.96 | ❌ → ✅ |
| apple-on-device · speed | 130 wpm [Samantha, WER 3%, ASR lag 0.5 s] | 0.00 → 0.00 | 0.77 → 0.77 | ✅ → ✅ |
| apple-on-device · speed | 230 wpm [Samantha, WER 4%, ASR lag 0.3 s] | 0.00 → 0.00 | 0.72 → 0.72 | ✅ → ✅ |
| apple-on-device · technical | jargon, app's contextual hints on [Samantha, WER 19%, ASR lag 0.5 s] | 0.00 → 0.00 | 0.89 → 1.01 | ✅ → ✅ |
| apple-on-device · technical | jargon, no hints [Samantha, WER 22%, ASR lag 0.5 s] | 0.00 → 0.00 | 1.03 → 1.11 | ✅ → ✅ |
| local-canary · accent | Indian English (Rishi) [Rishi, rolling window: WER n/a] | 0.00 → 0.00 | 1.56 → 1.19 | ❌ → ✅ |
| local-canary · accent | UK English (Daniel) [Daniel, rolling window: WER n/a] | 0.00 → 0.00 | 1.17 → 1.15 | ✅ → ✅ |
| local-canary · baseline | clean read, US voice [Samantha, rolling window: WER n/a] | 0.00 → 0.00 | 1.26 → 1.26 | ❌ → ✅ |
| local-canary · composite | realistic take, UK voice, babble 15 dB [Daniel, rolling window: WER n/a] | 17.25 → 0.00 | 7.63 → 1.35 | ❌ → ✅ |
| local-canary · noise | 4-talker babble, 10 dB [Samantha, rolling window: WER n/a] | 19.97 → 6.66 | 8.30 → 3.04 | report → report |
| local-canary · noise | competing talker (TV), 10 dB [Samantha, rolling window: WER n/a] | 6.66 → 0.00 | 1.76 → 1.27 | ❌ → ✅ |
| local-canary · paraphrase | ad-lib 15 and 40 words [Samantha, rolling window: WER n/a] | 22.79 → 0.00 | 0.91 → 1.13 | ❌ → ✅ |
| local-canary · pauses | pauses 5 s, 20 s, 60 s [Samantha, rolling window: WER n/a] | 0.00 → 0.00 | 1.14 → 1.21 | ✅ → ✅ |
| local-canary · repeated | re-read 12 words ×2, jump back 30 [Samantha, rolling window: WER n/a] | 10.96 → 0.00 | 1.03 → 1.27 | ❌ → ✅ |
| local-canary · skips | skip 10, 25, 60 words [Rishi, rolling window: WER n/a] | 26.49 → 0.00 | 8.40 → 1.18 | ❌ → ✅ |
| local-canary · technical | jargon, app's contextual hints on [Samantha, rolling window: WER n/a] | 0.00 → 0.00 | 1.92 → 1.37 | ❌ → ✅ |
| local-nemotron · accent | Indian English (Rishi) [Rishi, WER 0%, ASR lag 0.2 s] | 0.00 → 0.00 | 0.87 → 0.87 | ✅ → ✅ |
| local-nemotron · accent | UK English (Daniel) [Daniel, WER 1%, ASR lag 0.3 s] | 0.00 → 0.00 | 0.78 → 0.78 | ✅ → ✅ |
| local-nemotron · baseline | clean read, US voice [Samantha, WER 0%, ASR lag 0.1 s] | 0.00 → 0.00 | 0.73 → 0.73 | ✅ → ✅ |
| local-nemotron · composite | realistic take, UK voice, babble 15 dB [Daniel, WER 3%, ASR lag 0.6 s] | 11.50 → 0.00 | 0.85 → 0.86 | ❌ → ✅ |
| local-nemotron · noise | 4-talker babble, 10 dB [Samantha, WER 3%, ASR lag 0.0 s] | 0.00 → 0.00 | 0.84 → 0.84 | ✅ → ✅ |
| local-nemotron · noise | competing talker (TV), 10 dB [Samantha, WER 2%, ASR lag 0.3 s] | 0.00 → 0.00 | 0.79 → 0.76 | ✅ → ✅ |
| local-nemotron · paraphrase | ad-lib 15 and 40 words [Samantha, WER 0%, ASR lag 0.1 s] | 17.09 → 0.00 | 0.76 → 0.76 | ❌ → ✅ |
| local-nemotron · pauses | pauses 5 s, 20 s, 60 s [Samantha, WER 1%, ASR lag 0.1 s] | 0.00 → 0.00 | 0.83 → 0.82 | ✅ → ✅ |
| local-nemotron · repeated | re-read 12 words ×2, jump back 30 [Samantha, WER 0%, ASR lag 0.1 s] | 5.48 → 0.00 | 0.78 → 0.80 | ❌ → ✅ |
| local-nemotron · skips | skip 10, 25, 60 words [Rishi, WER 1%, ASR lag 0.2 s] | 26.49 → 0.00 | 8.90 → 0.84 | ❌ → ✅ |
| local-nemotron · technical | jargon, app's contextual hints on [Samantha, WER 15%, ASR lag 0.7 s] | 0.00 → 0.00 | 1.07 → 1.02 | ❌ → ✅ |

### What real audio taught us, and what was fixed

1. **Apple's on-device recognizer drops its transcript mid-session** after short gaps, and revises its
   opening words. Layer A didn't model this. The matcher now tells resets apart from revisions and
   carries the recent context across, and Layer A models resets (`utteranceReset`). With resets
   modeled, **the legacy matcher passes 0/37**: it never recovers from a reset, which is likely the
   main real-world "loses its place" failure.
2. **There is no separate Apple server path on macOS 26.** With on-device en-US available,
   `SFSpeechRecognizer` stays on-device even when server recognition is allowed: a test run produced
   partials identical to on-device, 327/327. The app doesn't force either, so on-device is what it gets.
3. **App bug, rolling-window local models (Canary, Whisper family):** after each 26 s window rollover
   the new window starts mid-word, and Canary returned empty text for up to 13 s, freezing the
   highlight. `LocalSpeechEngine` now (a) gives every window a 0.3 s silent lead-in, (b) adapts its
   cadence to model speed (0.75–1.5 s instead of a fixed 1.5 s; lag p95 1.58 → 1.15 s), and (c) for
   word tracking only (`retryEmptyWindowsOnRecentAudio`, dictation unchanged), retries an empty window
   on its last 4 s. Canary went from failing to 10/11 core cases.
4. **Canary-180M-flash can't transcribe 10 dB 4-talker babble**: about 50% of windows decode to
   nothing at any length (2–15 s) and with any run option, so there's nothing to track. Nemotron gets
   3% WER on the same audio. That case is report-only for Canary. **Product implication:** Canary is
   flagged "recommended" in the catalog, but it shouldn't be suggested for noisy rooms; Nemotron should.
5. The recognizer writes "$4.5M" as "4.5 million" (scaled numbers are normalized now) and merges or
   splits words ("topic" for "to pick"), and one spoken word can now match two script words.
6. Jargon wasn't a tracking risk: contextual hints cut lag p95 from 1.19 s to 1.03 s on Apple's recognizer.

### Matcher changes (`Textream/Shared/PromptMatcher.swift`, used by macOS and iOS)

- It aligns only the newest ~12 spoken words against the whole script (word-level Smith–Waterman),
  biased toward the current position. An early error can't stick, and skips and re-reads are found
  anywhere in the script.
- Forward steps commit on evidence *past* the current position. Function words weigh 0.35, and a
  function word only counts when 2 of the last 3 script steps matched, so ad-libs and background
  speech don't creep the highlight forward.
- Far jumps need 3+ matches among the *current transcript's* words, a 1.0 score margin over every
  other location (so refrains can't pull it), agreement from the newest 6 words, and a second agreeing
  partial, overwhelming evidence, or a session end.
- Context carries across recognizer restarts and mid-session resets. Contractions and scaled numbers
  are normalized, merged words are matched, and fuzzy matching is stricter.
- Cost: about 1 ms per partial on a 10,000-word script (release build).

### Human readers (§5)

`bench reader-scripts` writes `scripts/readers/<case>.md`: the script with stage directions (struck-out
skips, PAUSE 20 s, GO BACK and re-read, AD-LIB…) so a person performs exactly what the case measures.
`bench ingest-audio <case> <reader> take.wav` builds ground truth from Apple's on-device recognizer
(chunked at quiet points, aligned to the expected performance), mixes the case's noise, streams it
through the recognizer and writes `fixtures/<case>-human-<reader>/`, marked `truthSource: auto-aligned`.
Validated on synthetic takes with exact truth: word end times within 0.07 s median (≤0.26 s p95),
skip and pause boundaries within 0.1 s, and the same scores as the synthetic fixtures.

### Known limits

- **No real people have been recorded yet.** The tooling is ready and validated, but someone has to
  read the scripts. Synthetic voices are cleaner and more regular than people.
- **Strong foreign accent (French voice, Apple recognizer, 50% WER):** tracking trails 9–13 words
  behind, then catches up (17 lost-place events per 10 min, report-only). Loosening the matcher
  was tested and rejected because the highlight ran ahead during ad-libs. Nemotron is the better engine
  for accented speakers. German voice (27% WER): no lost-place events, lag p95 1.7 s.
- Number words vs digits ("forty-two thousand" vs "42,000") aren't normalized.
- The iOS app uses iOS 27.1 SDK APIs (`AVCaptureDeviceDirectionCoordinator`, `reservedRegions`,
  `sceneAccessory`) and needs a newer Xcode than 26.1. To run the iOS suite here, three
  `#available(iOS 27.1)` blocks were stubbed locally for the run only and then reverted (no committed
  change).
- Recording needs an otherwise idle machine. GPU contention once stalled a local model for minutes
  (a re-record on an idle machine was clean).

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
| Drift during silence | words the highlight moves past where the reader stopped, while nobody is speaking (catching up to late transcripts of the last words is not drift) | should be 0 |
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
