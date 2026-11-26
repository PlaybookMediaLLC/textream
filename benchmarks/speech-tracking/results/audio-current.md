| Dimension | Case | Lost/10 min | Lost % time | Recovery p50/p95 (s) | Never recovered | Ahead >3w % time | Silence drift (w) | Lag p50/p95 (s) | Final err (w) | Pass |
|---|---|---|---|---|---|---|---|---|---|---|
| accent | UK English (Daniel) [Daniel] · `apple-on-device` | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.47/0.79 | 0.0 | ✅ |
| accent | Indian English (Rishi) [Rishi] · `apple-on-device` | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.48/0.82 | 0.0 | ✅ |
| baseline | clean read, US voice [Samantha] · `apple-on-device` | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.43/0.78 | 0.0 | ✅ |
| baseline | clean read, US voice [Samantha] · `local-whisper-tiny-q8-0` | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.82/1.64 | 0.0 | ⚠️ report-only |

Layer B (synthetic voices → real recognizers, real audio, one take per case and engine). Matcher: current

3/3 gating cases pass the launch bar (PLAN.md §8); 1 report-only.

