# latency — spoken word → highlight, by stage (PLAN #2)

Host `m1-max-32gb`, commit `8cee918`, 2026-11-26T04:27:44-05:00.

## Engine `apple`

### clean read, US voice [Samantha]

Source: frames the overlay showed

| Dimension | Case | Lost/10 min | Lost % time | Recovery p50/p95 (s) | Never recovered | Ahead >3w % time | Silence drift (w) | Lag p50/p95 (s) | Final err (w) | Pass |
|---|---|---|---|---|---|---|---|---|---|---|
| baseline | clean read, US voice | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.50/0.80 | 0.0 | ✅ |

| Stage (word end → …) | p50 / p95 / max (ms) | n |
|---|---|---|
| ASR: word end → partial delivered | 357 / 636 / 1337 | 295 |
| Main-queue hop: partial → matcher start | 0 / 0 / 10 | 295 |
| Matcher | 0 / 0 / 0 | 295 |
| Render: matcher done → frame shows it | 7 / 14 / 57 | 295 |
| **End to end: word end → on screen** | 369 / 643 / 1351 | 295 |

Word end times are interpolated inside synthesized phrases, so the ASR and end-to-end rows
carry roughly ±100 ms of ground-truth error; the hop, matcher and render rows don't.
All matcher calls: 0 / 0 / 0 over 320 partials.

| Resource | Value |
|---|---|
| Duration | 1.6 min |
| Memory start → end (peak) | 25.2 → 72.8 MB (74.5 MB) |
| Memory slope after 10 min | – (run shorter than 10 min: growth is warm-up) |
| CPU average | 28.0 % |
| Recognition sessions | begin 1, restartTask 1 |

### UK English (Daniel) [Daniel]

Source: frames the overlay showed

| Dimension | Case | Lost/10 min | Lost % time | Recovery p50/p95 (s) | Never recovered | Ahead >3w % time | Silence drift (w) | Lag p50/p95 (s) | Final err (w) | Pass |
|---|---|---|---|---|---|---|---|---|---|---|
| accent | UK English (Daniel) | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.53/0.89 | 0.0 | ✅ |

| Stage (word end → …) | p50 / p95 / max (ms) | n |
|---|---|---|
| ASR: word end → partial delivered | 399 / 742 / 1784 | 295 |
| Main-queue hop: partial → matcher start | 0 / 0 / 1 | 295 |
| Matcher | 0 / 0 / 0 | 295 |
| Render: matcher done → frame shows it | 8 / 15 / 52 | 295 |
| **End to end: word end → on screen** | 407 / 754 / 1798 | 295 |

Word end times are interpolated inside synthesized phrases, so the ASR and end-to-end rows
carry roughly ±100 ms of ground-truth error; the hop, matcher and render rows don't.
All matcher calls: 0 / 0 / 0 over 326 partials.

| Resource | Value |
|---|---|
| Duration | 1.7 min |
| Memory start → end (peak) | 25.0 → 74.0 MB (75.7 MB) |
| Memory slope after 10 min | – (run shorter than 10 min: growth is warm-up) |
| CPU average | 28.0 % |
| Recognition sessions | begin 1, restartTask 1 |

### 4-talker babble, 10 dB [Samantha]

Source: frames the overlay showed

| Dimension | Case | Lost/10 min | Lost % time | Recovery p50/p95 (s) | Never recovered | Ahead >3w % time | Silence drift (w) | Lag p50/p95 (s) | Final err (w) | Pass |
|---|---|---|---|---|---|---|---|---|---|---|
| noise | 4-talker babble, 10 dB | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.54/0.93 | 0.0 | ✅ |

| Stage (word end → …) | p50 / p95 / max (ms) | n |
|---|---|---|
| ASR: word end → partial delivered | 416 / 824 / 2226 | 295 |
| Main-queue hop: partial → matcher start | 0 / 0 / 11 | 295 |
| Matcher | 0 / 0 / 0 | 295 |
| Render: matcher done → frame shows it | 8 / 16 / 57 | 295 |
| **End to end: word end → on screen** | 428 / 837 / 2243 | 295 |

Word end times are interpolated inside synthesized phrases, so the ASR and end-to-end rows
carry roughly ±100 ms of ground-truth error; the hop, matcher and render rows don't.
All matcher calls: 0 / 0 / 0 over 325 partials.

| Resource | Value |
|---|---|
| Duration | 1.6 min |
| Memory start → end (peak) | 25.4 → 72.7 MB (75.3 MB) |
| Memory slope after 10 min | – (run shorter than 10 min: growth is warm-up) |
| CPU average | 28.4 % |
| Recognition sessions | begin 1, restartTask 1 |

## Engine `local-whisper-tiny-Q8_0`

### clean read, US voice [Samantha]

Source: frames the overlay showed

| Dimension | Case | Lost/10 min | Lost % time | Recovery p50/p95 (s) | Never recovered | Ahead >3w % time | Silence drift (w) | Lag p50/p95 (s) | Final err (w) | Pass |
|---|---|---|---|---|---|---|---|---|---|---|
| baseline | clean read, US voice | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.84/1.70 | 0.0 | ❌ |

| Stage (word end → …) | p50 / p95 / max (ms) | n |
|---|---|---|
| ASR: word end → partial delivered | 700 / 1484 / 3950 | 295 |
| Main-queue hop: partial → matcher start | 0 / 4 / 8 | 295 |
| Matcher | 0 / 0 / 1 | 295 |
| Render: matcher done → frame shows it | 12 / 19 / 52 | 295 |
| **End to end: word end → on screen** | 717 / 1502 / 3961 | 295 |

Word end times are interpolated inside synthesized phrases, so the ASR and end-to-end rows
carry roughly ±100 ms of ground-truth error; the hop, matcher and render rows don't.
All matcher calls: 0 / 0 / 1 over 60 partials.

| Resource | Value |
|---|---|
| Duration | 1.7 min |
| Memory start → end (peak) | 25.3 → 152.5 MB (210.9 MB) |
| Memory slope after 10 min | – (run shorter than 10 min: growth is warm-up) |
| CPU average | 37.3 % |
| Recognition sessions | begin 1, localWindow 3 |

### UK English (Daniel) [Daniel]

Source: frames the overlay showed

| Dimension | Case | Lost/10 min | Lost % time | Recovery p50/p95 (s) | Never recovered | Ahead >3w % time | Silence drift (w) | Lag p50/p95 (s) | Final err (w) | Pass |
|---|---|---|---|---|---|---|---|---|---|---|
| accent | UK English (Daniel) | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.75/1.53 | 0.0 | ❌ |

| Stage (word end → …) | p50 / p95 / max (ms) | n |
|---|---|---|
| ASR: word end → partial delivered | 648 / 1418 / 1683 | 292 |
| Main-queue hop: partial → matcher start | 0 / 0 / 8 | 292 |
| Matcher | 0 / 0 / 1 | 292 |
| Render: matcher done → frame shows it | 13 / 17 / 59 | 292 |
| **End to end: word end → on screen** | 659 / 1435 / 1699 | 292 |

Word end times are interpolated inside synthesized phrases, so the ASR and end-to-end rows
carry roughly ±100 ms of ground-truth error; the hop, matcher and render rows don't.
All matcher calls: 0 / 0 / 1 over 64 partials.

| Resource | Value |
|---|---|
| Duration | 1.7 min |
| Memory start → end (peak) | 25.1 → 204.8 MB (207.7 MB) |
| Memory slope after 10 min | – (run shorter than 10 min: growth is warm-up) |
| CPU average | 34.2 % |
| Recognition sessions | begin 1, localWindow 3 |

### 4-talker babble, 10 dB [Samantha]

Source: frames the overlay showed

| Dimension | Case | Lost/10 min | Lost % time | Recovery p50/p95 (s) | Never recovered | Ahead >3w % time | Silence drift (w) | Lag p50/p95 (s) | Final err (w) | Pass |
|---|---|---|---|---|---|---|---|---|---|---|
| noise | 4-talker babble, 10 dB | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.89/2.40 | 0.0 | ❌ |

| Stage (word end → …) | p50 / p95 / max (ms) | n |
|---|---|---|
| ASR: word end → partial delivered | 747 / 2189 / 3126 | 295 |
| Main-queue hop: partial → matcher start | 0 / 1 / 6 | 295 |
| Matcher | 0 / 0 / 1 | 295 |
| Render: matcher done → frame shows it | 13 / 27 / 52 | 295 |
| **End to end: word end → on screen** | 752 / 2201 / 3153 | 295 |

Word end times are interpolated inside synthesized phrases, so the ASR and end-to-end rows
carry roughly ±100 ms of ground-truth error; the hop, matcher and render rows don't.
All matcher calls: 0 / 0 / 1 over 59 partials.

| Resource | Value |
|---|---|
| Duration | 1.6 min |
| Memory start → end (peak) | 24.9 → 209.7 MB (214.3 MB) |
| Memory slope after 10 min | – (run shorter than 10 min: growth is warm-up) |
| CPU average | 35.0 % |
| Recognition sessions | begin 1, localWindow 3 |

PLAN bars (base M1, Apple on-device): matcher p95 < 5 ms, hop p95 < 16 ms, render p95 < 1 frame, end to end p50 < 600 ms and p95 < 1200 ms.

Apple engines need Speech Recognition permission for the bench app; macOS asks once per build.

## All metrics (median of runs, MAD)

| Metric | Median | MAD | Unit | Runs |
|---|---|---|---|---|
| latency.apple.accent-gb.asrP50.ms | 397 | 1.55 | ms | 3 |
| latency.apple.accent-gb.e2eP50.ms | 406 | 0.683 | ms | 3 |
| latency.apple.accent-gb.e2eP95.ms | 754 | 0.42 | ms | 3 |
| latency.apple.accent-gb.hopP95.ms | 0.11 | 0.00342 | ms | 3 |
| latency.apple.accent-gb.lostPer10Min | 0 | 0 | events | 3 |
| latency.apple.accent-gb.matcherP95.ms | 0.371 | 0.00254 | ms | 3 |
| latency.apple.accent-gb.renderP95.ms | 14.54 | 0.0926 | ms | 3 |
| latency.apple.baseline-us.asrP50.ms | 359 | 1.04 | ms | 3 |
| latency.apple.baseline-us.e2eP50.ms | 371 | 0.275 | ms | 3 |
| latency.apple.baseline-us.e2eP95.ms | 644 | 0.788 | ms | 3 |
| latency.apple.baseline-us.hopP95.ms | 0.113 | 0.0065 | ms | 3 |
| latency.apple.baseline-us.lostPer10Min | 0 | 0 | events | 3 |
| latency.apple.baseline-us.matcherP95.ms | 0.38 | 0.00529 | ms | 3 |
| latency.apple.baseline-us.renderP95.ms | 13.98 | 0.311 | ms | 3 |
| latency.apple.noise-babble-10.asrP50.ms | 416 | 0.175 | ms | 3 |
| latency.apple.noise-babble-10.e2eP50.ms | 428 | 0.636 | ms | 3 |
| latency.apple.noise-babble-10.e2eP95.ms | 837 | 10.64 | ms | 3 |
| latency.apple.noise-babble-10.hopP95.ms | 0.119 | 0.00729 | ms | 3 |
| latency.apple.noise-babble-10.lostPer10Min | 0 | 0 | events | 3 |
| latency.apple.noise-babble-10.matcherP95.ms | 0.358 | 0.00937 | ms | 3 |
| latency.apple.noise-babble-10.renderP95.ms | 14.21 | 0.802 | ms | 3 |
| latency.local-whisper-tiny-Q8_0.accent-gb.asrP50.ms | 637 | 4.13 | ms | 3 |
| latency.local-whisper-tiny-Q8_0.accent-gb.e2eP50.ms | 648 | 5.76 | ms | 3 |
| latency.local-whisper-tiny-Q8_0.accent-gb.e2eP95.ms | 1418 | 1.68 | ms | 3 |
| latency.local-whisper-tiny-Q8_0.accent-gb.hopP95.ms | 1.16 | 0.9 | ms | 3 |
| latency.local-whisper-tiny-Q8_0.accent-gb.lostPer10Min | 0 | 0 | events | 3 |
| latency.local-whisper-tiny-Q8_0.accent-gb.matcherP95.ms | 0.47 | 0.0267 | ms | 3 |
| latency.local-whisper-tiny-Q8_0.accent-gb.renderP95.ms | 16.64 | 0.661 | ms | 3 |
| latency.local-whisper-tiny-Q8_0.baseline-us.asrP50.ms | 700 | 0.366 | ms | 3 |
| latency.local-whisper-tiny-Q8_0.baseline-us.e2eP50.ms | 716 | 1.56 | ms | 3 |
| latency.local-whisper-tiny-Q8_0.baseline-us.e2eP95.ms | 1499 | 2.81 | ms | 3 |
| latency.local-whisper-tiny-Q8_0.baseline-us.hopP95.ms | 1.69 | 0.808 | ms | 3 |
| latency.local-whisper-tiny-Q8_0.baseline-us.lostPer10Min | 0 | 0 | events | 3 |
| latency.local-whisper-tiny-Q8_0.baseline-us.matcherP95.ms | 0.476 | 0.00175 | ms | 3 |
| latency.local-whisper-tiny-Q8_0.baseline-us.renderP95.ms | 19.04 | 1.07 | ms | 3 |
| latency.local-whisper-tiny-Q8_0.noise-babble-10.asrP50.ms | 759 | 0.0674 | ms | 3 |
| latency.local-whisper-tiny-Q8_0.noise-babble-10.e2eP50.ms | 771 | 1.90 | ms | 3 |
| latency.local-whisper-tiny-Q8_0.noise-babble-10.e2eP95.ms | 2432 | 47.10 | ms | 3 |
| latency.local-whisper-tiny-Q8_0.noise-babble-10.hopP95.ms | 1.19 | 0.819 | ms | 3 |
| latency.local-whisper-tiny-Q8_0.noise-babble-10.lostPer10Min | 0 | 0 | events | 3 |
| latency.local-whisper-tiny-Q8_0.noise-babble-10.matcherP95.ms | 0.433 | 0.0172 | ms | 3 |
| latency.local-whisper-tiny-Q8_0.noise-babble-10.renderP95.ms | 24.46 | 0.937 | ms | 3 |

No baseline yet for this host. Commit one with -update-baseline once the numbers look right.
