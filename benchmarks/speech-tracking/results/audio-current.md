| Dimension | Case | Lost/10 min | Lost % time | Recovery p50/p95 (s) | Never recovered | Ahead >3w % time | Silence drift (w) | Lag p50/p95 (s) | Final err (w) | Pass |
|---|---|---|---|---|---|---|---|---|---|---|
| apple-on-device · accent | Australian English (Karen) [Karen, WER 4%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.44/0.74 | 0.0 | ✅ |
| apple-on-device · accent | UK English (Daniel) [Daniel, WER 4%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.47/0.79 | 0.0 | ✅ |
| apple-on-device · accent | Irish English (Moira) [Moira, WER 6%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.44/0.79 | 0.0 | ✅ |
| apple-on-device · accent | Indian English (Rishi) [Rishi, WER 3%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.48/0.82 | 0.0 | ✅ |
| apple-on-device · accent | Indian English (Tara) [Tara, WER 3%, ASR lag 0.1 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.43/0.72 | 0.0 | ✅ |
| apple-on-device · accent (non-native proxy) | French voice reading English [Thomas, WER 50%, ASR lag 7.1 s] | 17.27 | 14.4 | –/– | – | 0.5 | 0 | 1.21/5.29 | 0.0 | ⚠️ report-only |
| apple-on-device · accent (non-native proxy) | German voice reading English [Anna, WER 27%, ASR lag 6.7 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.58/1.72 | 0.0 | ⚠️ report-only |
| apple-on-device · accent (non-native proxy) | Mandarin voice reading English [Tingting, WER 11%, ASR lag -0.1 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.51/1.16 | 0.0 | ✅ |
| apple-on-device · accent (non-native proxy) | Spanish voice reading English [Mónica, WER 4%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.43/0.77 | 0.0 | ✅ |
| apple-on-device · accent | South African English (Tessa) [Tessa, WER 53%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.48/0.83 | 0.0 | ✅ |
| apple-on-device · baseline | clean read, US voice [Samantha, WER 4%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.43/0.78 | 0.0 | ✅ |
| apple-on-device · composite | realistic take, UK voice, babble 15 dB [Daniel, WER 11%, ASR lag 0.9 s] | 0.00 | 0.0 | 0.2/0.8 | 0/4 | 0.0 | 0 | 0.51/1.23 | 0.0 | ✅ |
| apple-on-device · noise | 4-talker babble, 10 dB [Samantha, WER 7%, ASR lag 1.0 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.48/1.14 | 0.0 | ✅ |
| apple-on-device · noise | 4-talker babble, 5 dB [Samantha, WER 18%, ASR lag 0.6 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.61/1.65 | 0.0 | ⚠️ report-only |
| apple-on-device · noise | HVAC rumble, 5 dB [Samantha, WER 4%, ASR lag 0.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.44/0.77 | 0.0 | ✅ |
| apple-on-device · noise | competing talker (TV), 10 dB [Samantha, WER 6%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.49/0.85 | 0.0 | ✅ |
| apple-on-device · noise | competing talker (TV), 5 dB [Samantha, WER 6%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.48/0.88 | 0.0 | ✅ |
| apple-on-device · paraphrase | ad-lib 15 and 40 words [Samantha, WER 3%, ASR lag 0.5 s] | 0.00 | 0.0 | 0.2/0.2 | 0/2 | 0.0 | 0 | 0.42/0.85 | 0.0 | ✅ |
| apple-on-device · paraphrase | contractions, synonyms, fillers [Karen, WER 8%, ASR lag -0.7 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.45/0.99 | 0.0 | ✅ |
| apple-on-device · pauses | pauses 5 s, 20 s, 60 s [Samantha, WER 4%, ASR lag 16.6 s] | 0.00 | 0.0 | 0.1/0.1 | 0/3 | 0.0 | 0 | 0.44/0.80 | 0.0 | ✅ |
| apple-on-device · repeated | refrains + restart sentence ×3 [Daniel, WER 3%, ASR lag 0.5 s] | 0.00 | 0.0 | 1.0/1.0 | 0/3 | 0.0 | 0 | 0.43/0.67 | 0.0 | ✅ |
| apple-on-device · repeated | re-read 12 words ×2, jump back 30 [Samantha, WER 5%, ASR lag 0.3 s] | 0.00 | 0.0 | 1.9/1.9 | 0/3 | 0.0 | 0 | 0.43/0.74 | 0.0 | ✅ |
| apple-on-device · skips | skip 10, 25, 60 words [Rishi, WER 3%, ASR lag 0.3 s] | 0.00 | 0.0 | 2.1/2.1 | 0/3 | 0.0 | 0 | 0.49/0.96 | 0.0 | ✅ |
| apple-on-device · speed | 130 wpm [Samantha, WER 3%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.46/0.77 | 0.0 | ✅ |
| apple-on-device · speed | 230 wpm [Samantha, WER 4%, ASR lag 0.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.46/0.72 | 0.0 | ✅ |
| apple-on-device · technical | jargon, app's contextual hints on [Samantha, WER 19%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.42/1.01 | 0.0 | ✅ |
| apple-on-device · technical | jargon, no hints [Samantha, WER 22%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.42/1.11 | 0.0 | ✅ |
| local-canary · accent | UK English (Daniel) [Daniel, rolling window: WER n/a] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.45/1.15 | 0.0 | ✅ |
| local-canary · accent | Indian English (Rishi) [Rishi, rolling window: WER n/a] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.53/1.19 | 0.0 | ✅ |
| local-canary · baseline | clean read, US voice [Samantha, rolling window: WER n/a] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.49/1.26 | 0.0 | ✅ |
| local-canary · composite | realistic take, UK voice, babble 15 dB [Daniel, rolling window: WER n/a] | 0.00 | 0.0 | 0.8/1.4 | 0/4 | 0.0 | 0 | 0.51/1.35 | 0.0 | ✅ |
| local-canary · noise | 4-talker babble, 10 dB [Samantha, rolling window: WER n/a] | 6.66 | 3.1 | –/– | – | 0.0 | 0 | 0.74/3.04 | 0.0 | ⚠️ report-only |
| local-canary · noise | competing talker (TV), 10 dB [Samantha, rolling window: WER n/a] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.54/1.27 | 0.0 | ✅ |
| local-canary · paraphrase | ad-lib 15 and 40 words [Samantha, rolling window: WER n/a] | 0.00 | 0.0 | 0.1/0.1 | 0/2 | 0.0 | 0 | 0.50/1.13 | 0.0 | ✅ |
| local-canary · pauses | pauses 5 s, 20 s, 60 s [Samantha, rolling window: WER n/a] | 0.00 | 0.0 | 0.1/0.1 | 0/3 | 0.0 | 0 | 0.47/1.21 | 0.0 | ✅ |
| local-canary · repeated | re-read 12 words ×2, jump back 30 [Samantha, rolling window: WER n/a] | 0.00 | 0.0 | 2.1/2.1 | 0/3 | 0.0 | 0 | 0.51/1.27 | 0.0 | ✅ |
| local-canary · skips | skip 10, 25, 60 words [Rishi, rolling window: WER n/a] | 0.00 | 0.0 | 2.4/2.4 | 0/3 | 0.0 | 0 | 0.48/1.18 | 0.0 | ✅ |
| local-canary · technical | jargon, app's contextual hints on [Samantha, rolling window: WER n/a] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.48/1.37 | 0.0 | ✅ |
| local-nemotron · accent | UK English (Daniel) [Daniel, WER 1%, ASR lag 0.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.35/0.78 | 0.0 | ✅ |
| local-nemotron · accent | Indian English (Rishi) [Rishi, WER 0%, ASR lag 0.2 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.41/0.87 | 0.0 | ✅ |
| local-nemotron · baseline | clean read, US voice [Samantha, WER 0%, ASR lag 0.1 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.33/0.73 | 0.0 | ✅ |
| local-nemotron · composite | realistic take, UK voice, babble 15 dB [Daniel, WER 3%, ASR lag 0.6 s] | 0.00 | 0.0 | 0.2/0.8 | 0/4 | 0.0 | 0 | 0.38/0.86 | 0.0 | ✅ |
| local-nemotron · noise | 4-talker babble, 10 dB [Samantha, WER 3%, ASR lag 0.0 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.40/0.84 | 0.0 | ✅ |
| local-nemotron · noise | competing talker (TV), 10 dB [Samantha, WER 2%, ASR lag 0.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.38/0.76 | 0.0 | ✅ |
| local-nemotron · paraphrase | ad-lib 15 and 40 words [Samantha, WER 0%, ASR lag 0.1 s] | 0.00 | 0.0 | 0.1/0.1 | 0/2 | 0.0 | 0 | 0.34/0.76 | 0.0 | ✅ |
| local-nemotron · pauses | pauses 5 s, 20 s, 60 s [Samantha, WER 1%, ASR lag 0.1 s] | 0.00 | 0.0 | 0.1/0.1 | 0/3 | 0.0 | 0 | 0.37/0.82 | 0.0 | ✅ |
| local-nemotron · repeated | re-read 12 words ×2, jump back 30 [Samantha, WER 0%, ASR lag 0.1 s] | 0.00 | 0.0 | 1.9/1.9 | 0/3 | 0.0 | 0 | 0.35/0.80 | 0.0 | ✅ |
| local-nemotron · skips | skip 10, 25, 60 words [Rishi, WER 1%, ASR lag 0.2 s] | 0.00 | 0.0 | 2.1/2.1 | 0/3 | 0.0 | 0 | 0.39/0.84 | 0.0 | ✅ |
| local-nemotron · technical | jargon, app's contextual hints on [Samantha, WER 15%, ASR lag 0.7 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.30/1.02 | 0.0 | ✅ |

Layer B (synthetic voices → real recognizers, real audio, one take per case per engine). Matcher: current

42/42 gating cases pass the launch bar (PLAN.md §8); 7 report-only.

