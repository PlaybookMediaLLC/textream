| Dimension | Case | Lost/10 min | Lost % time | Recovery p50/p95 (s) | Never recovered | Ahead >3w % time | Silence drift (w) | Lag p50/p95 (s) | Final err (w) | Pass |
|---|---|---|---|---|---|---|---|---|---|---|
| apple-on-device · accent | Australian English (Karen) [Karen, WER 4%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.44/0.75 | 0.0 | ✅ |
| apple-on-device · accent | UK English (Daniel) [Daniel, WER 4%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.47/0.75 | 0.0 | ✅ |
| apple-on-device · accent | Irish English (Moira) [Moira, WER 6%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.44/0.73 | 0.0 | ✅ |
| apple-on-device · accent | Indian English (Rishi) [Rishi, WER 3%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.48/0.87 | 0.0 | ✅ |
| apple-on-device · accent | Indian English (Tara) [Tara, WER 3%, ASR lag 0.1 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.43/0.69 | 0.0 | ✅ |
| apple-on-device · accent (non-native proxy) | French voice reading English [Thomas, WER 50%, ASR lag 7.1 s] | 5.76 | 88.8 | –/– | – | 0.0 | 0 | 0.66/8.90 | 170.0 | ⚠️ report-only |
| apple-on-device · accent (non-native proxy) | German voice reading English [Anna, WER 27%, ASR lag 6.7 s] | 0.00 | 0.0 | –/– | – | 0.2 | 0 | 0.54/1.35 | 0.0 | ✅ |
| apple-on-device · accent (non-native proxy) | Mandarin voice reading English [Tingting, WER 11%, ASR lag -0.1 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.50/1.07 | 0.0 | ✅ |
| apple-on-device · accent (non-native proxy) | Spanish voice reading English [Mónica, WER 4%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.43/0.74 | 0.0 | ✅ |
| apple-on-device · accent | South African English (Tessa) [Tessa, WER 53%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.48/0.80 | 0.0 | ✅ |
| apple-on-device · baseline | clean read, US voice [Samantha, WER 4%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.43/0.76 | 0.0 | ✅ |
| apple-on-device · composite | realistic take, UK voice, babble 15 dB [Daniel, WER 11%, ASR lag 0.9 s] | 17.25 | 47.4 | 0.8/0.8 | 2/4 | 0.5 | 0 | 0.55/8.66 | 110.0 | ❌ |
| apple-on-device · noise | 4-talker babble, 10 dB [Samantha, WER 7%, ASR lag 1.0 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.47/1.02 | 0.0 | ✅ |
| apple-on-device · noise | 4-talker babble, 5 dB [Samantha, WER 18%, ASR lag 0.6 s] | 6.66 | 50.5 | –/– | – | 0.0 | 0 | 0.61/1.77 | 105.0 | ⚠️ report-only |
| apple-on-device · noise | HVAC rumble, 5 dB [Samantha, WER 4%, ASR lag 0.3 s] | 6.66 | 50.5 | –/– | – | 0.0 | 0 | 0.43/0.70 | 98.0 | ❌ |
| apple-on-device · noise | competing talker (TV), 10 dB [Samantha, WER 6%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.48/0.80 | 0.0 | ✅ |
| apple-on-device · noise | competing talker (TV), 5 dB [Samantha, WER 6%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.48/0.81 | 0.0 | ✅ |
| apple-on-device · paraphrase | ad-lib 15 and 40 words [Samantha, WER 3%, ASR lag 0.5 s] | 11.40 | 5.2 | 6.7/6.7 | 0/2 | 17.6 | 0 | 0.40/0.75 | 0.0 | ❌ |
| apple-on-device · paraphrase | contractions, synonyms, fillers [Karen, WER 8%, ASR lag -0.7 s] | 6.40 | 40.3 | –/– | – | 0.0 | 0 | 0.50/6.17 | 58.0 | ❌ |
| apple-on-device · pauses | pauses 5 s, 20 s, 60 s [Samantha, WER 4%, ASR lag 16.6 s] | 10.25 | 84.9 | 0.1/0.1 | 2/3 | 0.0 | 0 | 0.41/0.66 | 164.0 | ❌ |
| apple-on-device · repeated | refrains + restart sentence ×3 [Daniel, WER 3%, ASR lag 0.5 s] | 0.00 | 0.0 | 1.0/1.0 | 0/3 | 0.0 | 0 | 0.44/0.71 | 0.0 | ✅ |
| apple-on-device · repeated | re-read 12 words ×2, jump back 30 [Samantha, WER 5%, ASR lag 0.3 s] | 5.48 | 14.4 | 10.9/10.9 | 0/3 | 25.6 | 0 | 0.35/0.70 | 0.0 | ❌ |
| apple-on-device · skips | skip 10, 25, 60 words [Rishi, WER 3%, ASR lag 0.3 s] | 26.49 | 61.8 | –/– | 3/3 | 0.0 | 0 | 0.52/8.97 | 157.0 | ❌ |
| apple-on-device · speed | 130 wpm [Samantha, WER 3%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.46/0.77 | 0.0 | ✅ |
| apple-on-device · speed | 230 wpm [Samantha, WER 4%, ASR lag 0.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.47/0.72 | 0.0 | ✅ |
| apple-on-device · technical | jargon, app's contextual hints on [Samantha, WER 19%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.45/0.89 | 0.0 | ✅ |
| apple-on-device · technical | jargon, no hints [Samantha, WER 22%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.45/1.03 | 0.0 | ✅ |
| local-canary · accent | UK English (Daniel) [Daniel, rolling window: WER n/a] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.45/1.17 | 0.0 | ✅ |
| local-canary · accent | Indian English (Rishi) [Rishi, rolling window: WER n/a] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.56/1.56 | 0.0 | ❌ |
| local-canary · baseline | clean read, US voice [Samantha, rolling window: WER n/a] | 0.00 | 0.0 | –/– | – | 1.9 | 0 | 0.48/1.26 | 0.0 | ❌ |
| local-canary · composite | realistic take, UK voice, babble 15 dB [Daniel, rolling window: WER n/a] | 17.25 | 44.1 | 0.8/0.8 | 2/4 | 0.0 | 0 | 0.54/7.63 | 68.0 | ❌ |
| local-canary · noise | 4-talker babble, 10 dB [Samantha, rolling window: WER n/a] | 19.97 | 31.1 | –/– | – | 0.0 | 0 | 1.01/8.30 | 0.0 | ⚠️ report-only |
| local-canary · noise | competing talker (TV), 10 dB [Samantha, rolling window: WER n/a] | 6.66 | 3.6 | –/– | – | 4.7 | 0 | 0.53/1.76 | 0.0 | ❌ |
| local-canary · paraphrase | ad-lib 15 and 40 words [Samantha, rolling window: WER n/a] | 22.79 | 16.6 | 8.8/8.8 | 0/2 | 32.0 | 0 | 0.25/0.91 | 0.0 | ❌ |
| local-canary · pauses | pauses 5 s, 20 s, 60 s [Samantha, rolling window: WER n/a] | 0.00 | 0.0 | 0.1/0.1 | 0/3 | 0.0 | 0 | 0.46/1.14 | 0.0 | ✅ |
| local-canary · repeated | re-read 12 words ×2, jump back 30 [Samantha, rolling window: WER n/a] | 10.96 | 21.5 | 13.8/13.8 | 0/3 | 28.5 | 0 | 0.24/1.03 | 0.0 | ❌ |
| local-canary · skips | skip 10, 25, 60 words [Rishi, rolling window: WER n/a] | 26.49 | 61.8 | –/– | 3/3 | 0.0 | 0 | 0.47/8.40 | 157.0 | ❌ |
| local-canary · technical | jargon, app's contextual hints on [Samantha, rolling window: WER n/a] | 0.00 | 0.0 | –/– | – | 5.3 | 0 | 0.44/1.92 | 0.0 | ❌ |
| local-nemotron · accent | UK English (Daniel) [Daniel, WER 1%, ASR lag 0.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.37/0.78 | 0.0 | ✅ |
| local-nemotron · accent | Indian English (Rishi) [Rishi, WER 0%, ASR lag 0.2 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.43/0.87 | 0.0 | ✅ |
| local-nemotron · baseline | clean read, US voice [Samantha, WER 0%, ASR lag 0.1 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.36/0.73 | 0.0 | ✅ |
| local-nemotron · composite | realistic take, UK voice, babble 15 dB [Daniel, WER 3%, ASR lag 0.6 s] | 11.50 | 34.7 | 0.2/0.2 | 2/4 | 0.0 | 0 | 0.40/0.85 | 89.0 | ❌ |
| local-nemotron · noise | 4-talker babble, 10 dB [Samantha, WER 3%, ASR lag 0.0 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.43/0.84 | 0.0 | ✅ |
| local-nemotron · noise | competing talker (TV), 10 dB [Samantha, WER 2%, ASR lag 0.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.40/0.79 | 0.0 | ✅ |
| local-nemotron · paraphrase | ad-lib 15 and 40 words [Samantha, WER 0%, ASR lag 0.1 s] | 17.09 | 15.2 | 9.3/9.3 | 0/2 | 28.7 | 0 | 0.29/0.76 | 0.0 | ❌ |
| local-nemotron · pauses | pauses 5 s, 20 s, 60 s [Samantha, WER 1%, ASR lag 0.1 s] | 0.00 | 0.0 | 0.1/0.1 | 0/3 | 0.0 | 0 | 0.39/0.83 | 0.0 | ✅ |
| local-nemotron · repeated | re-read 12 words ×2, jump back 30 [Samantha, WER 0%, ASR lag 0.1 s] | 5.48 | 13.0 | 5.9/5.9 | 0/3 | 19.4 | 0 | 0.29/0.78 | 0.0 | ❌ |
| local-nemotron · skips | skip 10, 25, 60 words [Rishi, WER 1%, ASR lag 0.2 s] | 26.49 | 61.8 | –/– | 3/3 | 0.0 | 0 | 0.43/8.90 | 157.0 | ❌ |
| local-nemotron · technical | jargon, app's contextual hints on [Samantha, WER 15%, ASR lag 0.7 s] | 0.00 | 0.0 | –/– | – | 2.5 | 0 | 0.29/1.07 | 0.0 | ❌ |

Layer B (synthetic voices → real recognizers, real audio, one take per case per engine). Matcher: legacy (git f9c6c94)

22/42 gating cases pass the launch bar (PLAN.md §8); 7 report-only.

