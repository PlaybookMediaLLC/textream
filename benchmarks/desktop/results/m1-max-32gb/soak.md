# soak — long session (PLAN #6)

Host `m1-max-32gb`, commit `f9c6c94`, 2026-11-26T01:00:40-05:00.

## Engine `local-whisper-tiny-Q8_0`

### realistic take, UK voice, babble 15 dB [Daniel] × 8 loops

Source: frames the overlay showed

| Dimension | Case | Lost/10 min | Lost % time | Recovery p50/p95 (s) | Never recovered | Ahead >3w % time | Silence drift (w) | Lag p50/p95 (s) | Final err (w) | Pass |
|---|---|---|---|---|---|---|---|---|---|---|
| composite | realistic take, UK voice, babble 15 dB | 2.85 | 3.6 | 1.8/2.9 | 0/39 | 0.8 | 0 | 0.79/1.96 | 0.0 | ❌ |

First vs last loop (rescored from the same log after a scorer fix that ends each loop's window before the jump back to the top):

| Dimension | Case | Lost/10 min | Lost % time | Recovery p50/p95 (s) | Never recovered | Ahead >3w % time | Silence drift (w) | Lag p50/p95 (s) | Final err (w) | Pass |
|---|---|---|---|---|---|---|---|---|---|---|
| soak | loop 1 of 8 | 0.00 | 0.0 | 0.2/1.0 | 0/4 | 0.5 | 0 | 0.79/1.96 | 0.0 | ❌ |
| soak | loop 8 of 8 | 11.50 | 6.9 | 0.8/1.9 | 0/4 | 0.5 | 0 | 1.04/3.33 | 12.0 | ❌ |

| Stage (word end → …) | p50 / p95 / max (ms) | n |
|---|---|---|
| ASR: word end → partial delivered | 687 / 1858 / 4676 | 254 |
| Main-queue hop: partial → matcher start | 0 / 2 / 7 | 254 |
| Matcher | 0 / 0 / 1 | 254 |
| Render: matcher done → frame shows it | 13 / 17 / 26 | 254 |
| **End to end: word end → on screen** | 701 / 1868 / 4689 | 254 |

Word end times are interpolated inside synthesized phrases, so the ASR and end-to-end rows
carry roughly ±100 ms of ground-truth error; the hop, matcher and render rows don't.
All matcher calls: 0 / 0 / 1 over 532 partials.

| Resource | Value |
|---|---|
| Duration | 14.1 min |
| Memory start → end (peak) | 25.7 → 157.1 MB (207.8 MB) |
| Memory slope after 10 min | 4.8 MB/h |
| CPU average | 31.5 % |
| Recognition sessions | begin 9, localWindow 32 |

Leaks at the end: 194 leaks, 9648 bytes

Session: the `composite` case (104 s) read 8× in one session, jumping back to the top of the script at each loop (7 jumps). Pass: memory slope < 5 MB/h after 10 min, last loop tracks like the first, Apple restarts ≈ one per 55 s, 0 leaked bytes from app code.

Manual release checklist (not automated): sleep/wake mid-session; mic switch built-in → AirPods → built-in; unplug/replug the external display in fullscreen-on-external; default input changing while backgrounded.

## All metrics (median of runs, MAD)

| Metric | Median | MAD | Unit | Runs |
|---|---|---|---|---|
| soak.local-whisper-tiny-Q8_0.cpuPercent | 31.46 | 0 |  | 1 |
| soak.local-whisper-tiny-Q8_0.leakedBytes | 9648 | 0 | bytes | 1 |
| soak.local-whisper-tiny-Q8_0.lostPer10Min | 2.85 | 0 |  | 1 |
| soak.local-whisper-tiny-Q8_0.memSlopeMBPerHour | 4.81 | 0 |  | 1 |
| soak.local-whisper-tiny-Q8_0.peakMemoryMB | 208 | 0 |  | 1 |
| soak.local-whisper-tiny-Q8_0.restartTasks | 0 | 0 | count | 1 |

No baseline yet for this host. Commit one with -update-baseline once the numbers look right.
