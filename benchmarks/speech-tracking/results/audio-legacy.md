| Dimension | Case | Lost/10 min | Lost % time | Recovery p50/p95 (s) | Never recovered | Ahead >3w % time | Silence drift (w) | Lag p50/p95 (s) | Final err (w) | Pass |
|---|---|---|---|---|---|---|---|---|---|---|
| accent | UK English (Daniel) [Daniel] · `apple-on-device` | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.47/0.75 | 0.0 | ✅ |
| accent | Indian English (Rishi) [Rishi] · `apple-on-device` | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.48/0.87 | 0.0 | ✅ |
| baseline | clean read, US voice [Samantha] · `apple-on-device` | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.43/0.76 | 0.0 | ✅ |
| baseline | clean read, US voice [Samantha] · `local-whisper-tiny-q8-0` | 0.00 | 0.0 | –/– | – | 16.6 | 0 | 0.43/1.59 | 0.0 | ⚠️ report-only |

Layer B (synthetic voices → real recognizers, real audio, one take per case and engine). Matcher: legacy (git f9c6c94)

3/3 gating cases pass the launch bar (PLAN.md §8); 1 report-only.

