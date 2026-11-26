| Dimension | Case | Lost/10 min | Lost % time | Recovery p50/p95 (s) | Never recovered | Ahead >3w % time | Silence drift (w) | Lag p50/p95 (s) | Final err (w) | Pass |
|---|---|---|---|---|---|---|---|---|---|---|
| baseline | clean read, 150 wpm | 4.52 | 71.3 | –/– | – | 0.4 | 0 | 0.42/0.71 | 141.4 | ❌ |
| baseline | recognizer drops transcript at most gaps | 16.78 | 82.4 | –/– | 90/90 | 0.3 | 0 | 0.40/0.66 | 214.3 | ❌ |
| repeated | refrains in script | 6.86 | 74.7 | –/– | – | 0.1 | 0 | 0.44/5.73 | 102.0 | ❌ |
| repeated | restart sentence ×4 | 15.70 | 61.3 | 7.5/10.6 | 67/120 | 5.6 | 0 | 0.38/1.01 | 125.0 | ❌ |
| repeated | re-read previous 12 words ×3 | 14.99 | 74.1 | 6.6/9.0 | 76/90 | 1.4 | 0 | 0.40/0.59 | 145.5 | ❌ |
| repeated | refrains + restart sentence ×3 | 17.53 | 64.9 | 1.5/2.2 | 60/90 | 0.1 | 0 | 0.43/0.72 | 92.7 | ❌ |
| repeated | stutters (8%) | 4.20 | 72.1 | –/– | – | 0.7 | 0 | 0.38/0.82 | 130.4 | ❌ |
| paraphrase | light: contractions + synonyms | 4.61 | 74.0 | –/– | – | 0.5 | 0 | 0.41/1.40 | 146.7 | ❌ |
| paraphrase | fillers + disfluency (10%) | 3.85 | 68.2 | –/– | – | 0.8 | 0 | 0.39/1.00 | 127.2 | ❌ |
| paraphrase | ad-lib 15 words ×3 | 12.50 | 68.2 | 7.9/12.7 | 60/90 | 6.0 | 0 | 0.39/2.00 | 125.0 | ❌ |
| paraphrase | ad-lib 45 words ×2 | 10.50 | 70.6 | 6.1/19.1 | 45/60 | 7.1 | 0 | 0.39/0.88 | 98.9 | ❌ |
| pauses | pause 2 s ×3 | 13.41 | 68.6 | 0.1/0.2 | 66/90 | 0.4 | 0 | 0.41/0.70 | 152.9 | ❌ |
| pauses | pause 5 s ×3 | 12.46 | 69.0 | 0.1/0.2 | 65/90 | 0.3 | 0 | 0.42/1.20 | 151.6 | ❌ |
| pauses | pause 15 s ×3 | 10.47 | 69.4 | 0.1/0.2 | 66/90 | 0.3 | 0 | 0.42/1.16 | 138.5 | ❌ |
| pauses | pause 30 s ×3 | 8.17 | 66.1 | 0.2/0.9 | 61/90 | 0.2 | 0 | 0.43/4.45 | 123.3 | ❌ |
| pauses | pause 60 s ×3 | 5.82 | 66.3 | 0.2/0.9 | 61/90 | 0.2 | 0 | 0.42/1.93 | 126.4 | ❌ |
| skips | skip 1 words forward ×3 | 13.57 | 68.7 | 0.1/0.5 | 70/90 | 0.4 | 0 | 0.41/0.92 | 146.9 | ❌ |
| skips | skip 3 words forward ×3 | 14.26 | 70.9 | 0.8/0.9 | 76/90 | 0.4 | 0 | 0.41/0.66 | 160.6 | ❌ |
| skips | skip 6 words forward ×3 | 14.27 | 69.0 | 1.1/1.2 | 73/90 | 0.4 | 0 | 0.40/0.78 | 160.5 | ❌ |
| skips | skip 10 words forward ×3 | 16.12 | 77.1 | –/– | 90/90 | 0.3 | 0 | 0.42/0.60 | 168.9 | ❌ |
| skips | skip 25 words forward ×3 | 19.15 | 72.4 | –/– | 90/90 | 0.4 | 0 | 0.41/0.60 | 186.4 | ❌ |
| skips | skip 60 words forward ×3 | 33.30 | 48.1 | –/– | 90/90 | 0.8 | 0 | 0.42/0.59 | 234.5 | ❌ |
| skips | jump back 30 words ×2 | 11.44 | 68.3 | 13.5/19.0 | 43/60 | 3.5 | 0 | 0.40/0.68 | 117.3 | ❌ |
| speed | 110 wpm | 3.46 | 70.6 | –/– | – | 0.7 | 0 | 0.40/0.99 | 135.7 | ❌ |
| speed | 150 wpm | 4.52 | 71.3 | –/– | – | 0.4 | 0 | 0.42/0.71 | 141.4 | ❌ |
| speed | 190 wpm | 5.50 | 75.3 | –/– | – | 0.4 | 0 | 0.42/0.78 | 160.8 | ❌ |
| speed | 230 wpm | 6.40 | 80.3 | –/– | – | 0.4 | 0 | 0.43/0.79 | 186.2 | ❌ |
| accent (proxy) | native-like, WER≈5% | 2.11 | 19.1 | –/– | – | 0.8 | 0 | 0.40/0.89 | 31.4 | ❌ |
| accent (proxy) | moderate, WER≈12% | 2.11 | 25.6 | –/– | – | 1.0 | 0 | 0.40/1.05 | 40.9 | ❌ |
| accent (proxy) | strong, WER≈22% | 2.26 | 30.8 | –/– | – | 1.2 | 0 | 0.41/1.28 | 49.3 | ❌ |
| accent (proxy) | very strong, WER≈35% | 4.22 | 54.9 | –/– | – | 0.8 | 0 | 0.44/1.63 | 96.9 | ⚠️ report-only |
| noise (proxy) | stationary noise 20 dB | 1.36 | 13.8 | –/– | – | 1.0 | 0 | 0.40/0.85 | 21.7 | ❌ |
| noise (proxy) | stationary noise 10 dB | 1.81 | 23.7 | –/– | – | 1.1 | 0 | 0.40/1.15 | 38.3 | ❌ |
| noise (proxy) | stationary noise 5 dB | 2.26 | 27.1 | –/– | – | 1.4 | 0 | 0.41/1.30 | 45.7 | ⚠️ report-only |
| noise (proxy) | stationary noise 0 dB | 3.92 | 47.0 | –/– | – | 1.5 | 0 | 0.44/1.76 | 85.8 | ⚠️ report-only |
| noise (proxy) | competing speech (TV) 5% | 1.96 | 5.2 | –/– | – | 8.3 | 0 | 0.37/0.85 | 4.5 | ❌ |
| noise (proxy) | competing speech (TV) 12% | 9.80 | 36.7 | –/– | – | 54.3 | 0 | 0.17/0.58 | 0.7 | ⚠️ report-only |
| technical | jargon mostly recognised (hints work) | 5.46 | 51.2 | –/– | – | 0.2 | 0 | 0.41/0.85 | 66.5 | ❌ |
| technical | jargon half mis-heard | 6.64 | 59.4 | –/– | – | 0.2 | 0 | 0.41/0.91 | 78.2 | ❌ |
| technical | jargon mis-heard (no hints) | 4.75 | 43.5 | –/– | – | 0.2 | 0 | 0.39/0.97 | 57.4 | ❌ |
| composite | realistic take | 9.27 | 35.4 | 0.2/4.6 | 58/120 | 2.2 | 0 | 0.40/0.94 | 67.5 | ❌ |

Layer A (simulated speakers + ASR). Matcher: legacy (git f9c6c94)

0/37 gating cases pass the launch bar (PLAN.md §8); 4 report-only. Seeds per case: 30.

