| Dimension | Case | Lost/10 min | Lost % time | Recovery p50/p95 (s) | Never recovered | Ahead >3w % time | Silence drift (w) | Lag p50/p95 (s) | Final err (w) | Pass |
|---|---|---|---|---|---|---|---|---|---|---|
| baseline | clean read, 150 wpm | 4.52 | 71.8 | –/– | – | 0.4 | 0 | 0.42/0.72 | 146.0 | ❌ |
| baseline | recognizer drops transcript at most gaps | 16.78 | 82.4 | –/– | 90/90 | 0.3 | 0 | 0.40/0.66 | 215.0 | ❌ |
| repeated | refrains in script | 6.86 | 74.7 | –/– | – | 0.1 | 0 | 0.44/1.25 | 103.9 | ❌ |
| repeated | restart sentence ×4 | 15.84 | 61.6 | 7.5/10.6 | 67/120 | 5.6 | 0 | 0.38/0.79 | 124.9 | ❌ |
| repeated | re-read previous 12 words ×3 | 14.99 | 74.1 | 6.6/9.0 | 76/90 | 1.4 | 0 | 0.41/0.61 | 147.2 | ❌ |
| repeated | refrains + restart sentence ×3 | 17.53 | 65.2 | 1.5/2.2 | 60/90 | 0.1 | 0 | 0.43/0.73 | 94.0 | ❌ |
| repeated | stutters (8%) | 4.20 | 73.9 | –/– | – | 0.7 | 0 | 0.38/0.59 | 138.6 | ❌ |
| paraphrase | light: contractions + synonyms | 4.61 | 74.2 | –/– | – | 0.5 | 0 | 0.41/1.58 | 149.9 | ❌ |
| paraphrase | fillers + disfluency (10%) | 3.85 | 65.6 | –/– | – | 0.9 | 0 | 0.38/0.82 | 128.4 | ❌ |
| paraphrase | ad-lib 15 words ×3 | 12.37 | 68.1 | 7.9/12.7 | 60/90 | 5.9 | 0 | 0.39/1.04 | 131.8 | ❌ |
| paraphrase | ad-lib 45 words ×2 | 10.62 | 70.2 | 11.9/19.6 | 45/60 | 7.4 | 0 | 0.38/0.74 | 112.6 | ❌ |
| pauses | pause 2 s ×3 | 13.41 | 69.6 | 0.1/0.2 | 66/90 | 0.4 | 0 | 0.42/0.62 | 151.8 | ❌ |
| pauses | pause 5 s ×3 | 12.59 | 69.6 | 0.1/0.2 | 66/90 | 0.3 | 0 | 0.42/0.78 | 150.1 | ❌ |
| pauses | pause 15 s ×3 | 10.47 | 69.7 | 0.1/0.2 | 66/90 | 0.3 | 0 | 0.42/1.99 | 147.1 | ❌ |
| pauses | pause 30 s ×3 | 8.26 | 68.0 | 0.1/0.2 | 65/90 | 0.2 | 0 | 0.41/1.14 | 135.3 | ❌ |
| pauses | pause 60 s ×3 | 5.82 | 66.6 | 0.2/0.9 | 61/90 | 0.2 | 0 | 0.43/2.17 | 121.8 | ❌ |
| skips | skip 1 words forward ×3 | 13.72 | 69.7 | 0.1/0.5 | 70/90 | 0.4 | 0 | 0.41/1.00 | 153.0 | ❌ |
| skips | skip 3 words forward ×3 | 14.57 | 72.1 | 0.8/0.9 | 77/90 | 0.4 | 0 | 0.42/0.65 | 163.1 | ❌ |
| skips | skip 6 words forward ×3 | 14.43 | 69.3 | 1.1/1.2 | 73/90 | 0.4 | 0 | 0.40/0.72 | 163.6 | ❌ |
| skips | skip 10 words forward ×3 | 16.12 | 77.1 | –/– | 90/90 | 0.3 | 0 | 0.42/0.60 | 181.0 | ❌ |
| skips | skip 25 words forward ×3 | 19.15 | 72.4 | –/– | 90/90 | 0.4 | 0 | 0.41/0.60 | 188.7 | ❌ |
| skips | skip 60 words forward ×3 | 33.30 | 48.1 | –/– | 90/90 | 0.8 | 0 | 0.42/0.59 | 234.5 | ❌ |
| skips | jump back 30 words ×2 | 11.07 | 68.3 | 17.4/21.9 | 45/60 | 4.0 | 0 | 0.40/0.64 | 126.1 | ❌ |
| speed | 110 wpm | 3.34 | 68.5 | –/– | – | 0.7 | 0 | 0.40/1.13 | 134.3 | ❌ |
| speed | 150 wpm | 4.52 | 71.8 | –/– | – | 0.4 | 0 | 0.42/0.72 | 146.0 | ❌ |
| speed | 190 wpm | 5.32 | 74.4 | –/– | – | 0.4 | 0 | 0.42/0.75 | 172.4 | ❌ |
| speed | 230 wpm | 6.40 | 80.3 | –/– | – | 0.4 | 0 | 0.43/0.79 | 188.0 | ❌ |
| accent (proxy) | native-like, WER≈5% | 0.60 | 6.3 | –/– | – | 0.9 | 0 | 0.40/0.87 | 9.6 | ❌ |
| accent (proxy) | moderate, WER≈12% | 1.21 | 17.3 | –/– | – | 1.0 | 0 | 0.40/1.08 | 26.7 | ❌ |
| accent (proxy) | strong, WER≈22% | 1.81 | 26.2 | –/– | – | 1.3 | 0 | 0.41/1.21 | 42.9 | ❌ |
| accent (proxy) | very strong, WER≈35% | 3.77 | 50.1 | –/– | – | 0.9 | 0 | 0.44/1.47 | 88.8 | ⚠️ report-only |
| noise (proxy) | stationary noise 20 dB | 0.75 | 10.5 | –/– | – | 1.0 | 0 | 0.40/1.04 | 14.6 | ❌ |
| noise (proxy) | stationary noise 10 dB | 1.51 | 20.2 | –/– | – | 1.2 | 0 | 0.40/1.17 | 32.5 | ❌ |
| noise (proxy) | stationary noise 5 dB | 2.26 | 24.9 | –/– | – | 1.4 | 0 | 0.41/1.32 | 43.6 | ⚠️ report-only |
| noise (proxy) | stationary noise 0 dB | 3.77 | 46.6 | –/– | – | 1.6 | 0 | 0.44/1.75 | 87.3 | ⚠️ report-only |
| noise (proxy) | competing speech (TV) 5% | 1.96 | 6.3 | –/– | – | 9.0 | 0 | 0.37/0.96 | 7.2 | ❌ |
| noise (proxy) | competing speech (TV) 12% | 9.50 | 34.3 | –/– | – | 52.9 | 0 | 0.17/0.57 | 0.7 | ⚠️ report-only |
| technical | jargon mostly recognised (hints work) | 5.22 | 51.0 | –/– | – | 0.2 | 0 | 0.41/0.74 | 69.4 | ❌ |
| technical | jargon half mis-heard | 6.64 | 59.0 | –/– | – | 0.2 | 0 | 0.40/0.84 | 80.3 | ❌ |
| technical | jargon mis-heard (no hints) | 4.98 | 46.4 | –/– | – | 0.3 | 0 | 0.39/0.97 | 62.9 | ❌ |
| composite | realistic take | 9.42 | 35.7 | 0.9/4.2 | 58/120 | 1.7 | 0 | 0.41/1.05 | 65.8 | ❌ |

Layer A (simulated speakers + ASR). Matcher: legacy (git f9c6c94)

0/37 gating cases pass the launch bar (PLAN.md §8); 4 report-only. Seeds per case: 30.

