# soak — long session (PLAN #6)

Host `m1-max-32gb`, commit `8cee918`, 2026-11-26T05:14:14-05:00.

## Engine `local-whisper-tiny-Q8_0`

### realistic take, UK voice, babble 15 dB [Daniel] × 18 loops

Source: frames the overlay showed

| Dimension | Case | Lost/10 min | Lost % time | Recovery p50/p95 (s) | Never recovered | Ahead >3w % time | Silence drift (w) | Lag p50/p95 (s) | Final err (w) | Pass |
|---|---|---|---|---|---|---|---|---|---|---|
| composite | realistic take, UK voice, babble 15 dB | 2.53 | 3.3 | 1.8/2.9 | 0/89 | 0.8 | 0 | 0.82/2.02 | 0.0 | ❌ |

First vs last loop:

| Dimension | Case | Lost/10 min | Lost % time | Recovery p50/p95 (s) | Never recovered | Ahead >3w % time | Silence drift (w) | Lag p50/p95 (s) | Final err (w) | Pass |
|---|---|---|---|---|---|---|---|---|---|---|
| soak | loop 1 of 18 | 0.00 | 0.0 | 0.2/1.0 | 0/4 | 0.5 | 0 | 0.82/2.02 | 0.0 | ❌ |
| soak | loop 18 of 18 | 5.75 | 15.6 | 0.8/1.5 | 0/4 | 0.5 | 0 | 0.95/6.10 | 12.0 | ❌ |

| Stage (word end → …) | p50 / p95 / max (ms) | n |
|---|---|---|
| ASR: word end → partial delivered | 696 / 1926 / 4673 | 254 |
| Main-queue hop: partial → matcher start | 0 / 5 / 8 | 254 |
| Matcher | 0 / 1 / 1 | 254 |
| Render: matcher done → frame shows it | 13 / 18 / 20 | 254 |
| **End to end: word end → on screen** | 709 / 1941 / 4685 | 254 |

Word end times are interpolated inside synthesized phrases, so the ASR and end-to-end rows
carry roughly ±100 ms of ground-truth error; the hop, matcher and render rows don't.
All matcher calls: 0 / 0 / 1 over 1198 partials.

| Resource | Value |
|---|---|
| Duration | 31.7 min |
| Memory start → end (peak) | 25.2 → 167.1 MB (218.3 MB) |
| Memory slope after 10 min | 23.0 MB/h |
| CPU average | 34.5 % |
| Recognition sessions | begin 19, localWindow 72 |

Leaks at the end: 194 leaks, 9648 bytes

Session: the `composite` case (104 s) read 18× in one session, jumping back to the top of the script at each loop (17 jumps). Pass: memory slope < 5 MB/h after 10 min, last loop tracks like the first, Apple restarts ≈ one per 55 s, 0 leaked bytes from app code.

Manual release checklist (not automated): sleep/wake mid-session; mic switch built-in → AirPods → built-in; unplug/replug the external display in fullscreen-on-external; default input changing while backgrounded.

## All metrics (median of runs, MAD)

| Metric | Median | MAD | Unit | Runs |
|---|---|---|---|---|
| soak.local-whisper-tiny-Q8_0.cpuPercent | 34.50 | 0 |  | 1 |
| soak.local-whisper-tiny-Q8_0.leakedBytes | 9648 | 0 | bytes | 1 |
| soak.local-whisper-tiny-Q8_0.lostPer10Min | 2.53 | 0 |  | 1 |
| soak.local-whisper-tiny-Q8_0.memSlopeMBPerHour | 23.00 | 0 |  | 1 |
| soak.local-whisper-tiny-Q8_0.peakMemoryMB | 218 | 0 |  | 1 |
| soak.local-whisper-tiny-Q8_0.restartTasks | 0 | 0 | count | 1 |

No baseline yet for this host. Commit one with -update-baseline once the numbers look right.
