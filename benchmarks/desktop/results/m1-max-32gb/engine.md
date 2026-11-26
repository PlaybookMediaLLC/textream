# engine — local model performance (PLAN #3)

Host `m1-max-32gb`, commit `f9c6c94`, 2026-11-26T01:22:08-05:00.

| Model | Backend | Load (s) | Reload (s) | First partial (s) | Partial interval p95 (s) | Decode @26 s p50 (s) | Stream RTF p95 | Peak MB | Thermal ratio | Recommended |
|---|---|---|---|---|---|---|---|---|---|---|
| whisper-tiny-Q8_0 | MTL0 | 0.115 | 0.0395 | 1.50 | 1.65 | 0.22 | – | 153 | – | ✅ (thermals not run) |
| moonshine-streaming-tiny-Q8_0 | MTL0 | 0.0933 | 0.0359 | 0.735 | 4.12 | – | 9.54 | 509 | – | — |

Audio: the `baseline-us` case. The app's rolling window re-decodes up to 26 s of audio every 1.5 s, so **recommended** = 26-s decode p50 under 1.0 s (≈33% headroom) — or, for streaming models, chunk RTF p95 under 0.7 — and a thermal ratio (minutes 25–30 vs 0–5 of sustained load) under 1.3. `recommended-models.json` holds the verdicts for this host class.

## All metrics (median of runs, MAD)

| Metric | Median | MAD | Unit | Runs |
|---|---|---|---|---|
| engine.moonshine-streaming-tiny-Q8_0.firstPartialSeconds | 0.735 | 0 | s | 1 |
| engine.moonshine-streaming-tiny-Q8_0.loadSeconds | 0.0933 | 0 | s | 1 |
| engine.moonshine-streaming-tiny-Q8_0.partialIntervalP95 | 4.12 | 0 | s | 1 |
| engine.moonshine-streaming-tiny-Q8_0.peakMemoryMB | 509 | 0 | MB | 1 |
| engine.moonshine-streaming-tiny-Q8_0.reloadSeconds | 0.0359 | 0 | s | 1 |
| engine.moonshine-streaming-tiny-Q8_0.streamAudioSecondsIn2Min | 61.40 | 0 | s | 1 |
| engine.moonshine-streaming-tiny-Q8_0.streamRtfP95 | 9.54 | 0 | x | 1 |
| engine.whisper-tiny-Q8_0.decodeAt26sP50 | 0.22 | 0 | s | 1 |
| engine.whisper-tiny-Q8_0.firstPartialSeconds | 1.50 | 0 | s | 1 |
| engine.whisper-tiny-Q8_0.loadSeconds | 0.115 | 0 | s | 1 |
| engine.whisper-tiny-Q8_0.partialIntervalP95 | 1.65 | 0 | s | 1 |
| engine.whisper-tiny-Q8_0.peakMemoryMB | 153 | 0 | MB | 1 |
| engine.whisper-tiny-Q8_0.reloadSeconds | 0.0395 | 0 | s | 1 |

No baseline yet for this host. Commit one with -update-baseline once the numbers look right.
