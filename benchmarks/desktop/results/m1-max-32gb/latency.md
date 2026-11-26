# latency — spoken word → highlight, by stage (PLAN #2)

Host `m1-max-32gb`, commit `f9c6c94`, 2026-11-25T23:50:06-05:00.

## Engine `local-whisper-tiny-Q8_0`

### clean read, US voice [Samantha]

Source: frames the overlay showed

| Dimension | Case | Lost/10 min | Lost % time | Recovery p50/p95 (s) | Never recovered | Ahead >3w % time | Silence drift (w) | Lag p50/p95 (s) | Final err (w) | Pass |
|---|---|---|---|---|---|---|---|---|---|---|
| baseline | clean read, US voice | 0.00 | 0.0 | –/– | – | 0.3 | 0 | 0.80/1.63 | 0.0 | ❌ |

| Stage (word end → …) | p50 / p95 / max (ms) | n |
|---|---|---|
| ASR: word end → partial delivered | 662 / 1448 / 2700 | 295 |
| Main-queue hop: partial → matcher start | 0 / 2 / 9 | 295 |
| Matcher | 0 / 0 / 1 | 295 |
| Render: matcher done → frame shows it | 13 / 19 / 1328 | 295 |
| **End to end: word end → on screen** | 718 / 1473 / 2711 | 295 |

Word end times are interpolated inside synthesized phrases, so the ASR and end-to-end rows
carry roughly ±100 ms of ground-truth error; the hop, matcher and render rows don't.
All matcher calls: 0 / 0 / 1 over 61 partials.

| Resource | Value |
|---|---|
| Duration | 1.6 min |
| Memory start → end (peak) | 24.9 → 182.8 MB (212.3 MB) |
| Memory slope | 624.7 MB/h |
| CPU average | 39.0 % |
| Recognition sessions | begin 1, localWindow 3 |

### UK English (Daniel) [Daniel]

Source: frames the overlay showed

| Dimension | Case | Lost/10 min | Lost % time | Recovery p50/p95 (s) | Never recovered | Ahead >3w % time | Silence drift (w) | Lag p50/p95 (s) | Final err (w) | Pass |
|---|---|---|---|---|---|---|---|---|---|---|
| accent | UK English (Daniel) | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.73/1.53 | 0.0 | ❌ |

| Stage (word end → …) | p50 / p95 / max (ms) | n |
|---|---|---|
| ASR: word end → partial delivered | 663 / 1414 / 1688 | 292 |
| Main-queue hop: partial → matcher start | 0 / 5 / 8 | 292 |
| Matcher | 0 / 0 / 1 | 292 |
| Render: matcher done → frame shows it | 13 / 24 / 55 | 292 |
| **End to end: word end → on screen** | 680 / 1427 / 1705 | 292 |

Word end times are interpolated inside synthesized phrases, so the ASR and end-to-end rows
carry roughly ±100 ms of ground-truth error; the hop, matcher and render rows don't.
All matcher calls: 0 / 0 / 1 over 64 partials.

| Resource | Value |
|---|---|
| Duration | 1.7 min |
| Memory start → end (peak) | 25.1 → 207.5 MB (212.2 MB) |
| Memory slope | 1669.0 MB/h |
| CPU average | 37.8 % |
| Recognition sessions | begin 1, localWindow 3 |

### 4-talker babble, 10 dB [Samantha]

Source: frames the overlay showed

| Dimension | Case | Lost/10 min | Lost % time | Recovery p50/p95 (s) | Never recovered | Ahead >3w % time | Silence drift (w) | Lag p50/p95 (s) | Final err (w) | Pass |
|---|---|---|---|---|---|---|---|---|---|---|
| noise | 4-talker babble, 10 dB | 6.66 | 2.2 | –/– | – | 0.0 | 0 | 0.89/2.52 | 0.0 | ❌ |

| Stage (word end → …) | p50 / p95 / max (ms) | n |
|---|---|---|
| ASR: word end → partial delivered | 761 / 2411 / 4387 | 295 |
| Main-queue hop: partial → matcher start | 0 / 4 / 7 | 295 |
| Matcher | 0 / 0 / 1 | 295 |
| Render: matcher done → frame shows it | 13 / 23 / 63 | 295 |
| **End to end: word end → on screen** | 768 / 2428 / 4400 | 295 |

Word end times are interpolated inside synthesized phrases, so the ASR and end-to-end rows
carry roughly ±100 ms of ground-truth error; the hop, matcher and render rows don't.
All matcher calls: 0 / 0 / 1 over 59 partials.

| Resource | Value |
|---|---|
| Duration | 1.6 min |
| Memory start → end (peak) | 25.0 → 210.6 MB (215.2 MB) |
| Memory slope | 1979.1 MB/h |
| CPU average | 39.2 % |
| Recognition sessions | begin 1, localWindow 3 |

PLAN bars (base M1, Apple on-device): matcher p95 < 5 ms, hop p95 < 16 ms, render p95 < 1 frame, end to end p50 < 600 ms and p95 < 1200 ms.

## All metrics (median of runs, MAD)

| Metric | Median | MAD | Unit | Runs |
|---|---|---|---|---|
| latency.local-whisper-tiny-Q8_0.accent-gb.asrP50.ms | 663 | 0 | ms | 1 |
| latency.local-whisper-tiny-Q8_0.accent-gb.e2eP50.ms | 680 | 0 | ms | 1 |
| latency.local-whisper-tiny-Q8_0.accent-gb.e2eP95.ms | 1427 | 0 | ms | 1 |
| latency.local-whisper-tiny-Q8_0.accent-gb.hopP95.ms | 4.51 | 0 | ms | 1 |
| latency.local-whisper-tiny-Q8_0.accent-gb.lostPer10Min | 0 | 0 | events | 1 |
| latency.local-whisper-tiny-Q8_0.accent-gb.matcherP95.ms | 0.466 | 0 | ms | 1 |
| latency.local-whisper-tiny-Q8_0.accent-gb.renderP95.ms | 24.25 | 0 | ms | 1 |
| latency.local-whisper-tiny-Q8_0.baseline-us.asrP50.ms | 662 | 0 | ms | 1 |
| latency.local-whisper-tiny-Q8_0.baseline-us.e2eP50.ms | 718 | 0 | ms | 1 |
| latency.local-whisper-tiny-Q8_0.baseline-us.e2eP95.ms | 1473 | 0 | ms | 1 |
| latency.local-whisper-tiny-Q8_0.baseline-us.hopP95.ms | 2.49 | 0 | ms | 1 |
| latency.local-whisper-tiny-Q8_0.baseline-us.lostPer10Min | 0 | 0 | events | 1 |
| latency.local-whisper-tiny-Q8_0.baseline-us.matcherP95.ms | 0.496 | 0 | ms | 1 |
| latency.local-whisper-tiny-Q8_0.baseline-us.renderP95.ms | 18.54 | 0 | ms | 1 |
| latency.local-whisper-tiny-Q8_0.noise-babble-10.asrP50.ms | 761 | 0 | ms | 1 |
| latency.local-whisper-tiny-Q8_0.noise-babble-10.e2eP50.ms | 768 | 0 | ms | 1 |
| latency.local-whisper-tiny-Q8_0.noise-babble-10.e2eP95.ms | 2428 | 0 | ms | 1 |
| latency.local-whisper-tiny-Q8_0.noise-babble-10.hopP95.ms | 3.67 | 0 | ms | 1 |
| latency.local-whisper-tiny-Q8_0.noise-babble-10.lostPer10Min | 6.66 | 0 | events | 1 |
| latency.local-whisper-tiny-Q8_0.noise-babble-10.matcherP95.ms | 0.497 | 0 | ms | 1 |
| latency.local-whisper-tiny-Q8_0.noise-babble-10.renderP95.ms | 22.79 | 0 | ms | 1 |

No baseline yet for this host. Commit one with -update-baseline once the numbers look right.
