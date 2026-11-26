# engine — local model performance (PLAN #3)

Host `m1-max-32gb`, commit `8cee918`, 2026-11-26T04:57:48-05:00.

| Model | Backend | Load (s) | Reload (s) | First partial (s) | Partial interval p95 (s) | Decode @26 s p50 (s) | Stream RTF p95 | Peak MB | Thermal ratio | Recommended |
|---|---|---|---|---|---|---|---|---|---|---|
| whisper-tiny-Q8_0 | MTL0 | 0.119 | 0.0496 | 1.48 | 1.56 | 0.268 | – | 152 | – | ✅ (thermals not run) |
| moonshine-streaming-tiny-Q8_0 | MTL0 | 0.156 | 0.0358 | 0.737 | 4.73 | – | 9.57 | 546 | – | — |

Audio: the `baseline-us` case. The app's rolling window re-decodes up to 26 s of audio every 1.5 s, so **recommended** = 26-s decode p50 under 1.0 s (≈33% headroom) — or, for streaming models, chunk RTF p95 under 0.7 — and a thermal ratio (minutes 25–30 vs 0–5 of sustained load) under 1.3. `recommended-models.json` holds the verdicts for this host class.

## All metrics (median of runs, MAD)

| Metric | Median | MAD | Unit | Runs |
|---|---|---|---|---|
| engine.moonshine-streaming-tiny-Q8_0.firstPartialSeconds | 0.737 | 0.00934 | s | 3 |
| engine.moonshine-streaming-tiny-Q8_0.loadSeconds | 0.156 | 0.0621 | s | 3 |
| engine.moonshine-streaming-tiny-Q8_0.partialIntervalP95 | 4.73 | 0.178 | s | 3 |
| engine.moonshine-streaming-tiny-Q8_0.peakMemoryMB | 546 | 0.172 | MB | 3 |
| engine.moonshine-streaming-tiny-Q8_0.reloadSeconds | 0.0358 | 0.000435 | s | 3 |
| engine.moonshine-streaming-tiny-Q8_0.streamAudioSecondsIn2Min | 61.10 | 0 | s | 3 |
| engine.moonshine-streaming-tiny-Q8_0.streamRtfP95 | 9.57 | 0.166 | x | 3 |
| engine.whisper-tiny-Q8_0.decodeAt26sP50 | 0.268 | 0.0447 | s | 3 |
| engine.whisper-tiny-Q8_0.firstPartialSeconds | 1.48 | 0.00474 | s | 3 |
| engine.whisper-tiny-Q8_0.loadSeconds | 0.119 | 0.0139 | s | 3 |
| engine.whisper-tiny-Q8_0.partialIntervalP95 | 1.56 | 0.00219 | s | 3 |
| engine.whisper-tiny-Q8_0.peakMemoryMB | 152 | 0.781 | MB | 3 |
| engine.whisper-tiny-Q8_0.reloadSeconds | 0.0496 | 0.0012 | s | 3 |

No baseline yet for this host. Commit one with -update-baseline once the numbers look right.
