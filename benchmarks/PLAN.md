# Desktop Benchmark Suite: Plan

**Goal:** catch the regressions that Mac users actually notice: the prompter losing
their place, the highlight trailing their voice, dropped frames, battery and fan drain
while the app sits open, memory creep over long sessions, and slow launches.

The speech-tracking benchmark (`speech-tracking/PLAN.md`) is the model for this
suite: replays you can repeat exactly, a results table you can commit, and a
`-check` mode for CI. Everything below follows that pattern.

| # | Benchmark | Question it answers | Where it runs |
|---|---|---|---|
| 1 | Real-audio tracking | Does tracking hold up with real voices, mics and engines? | record: Mac · score: CI |
| 2 | End-to-end latency | How long from a spoken word to the word highlighting on screen? | bench Mac |
| 3 | Local engine perf & thermals | Can this model keep up on this Mac, and keep up for 30 min? | bench Mac + matrix |
| 4 | Overlay rendering | Does the prompter stay smooth on a 50k-word script at 120 Hz? | bench Mac |
| 5 | Idle / open-but-paused cost | What does leaving Textream open cost in battery? | bench Mac |
| 6 | Long-session soak | Does a 90-min session end like it started? | bench Mac (nightly) |
| 7 | Director/browser broadcast | What does remote mode cost per client and per script size? | CI (relative) |
| 8 | Cold launch & time-to-first-prompt | How fast from click to reading? | bench Mac |

All pass bars below are **provisional**. Phase 0 records baselines, and the bars get
set from those numbers, as §8 of the speech-tracking plan did.

## Status (2026-11-25)

**Built:** Phase 0 and all eight benchmarks, in `benchmarks/desktop/` (runner, engine
tool, CI) plus additions to the speech-tracking harness (`render-audio`, `score-app`,
engine selection for Layer B). First numbers from an M1 Max (32 GB) are in
`desktop/results/m1-max-32gb/` and summarized under [First results](#first-results).

```
cd benchmarks/desktop
go run run.go build                               # BENCHMARK app + harness + engine tool → .cache/
go run run.go fetch-model whisper-base-gguf Q8_0  # catalog model, sha256-checked
go run run.go micro | launch | idle | render | broadcast | latency | soak | engine
go run run.go nightly -check                      # everything, against results/<host>/baseline/
go run run.go <bench> -update-baseline            # accept this run as the baseline
```

The app opens real windows, so runs need a logged-in GUI session and must run outside
any sandbox. Results land in `desktop/results/<host>/<bench>.{md,json}`.

**How it differs from the plan text below** (each choice keeps the same measurement
with less machinery):
- **Both measurement routes exist.** The test targets from Phase 0 are built:
  `TextreamTests` (macOS unit tests, including a check that the redraw search matches
  the old linear scan, plus `XCTClockMetric`/`XCTCPUMetric` performance tests) and
  `TextreamUITests` (`XCTApplicationLaunchMetric`), in a shared `Textream` scheme.
  The runner also measures the same paths inside the BENCHMARK app (`-bench-micro`;
  launch from the kernel's process start time to the main window's first display
  refresh, which excludes LaunchServices). UI tests need automation mode on the Mac
  that runs them: `sudo automationmodetool enable-automationmode-without-authentication`,
  once. GitHub's hosted runners already have it.
- **No `top` or `powermetrics`.** The app samples itself with `task_info`: CPU time,
  idle and interrupt wakeups, the kernel's energy estimate (Apple silicon), and
  `phys_footprint`. No sudo is needed. Sampling every 10 s adds about 0.1 wakeups/s.
- **Frame pacing comes from an in-app display-link probe** (`BenchFrameProbe`). A
  refresh callback that arrives more than 1.5 frames late means the main thread was
  busy. `render -xctrace` still records Instruments "Animation Hitches" traces for
  investigation.
- **`OSSignposter` events are emitted only in the BENCHMARK build.** Decision 4 (ship
  them in Release) is still open; the hooks are one-line `benchLog` calls that compile
  to nothing today.
- **The benchmark build has its own identity:** bundle id `dev.fka.textream.bench`,
  ad-hoc signed without the App Sandbox (`desktop/Bench.entitlements`), with
  preferences wiped before every run and models read from `.cache/models`. It never
  touches the user's Textream settings or models.
- **#7 clients use browser mode** (no auth token). Director mode's encode cost is in
  the micro benchmark.

**Not done, because it needs people or hardware this session doesn't have:**
- the real-reader corpus (#1 step 3)
- a dedicated bench Mac registered as the `textream-bench` self-hosted runner
- the Intel and base-M1 matrix
- Sidecar
- the manual sleep/wake, mic-switch and display hot-plug checklist (#6)
- running the UI launch test here (automation mode needs an admin prompt)

The workflows that use them are written (`.github/workflows/desktop-bench.yml`) and
start working once the runner exists.

### First results

Host: M1 Max, 32 GB, external 75 Hz display. Full tables are in
`desktop/results/m1-max-32gb/`. The committed baselines in `results/m1-max-32gb/baseline/`
come from repeated runs: 3–5 per scenario, idle at 2 min, render at 30 s, soak at 30 min.
They were measured overnight with the fixes below applied. Nightly runs on a dedicated
bench Mac should replace them with full-length runs (`-update-baseline`). Rows marked
"fixed" show before → after.

| # | Finding | Number | Bar |
|---|---|---|---|
| 4 | Per-redraw scan grows with the script and the highlight's position | 50k words at 90%: **19 ms per redraw**; 10k: 3.9 ms → **fixed: 0.046 ms** | — |
| 4 | Frame pacing on long scripts | 50k words: 26–46 ms/s hitching, worst frame 380–706 ms, mostly the first layout of the script → **fixed: worst frame 48 ms**; ~13 ms/s of small hitches remain | < 5 ms/s ❌ |
| 7 | Browser/director encode the whole script on every 100 ms tick | 50k words: **13 ms per encode, 4.2 MB/s to every client**, 18–20% app CPU, ~95 ms delay → **fixed: 0.012 ms, 32 KB/s** | — |
| 5 | The open overlay keeps timers running while paused | **31–34 wakeups/s** (pinned/floating), up to 1.6% CPU → **fixed: 11–14/s** | < 20/s ✅ |
| 5 | Moving the highlight is expensive | classic scroll 28–31% CPU, ~440–530 mW; tracking UI (no ASR) 18–26% CPU | — |
| 5 | Idle in the menu bar, main window, servers on | ≤ 0.01% CPU, 0.2–0.4 wakeups/s | ✅ |
| 2 | Apple on-device keeps up | end to end p50 367–424 ms / p95 641–794 ms across clean, UK voice and babble 10 dB; 0 lost-place events | p95 < 1.2 s ✅ |
| 2 | With local whisper-tiny, recognition is nearly all of the latency | end to end p50 0.7 s / p95 1.4 s (clean), 2.4 s (babble 10 dB); hop ≤ 5 ms, matcher ≤ 1 ms, render ~13 ms | p95 < 1.2 s ❌ |
| 2 | Babble at 10 dB through whisper-tiny loses the place | 6.7 lost-place events / 10 min | ≤ 0.5 ❌ |
| 3 | whisper-tiny keeps up easily | 26-s decode 0.22 s, partials every 1.5 s, 153 MB | ✅ |
| 3 | moonshine-streaming-tiny falls behind | chunk RTF p50 0.08 but **p95 9.5**: 60 s of audio took 120 s; partials every 4.6 s (p95); 550 MB | ❌ |
| 3 | First model load after install compiles Metal shaders | **10.2 s** once, then 0.1 s (fresh process), 0.05 s reload → moved to right after download | — |
| 8 | Launch is dominated by work before `didFinishLaunching` | main window first frame 575 ms (didFinishLaunching at 288 ms; its own steps < 3 ms) | < 400 ms ❌ |
| 8 | Time to first prompt | not running 454 ms; running 112 ms; first highlight (local whisper-tiny) 1.77 s | < 300 ms ✅ (running) |
| 6 | Rehearsal soak with whisper-tiny (one script read 18× in 30 min, jumping to the top each time) | no degradation across loops (lag p95 1.8–6 s varies per take, no trend; cadence, matcher and CPU flat); footprint swings 145–218 MB per recognition window; 194 leaks / 9.6 KB, stable across runs | see the baseline soak for the current numbers |
| 1 | Layer B now records per engine | `baseline-us`: Apple on-device lag p95 0.78 s ✅; whisper-tiny 1.64 s ❌ (report-only: only the default engine gates CI, `GATE_ENGINES` overrides) | §8 bar |

Measurement pitfalls found while building this (now handled in the runner):
- **Display sleep stops vsync**, and with it every frame measurement. The runner holds
  `caffeinate -d -i -u` for as long as each app run is alive.
- **Boolean launch arguments arrive as strings.** Settings read with
  `object(forKey:) as? Bool` ignore `-key YES`. The runner passes `<true/>`.
- **A script made of identical copies never advances:** the matcher's refrain guard
  won't commit when every phrase occurs many times. The soak therefore reads one copy
  and jumps back to the top each loop, like a rehearsal.
- **Reaching the last word closes the overlay**, so the soak script ends with a sentence
  the audio never speaks.

### Fixes made from these numbers

| Fix | Where | Before → after |
|---|---|---|
| Next-word search is a binary search over precomputed letter counts (equivalence-tested against the old scan) | `MarqueeTextView.swift` `nextWordIndex` | per-redraw work at 50k words, highlight at 90%: **19.35 → 0.046 ms**; 10k: 3.85 → 0.010 ms. Layout build on a new script is 4–9% slower (letter counts computed once) |
| Line layout measures each distinct word's width once per pass | `MarqueeTextView.swift` `buildLines` | first layout of a 50k-word script **455 → 60 ms**; worst frame when starting a 50k-word read ~520 → 48 ms |
| Director broadcasts no longer carry the script (its page never read it) | `DirectorServer.swift` | encode per 100 ms tick at 50k words: **13 → 0.012 ms** |
| Browser broadcasts send the script once per connection, and skip unchanged ticks | `BrowserServer.swift` (+ page keeps the last words) | per client at 50k words: **4.2 MB/s → 32 KB/s** (mostly the one-time script); encode per tick 13 → 0.012 ms |
| The 50 ms scroll tick runs only in classic/voice-activated modes and while not paused, and advances by real elapsed time | `NotchOverlayController.swift` (×2), `ExternalDisplayController.swift` | paused overlay: **31–34 → 11–14 wakeups/s** (bar < 20 ✅) |
| A downloaded model's GPU pipelines are built right after download, on a throwaway `Model` | `ModelDownloadManager.swift`, `LocalSpeechEngine.warmUp` | moves the one-time 10 s Metal compile out of the first reading session (not re-measurable on this Mac: its shader cache is already warm) |

**Overlay frame pacing on long scripts: diagnosed, then fixed where reproducible.**
- **The 2–5 AM runs misled.** The first post-fix render runs showed 100–380 ms freezes
  on every word step once scrolling began. Later runs in the same conditions don't
  reproduce them: starting the highlight halfway into a 50k-word script
  (`render -from 0.5`), deep-script playback costs about 2% CPU. The night runs were
  environmental. Overnight, the Mac sat in deep idle until the runner woke the display.
- **Not the tall spacer.** Removing the transparent spacer below the visible lines
  made no difference in an A/B (15–16 ms/s of hitching in both builds), so that
  change was reverted.
- **The one reproducible freeze was the first layout of a long script:** about 520 ms
  at 50k words, almost all of it spent measuring each word's width. `buildLines` now
  measures each distinct word once per pass:

| | Before | After |
|---|---|---|
| First layout, 50k words (micro) | 455 ms | 60 ms |
| First layout, 10k words (micro) | 91 ms | 13 ms |
| Worst frame at the start of a 50k-word read | ~520 ms | 48 ms (no frame over 100 ms) |

  The generated test script has about 60 distinct words, so that's a best case. A real
  50k-word script has thousands of distinct words, so its gain is smaller but still large.
- **What's left:** about 13 ms/s of small hitches (bar < 5 ms/s), with no visible freezes.

**The "long-session drift" in #6 was a measurement artifact, not the app.** Per-loop
scoring of the 30-minute soak shows no trend: lag p95 varies from 1.8 to 6 s from take
to take, and loop 17 is among the best. Partial cadence (1.5 s), matcher time and CPU
are flat across all 18 loops. Two harness problems caused it, both fixed:
- **The last loop was cut short.** The runner assumed each loop was 1 s longer than the
  transcript, but the audio has about 1.3 s of lead-in and tail silence, so the session
  quit before the final words. That was the "final error 12 words".
- **The memory figure was a straight line fitted through noise.** Footprint rises and
  falls 145–218 MB with every recognition window. The soak now compares the median
  footprint of the first and last quarter after warm-up.

On that measure, 30 minutes shows about 4 MB of growth, inside the per-window swing.
Whether there's a slow leak is for the 90-minute nightly soak to settle.

Not changed (product decisions): offering moonshine-streaming-tiny for word tracking
(it falls behind real time even on an M1 Max), and shipping the `OSSignposter` hooks
in Release (decision 4).

---

## Phase 0: shared infrastructure (do first, ~3–4 days)

Every benchmark below depends on these. Build each one only once.

1. **`BENCHMARK` build.** Use the Release config, plus
   `SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) BENCHMARK'` and the
   `get-task-allow` entitlement (so `leaks` and `xctrace` can attach). Never ship it.
   Perf numbers always come from this build, never from Debug.
2. **Benchmark launch arguments** (`#if BENCHMARK`, parsed in
   `applicationDidFinishLaunching`):
   - `-bench-script <file|words:N>`: load a script, or generate one with N words.
   - `-bench-audio <wav>`: feed a file instead of the mic (see 3).
   - `-bench-autoplay <wpm>`: move the highlight at a fixed rate with no ASR.
     Used for rendering tests (#4), so ASR doesn't add noise.
   - `-bench-mode notch|floating|fullscreen|external`, `-bench-font <name>`.
   - `-bench-quit-after <s>`: quit after this many seconds.
   - `-bench-log <path>`: where to write the event log (see 4).
3. **File-fed audio hook.** In `SpeechRecognizer`'s tap setup, when `-bench-audio`
   is set, read the WAV with `AVAudioFile` and send buffers at real-time pace (an
   `AVAudioPlayerNode` into the engine, tapped where the mic tap is now). The rest of
   the pipeline is unchanged: level metering, Apple speech requests, and
   `LocalSpeechEngine.feed`. Do the full real-mic path through a loopback device
   (e.g. BlackHole) **once** as a cross-check, not in the regular runs.
4. **Event log.** Add a ~30-line `BenchLog` helper, used only in the BENCHMARK
   build. It appends one JSON line per event:
   `{"e":"partial","t":<mach_absolute_time ns>,...}`. Also emit the same points
   through `OSSignposter` (subsystem `dev.fka.textream`, category `Perf`), so a
   human can open a run in Instruments. Benchmarks parse the JSONL rather than
   `xctrace export` XML.
5. **macOS test targets.** Today only `TextreamiOSTests` exists. Add:
   - `TextreamTests` (macOS unit + `measure {}` perf tests): items #4 micro, #7.
   - `TextreamUITests` (macOS UI test bundle): item #8 (`XCTApplicationLaunchMetric`).
6. **Runner and results.** One Go runner, `benchmarks/desktop/run.go`, in the same
   style as `speech-tracking/run.go`, with one subcommand per benchmark
   (`latency`, `engine`, `render`, `idle`, `soak`, `broadcast`, `launch`).
   - It builds the BENCHMARK app once, runs each scenario **5×**, and reports the
     median and MAD (median absolute deviation).
   - It writes `results/<host-class>/<bench>.md` and `.json`. `<host-class>` is the
     chip and RAM, e.g. `m1-8gb` or `m3pro-18gb`.
   - `-check` compares against the committed baseline JSON for that host class.
     It fails on a **>10% regression in the median, and only if the MAD of both
     runs is less than half of that gap** (to stop noisy runs from failing CI).
7. **Hardware.**
   - One dedicated physical Mac as a self-hosted runner, at minimum a **base M1
     MacBook Air, 8 GB** (fanless, the worst case for thermals and memory). Add an
     M-series Pro if one is available.
   - Disable Spotlight indexing and Time Machine on it, and turn off auto-brightness
     and True Tone.
   - Give it a narrow sudoers entry for `purge` and `powermetrics` only.
   - GitHub's `macos-15` runners are VMs, so their timing is noise. Use them only
     for deterministic work (#1 scoring, #7 relative).

---

## 1. Real-audio tracking (extends speech-tracking Layer B)

**Status today:** `speech-tracking/Sources/Audio.swift` already does `record-audio`
(macOS TTS voices plus babble, TV and HVAC noise, streamed in real time into
on-device `SFSpeechRecognizer`) and `score-audio` (replays the fixtures through the
matcher). Only `fixtures/baseline-us` is recorded, and only Apple on-device is
covered.

**Work:**
1. **Record all synthetic audio cases** for Apple on-device and commit the fixtures
   (partials JSONL plus the ground-truth timeline; small files). The audio itself
   regenerates from TTS, so keep it out of git.
2. **Add engines.** Add `-engine apple-ondevice | apple-server | local:<model-file>`
   to `record-audio`.
   - For `local:`, make the harness a SwiftPM package that depends on
     `Textream/Vendor/TranscribeCpp` and compiles `LocalSpeechEngine.swift` directly.
     First check that the file builds outside the app target (it's a singleton with
     callbacks and should).
   - Also record the backend (`metal` / `cpu`).
   - Fixtures go in `fixtures/<engine>@<engine-version>/<case>/`, so an engine or
     model bump creates a new set rather than overwriting the old one.
3. **Real-reader corpus.**
   - 12 readers × 3 scripts (general, technical, repeated) × 2 mics (built-in,
     AirPods), with accents and speeds spread on purpose.
   - Get written consent.
   - Store the WAVs in a private bucket, **not** git. Commit only the partials and
     the hand-aligned word timelines.
   - Alignment: auto-align with a local Whisper model that outputs word timestamps,
     then spot-fix by hand (about 15 min per take).
4. **Report.** `score-audio` prints per-engine tables with the existing metrics.
   CI (the existing `speech-tracking.yml`) scores every committed fixture set.

**Gate:** the existing §8 launch bar, per engine. An engine that fails can't be the
default for that language.

**Effort:** 1 + 2 ≈ 1 week; 3 ≈ 1 week of calendar time (mostly logistics).

---

## 2. Spoken word → highlight on screen

**Measure** each stage separately, so a regression points at its cause:

| Stage | Start event | End event |
|---|---|---|
| ASR | word ends in the audio (fixture timeline) | partial containing it is delivered (`recognitionTask` callback, `SpeechRecognizer.swift:617`) |
| Main-queue hop | callback | `matchCharacters` starts |
| Matcher | `matchCharacters` start | `recognizedCharCount` published |
| Render | publish | next vsync (log from an `NSView.displayLink` callback on the overlay view) |

**Run:** `run.go latency` launches the BENCHMARK app with `-bench-audio` (the
general script, 3 voices from #1) and `-bench-log`, waits for it to quit, then joins
the log events to the fixture timeline.

**Report:** p50/p95/max for each stage and for the end-to-end total, per engine.

**Provisional bars** (base M1, Apple on-device):
- matcher p95 < 5 ms
- main-queue hop p95 < 16 ms
- render p95 < 1 frame
- end-to-end p50 < 0.6 s, p95 < 1.2 s

**Effort:** 2 days after Phase 0.

---

## 3. Local engine performance & thermals

The Whisper path re-decodes a window that grows to 26 s, every 1.5 s
(`LocalSpeechEngine.swift:92-93`). If one decode takes longer than about 1.5 s,
partials queue up and tracking lags further and further behind.

**Run:** `run.go engine` drives `LocalSpeechEngine` from the #1 harness with no UI.
It has two modes:
- **paced:** real-time feed, like the app.
- **sweep:** decode one fixed window at 1, 2, 4, … 26 s lengths, 10× each, to get
  the cost curve.

**Metrics** per model × quant × backend × machine:
- model load: first load in a fresh process, and second load
- first-partial latency (audio start → first non-empty partial)
- decode time vs window length (the curve); headline number: **decode at 26 s**
- partial interval p50/p95 in paced mode (should be about 1.5 s; growth = falling behind)
- real-time factor
- peak memory (`phys_footprint` from `task_info`, sampled at 10 Hz)
- **Thermal:** 30 min paced on the fanless Air, logging decode time and
  `ProcessInfo.thermalState` every 30 s. Report the decode-time ratio between
  minutes 25–30 and minutes 0–5.

**Matrix:** every model in `SpeechModelCatalog` × base M1 8 GB, M-Pro, and **one
Intel Mac** (the README claims Intel support; if it can't run any local model in
real time, say so in the UI or drop the claim).

**Gate and product output:** a model is "recommended" on a chip class when its
26-s decode is under 1.0 s (about 33% headroom) **and** its thermal ratio is under
1.3. Record this in a checked-in table that the model settings UI can read later.

**Effort:** 3–4 days, plus machine time for the matrix.

---

## 4. Overlay rendering vs script size

**Known per-redraw work that grows with the whole script**
(`MarqueeTextView.swift:631-669`):
- the cache key sorts every paragraph-break index into a string
- `words == Self._cachedWords` compares the full array
- `nextWordIndex` scans and filters every word up to the current one

All of this runs on every partial, and every 50 ms in the timer-scrolled modes.

**Two layers:**
1. **Micro** (`TextreamTests`, `measure {}` with `XCTClockMetric` / `XCTCPUMetric`):
   time `cachedLayout()` on a cache hit and `nextWordIndex` at 1k / 10k / 50k words,
   with the highlight at 10%, 50% and 90%. Cheap; runs in CI as a relative check.
2. **Real frames:** `run.go render` launches with `-bench-script words:N
   -bench-autoplay 150 -bench-quit-after 60` under
   `xctrace record --template 'Animation Hitches'`.

**Matrix:**
- N ∈ {1k, 10k, 50k}
- font ∈ {system, OpenDyslexic}
- mode ∈ {notch, floating, fullscreen, external display}
- display: built-in 120 Hz ProMotion and an external 60 Hz display
- Sidecar: manual run each release

**Metrics:** hitch time ratio (ms of hitching per second), worst frame, main-thread
CPU %.

**Provisional bars:** hitch ratio < 5 ms/s (Apple's "good" threshold); main-thread
CPU < 15% at 50k words.

**Likely fixes, only if the numbers say so:** cache by script identity instead of
rebuilding the key; binary search over `charOffset` for `nextWordIndex`.

**Effort:** 2–3 days.

---

## 5. Idle / open-but-paused cost

**Timers to watch:**
- 60 Hz cursor tracking (`NotchOverlayController.swift:177`)
- 0.3 s mouse tracking (`:163`)
- two 50 ms scroll timers (`:698`, `:1294`)
- two 0.1 s broadcast timers (`DirectorServer.swift:256`, `BrowserServer.swift:180`)

**Scenarios:** 5 min each, after a 1-min settle.

| Scenario | Provisional bar |
|---|---|
| A. Launched, main window closed | < 0.1% CPU, < 2 wakeups/s |
| B. Main window open, no session | < 0.5% CPU, < 5 wakeups/s |
| C. Overlay open, **paused** (each overlay mode) | < 1% CPU, < 20 wakeups/s |
| D. Director + browser servers on, no clients | adds < 1 wakeup/s over A |
| E. Classic scrolling (reference, not gated) | — |
| F. Word tracking, Apple on-device (reference, not gated) | — |

**Run:** `run.go idle` samples
`top -l 300 -s 1 -stats pid,cpu,idlew,power -pid <pid>` (no sudo needed). On the
bench Mac, also sample `sudo powermetrics --samplers tasks --show-process-energy`
for the energy number that Activity Monitor shows.

**Effort:** 1–2 days. This is the cheapest high-value item. Most of the wins will
come from stopping timers whose output isn't visible.

---

## 6. Long-session soak (nightly)

**Run:** `run.go soak` runs a 90-min BENCHMARK session with `-bench-audio` looping
a 10-min real-reader take from #1 (a 90-min script made of the take's script
repeated). Apple on-device by default; one night a week with the recommended local
model.

**Sample every 30 s:**
- memory (`phys_footprint`), CPU
- tracking error against ground truth
- count of recognizer restarts (expected: one about every 55 s)

**Pass:**
- memory slope < 5 MB per hour after the first 10 min
- tracking metrics in minutes 80–90 match minutes 0–10 within noise
- restart count matches what's expected
- `leaks <pid>` at the end reports 0 leaked bytes from app code

**Manual release checklist** (a person runs these once per release; automating them
needs sudo and hardware tricks that aren't worth it yet):
- sleep and wake mid-session
- switch the mic mid-session (built-in → AirPods → built-in)
- unplug and replug an external display while in fullscreen-on-external mode
- the user's default input device changing while the app is in the background

**Effort:** 2 days.

---

## 7. Director/browser broadcast cost

`broadcastCurrentState` JSON-encodes the full `words` array every 100 ms, then
compares the result to the last payload (`DirectorServer.swift:262-293`;
`BrowserServer` follows the same pattern).

**Two layers:**
1. **Micro** (`TextreamTests`): encode a `DirectorState` with 1k / 10k / 50k words.
   Report time per encode, CPU per second at 10 Hz, and payload bytes.
   Deterministic enough for CI as a relative check.
2. **Clients:** start the server in-process on a free port and connect N ∈
   {1, 5, 20} `URLSessionWebSocketTask` clients with the auth token. Run a 60-s
   autoplay session. Measure server CPU, bytes sent per client per second, and
   end-to-end delay (highlight change → client receives it).

**Expected outcome:** encode cost grows with script size even when nothing changed.
If the numbers confirm it, send the script once per connection and then only send
position, level and state changes. The benchmark is the before/after proof.

**Effort:** 1–2 days.

---

## 8. Cold launch & time-to-first-prompt

**Launch path today** (`TextreamApp.applicationDidFinishLaunching`):
- `NSUpdateDynamicServices`
- an update check (direct-download builds)
- starting the browser and director servers

A local model is loaded lazily when a session starts (`SpeechRecognizer.swift:266`),
so it isn't part of launch, but it **is** part of time-to-first-prompt.

**Metrics:**
1. **Launch time** (`TextreamUITests`, `XCTApplicationLaunchMetric`, 5 iterations):
   process start → first frame of the main window.
   - **Warm:** run as-is.
   - **Cold:** on the bench Mac, run `sudo purge` before each iteration to drop the
     file cache. A reboot is the only truly cold launch, so do that manually once
     per release.
2. **Time-to-first-prompt:** `open "textream://read?text=..."` (the existing
   `handleURL` → `readText` path) → first overlay frame (log + signpost). Measure:
   - app not running
   - app running
   - for word tracking, until the first highlight moves, with Apple on-device
     and with the recommended local model (which includes model load)
3. **Breakdown:** add signposts around each step of `applicationDidFinishLaunching`,
   so a regression names its step (the update check and server start are the
   suspects).

**Provisional bars** (base M1):
- warm launch < 400 ms; cold < 1.5 s
- first overlay frame from URL, app running: < 300 ms
- first highlight with a local model: under model load + 2 s

**Effort:** 2 days (most of it is the new UI test target).

---

## Order and schedule

| Week | Work | Why this order |
|---|---|---|
| 1 | Phase 0 · #5 idle | Infra everything else needs; #5 is cheap and likely to find wins right away |
| 2 | #1 steps 1–2 · #3 | Decide which engines and models can be the tracking default |
| 3 | #2 latency · #8 launch | Uses the event log and the file-fed audio from Phase 0 |
| 4 | #4 rendering · #7 broadcast | Both have a micro layer that adds to CI |
| 5 | #6 soak to nightly · baselines committed · `-check` turned on | Turn measurements into gates |
| ongoing | #1 step 3, the real-reader corpus | Calendar-bound; plug it in when ready |

**CI split:**
- **On every PR (GitHub runners):**
  - #1 scoring (already wired through `speech-tracking.yml`)
  - the micro layers of #4 and #7, compared against `master` built on the same runner
- **Nightly on the bench Mac:** #2, #3 (paced only), #4 frames, #5, #6, #8.
- **Weekly:** the #3 sweep and the 30-min thermal run.
- **Per release:** the full #3 matrix, including Intel; the manual #6 checklist;
  Sidecar for #4; a cold launch after reboot.

## Decisions needed

1. **Bench hardware:** is a dedicated base M1 Air (8 GB) available as a self-hosted
   runner? Without one, everything except #1, #4-micro and #7-micro is manual.
2. **Intel:** keep claiming Intel support? If so, an Intel machine needs to be in
   the #3 matrix every release.
3. **Real readers:** who records, how consent is collected, and where the private
   audio lives.
4. **Signposts in shipping builds:** the `OSSignposter` points cost almost nothing
   when nobody is recording. Keeping them in Release lets users send Instruments
   traces in bug reports. Recommended, but it's a product call.

## Not in scope

- iOS capture and recording performance (separate suite).
- Model download speed (depends on the network).
- Benchmarking code that isn't on a hot path.
