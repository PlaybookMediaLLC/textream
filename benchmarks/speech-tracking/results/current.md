| Dimension | Case | Lost/10 min | Lost % time | Recovery p50/p95 (s) | Never recovered | Ahead >3w % time | Silence drift (w) | Lag p50/p95 (s) | Final err (w) | Pass |
|---|---|---|---|---|---|---|---|---|---|---|
| baseline | clean read, 150 wpm | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.39/0.80 | 0.0 | ✅ |
| baseline | recognizer drops transcript at most gaps | 0.00 | 0.0 | 2.0/3.4 | 0/90 | 0.3 | 0 | 0.39/0.75 | 0.0 | ✅ |
| repeated | refrains in script | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.41/0.76 | 0.0 | ✅ |
| repeated | restart sentence ×4 | 0.00 | 0.0 | 0.2/2.7 | 0/120 | 0.1 | 0 | 0.40/0.79 | 0.0 | ✅ |
| repeated | re-read previous 12 words ×3 | 0.00 | 0.0 | 2.3/3.6 | 0/90 | 0.1 | 0 | 0.39/0.77 | 0.1 | ✅ |
| repeated | refrains + restart sentence ×3 | 0.00 | 0.0 | 1.5/2.7 | 0/90 | 0.0 | 0 | 0.41/0.76 | 0.0 | ✅ |
| repeated | stutters (8%) | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.38/0.78 | 0.0 | ✅ |
| paraphrase | light: contractions + synonyms | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.42/1.33 | 0.0 | ✅ |
| paraphrase | fillers + disfluency (10%) | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.39/0.73 | 0.0 | ✅ |
| paraphrase | ad-lib 15 words ×3 | 0.00 | 0.0 | 0.1/0.2 | 0/90 | 0.0 | 0 | 0.40/0.81 | 0.0 | ✅ |
| paraphrase | ad-lib 45 words ×2 | 0.12 | 0.3 | 0.1/0.2 | 0/60 | 0.3 | 0 | 0.39/0.70 | 0.0 | ✅ |
| pauses | pause 2 s ×3 | 0.00 | 0.0 | 0.1/0.2 | 0/90 | 0.0 | 0 | 0.39/0.60 | 0.0 | ✅ |
| pauses | pause 5 s ×3 | 0.00 | 0.0 | 0.1/0.2 | 0/90 | 0.0 | 0 | 0.40/0.79 | 0.0 | ✅ |
| pauses | pause 15 s ×3 | 0.00 | 0.0 | 0.1/0.2 | 0/90 | 0.0 | 0 | 0.40/0.96 | 0.0 | ✅ |
| pauses | pause 30 s ×3 | 0.00 | 0.0 | 0.2/1.2 | 0/90 | 0.0 | 0 | 0.39/0.70 | 0.4 | ✅ |
| pauses | pause 60 s ×3 | 0.00 | 0.0 | 0.1/0.2 | 0/90 | 0.0 | 0 | 0.40/0.78 | 0.0 | ✅ |
| skips | skip 1 words forward ×3 | 0.00 | 0.0 | 0.1/0.2 | 0/90 | 0.0 | 0 | 0.40/0.84 | 0.0 | ✅ |
| skips | skip 3 words forward ×3 | 0.00 | 0.0 | 1.2/1.4 | 0/90 | 0.0 | 0 | 0.40/0.88 | 0.0 | ✅ |
| skips | skip 6 words forward ×3 | 0.00 | 0.0 | 1.5/3.1 | 0/90 | 0.0 | 0 | 0.40/0.82 | 0.0 | ✅ |
| skips | skip 10 words forward ×3 | 0.00 | 0.0 | 1.5/2.6 | 0/90 | 0.0 | 0 | 0.40/0.85 | 0.0 | ✅ |
| skips | skip 25 words forward ×3 | 0.20 | 0.1 | 2.2/2.6 | 0/90 | 0.0 | 0 | 0.40/0.72 | 0.0 | ✅ |
| skips | skip 60 words forward ×3 | 0.00 | 0.0 | 2.3/3.2 | 0/90 | 0.0 | 0 | 0.38/0.59 | 0.1 | ✅ |
| skips | jump back 30 words ×2 | 0.00 | 0.0 | 2.7/4.0 | 0/60 | 0.1 | 0 | 0.40/0.60 | 0.0 | ✅ |
| speed | 110 wpm | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.38/0.94 | 0.0 | ✅ |
| speed | 150 wpm | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.39/0.80 | 0.0 | ✅ |
| speed | 190 wpm | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.41/0.83 | 0.2 | ✅ |
| speed | 230 wpm | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.43/0.90 | 0.1 | ✅ |
| accent (proxy) | native-like, WER≈5% | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.40/0.86 | 0.0 | ✅ |
| accent (proxy) | moderate, WER≈12% | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.41/1.13 | 0.1 | ✅ |
| accent (proxy) | strong, WER≈22% | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.44/1.48 | 0.1 | ✅ |
| accent (proxy) | very strong, WER≈35% | 0.15 | 0.1 | –/– | – | 0.0 | 0 | 0.49/1.99 | 0.3 | ⚠️ report-only |
| noise (proxy) | stationary noise 20 dB | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.40/0.87 | 0.0 | ✅ |
| noise (proxy) | stationary noise 10 dB | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.42/1.27 | 0.2 | ✅ |
| noise (proxy) | stationary noise 5 dB | 0.15 | 0.1 | –/– | – | 0.0 | 0 | 0.45/1.67 | 0.4 | ⚠️ report-only |
| noise (proxy) | stationary noise 0 dB | 2.86 | 1.3 | –/– | – | 0.0 | 0 | 0.58/2.83 | 1.3 | ⚠️ report-only |
| noise (proxy) | competing speech (TV) 5% | 0.00 | 0.0 | –/– | – | 0.1 | 0 | 0.40/1.05 | 0.1 | ✅ |
| noise (proxy) | competing speech (TV) 12% | 0.15 | 0.1 | –/– | – | 0.1 | 0 | 0.40/1.26 | 0.4 | ✅ |
| technical | jargon mostly recognised (hints work) | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.37/0.81 | 0.0 | ✅ |
| technical | jargon half mis-heard | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.38/0.95 | 0.0 | ✅ |
| technical | jargon mis-heard (no hints) | 0.00 | 0.0 | –/– | – | 0.2 | 0 | 0.39/1.15 | 0.0 | ✅ |
| composite | realistic take | 0.00 | 0.0 | 0.2/1.7 | 0/120 | 0.0 | 0 | 0.41/1.01 | 0.1 | ✅ |

Layer A (simulated speakers + ASR). Matcher: current

37/37 gating cases pass the launch bar (PLAN.md §8); 4 report-only. Seeds per case: 30.

