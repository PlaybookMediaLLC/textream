| Dimension | Case | Lost/10 min | Lost % time | Recovery p50/p95 (s) | Never recovered | Ahead >3w % time | Silence drift (w) | Lag p50/p95 (s) | Final err (w) | Pass |
|---|---|---|---|---|---|---|---|---|---|---|
| apple-on-device · accent | Australian English (Karen) [Karen, WER 5%, ASR lag 0.6 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.45/0.75 | 0.0 | ✅ |
| apple-on-device · accent | UK English (Daniel) [Daniel, WER 4%, ASR lag 0.2 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.47/0.76 | 1.0 | ✅ |
| apple-on-device · accent | Irish English (Moira) [Moira, WER 6%, ASR lag 0.2 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.44/0.73 | 0.0 | ✅ |
| apple-on-device · accent | Indian English (Rishi) [Rishi, WER 3%, ASR lag 0.2 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.49/0.83 | 0.0 | ✅ |
| apple-on-device · accent | Indian English (Tara) [Tara, WER 3%, ASR lag 0.2 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.45/0.72 | 0.0 | ✅ |
| apple-on-device · accent (non-native proxy) | French voice reading English [Thomas, WER 52%, ASR lag 5.6 s] | 5.76 | 88.8 | –/– | – | 0.0 | 0 | 0.66/8.90 | 166.0 | ⚠️ report-only |
| apple-on-device · accent (non-native proxy) | German voice reading English [Anna, WER 28%, ASR lag 8.3 s] | 0.00 | 0.0 | –/– | – | 1.7 | 0 | 0.56/1.42 | 0.0 | ⚠️ report-only |
| apple-on-device · accent (non-native proxy) | Mandarin voice reading English [Tingting, WER 8%, ASR lag -0.1 s] | 5.18 | 55.5 | –/– | – | 0.0 | 0 | 0.56/9.29 | 74.0 | ⚠️ report-only |
| apple-on-device · accent (non-native proxy) | Spanish voice reading English [Mónica, WER 4%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.43/0.74 | 0.0 | ✅ |
| apple-on-device · accent | South African English (Tessa) [Tessa, WER 5%, ASR lag 0.2 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.48/0.86 | 0.0 | ✅ |
| apple-on-device · baseline | clean read, US voice [Samantha, WER 4%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.43/0.74 | 0.0 | ✅ |
| apple-on-device · composite | realistic take, UK voice, babble 15 dB [Daniel, WER 32%, ASR lag 0.9 s] | 17.25 | 47.4 | 0.8/0.8 | 2/4 | 0.5 | 0 | 0.52/0.84 | 118.0 | ❌ |
| apple-on-device · human · baseline | LibriSpeech reader 1462 (F), straight [human: LibriSpeech 1462, WER 4%, ASR lag 0.4 s] | 6.82 | 70.2 | –/– | – | 0.0 | 0 | 0.51/0.72 | 138.0 | ❌ |
| apple-on-device · human · baseline | LibriSpeech reader 1673 (F), straight [human: LibriSpeech 1673, WER 5%, ASR lag 0.5 s] | 7.33 | 63.2 | –/– | – | 0.0 | 0 | 0.55/1.03 | 110.0 | ❌ |
| apple-on-device · human · noise | LibriSpeech reader 174 (M), babble10 [human: LibriSpeech 174, WER 34%, ASR lag 6.8 s] | 7.63 | 94.5 | –/– | – | 0.0 | 0 | 8.22/9.83 | 140.0 | ⚠️ report-only |
| apple-on-device · human · composite | LibriSpeech reader 174 (M), composite [human: LibriSpeech 174, WER 12%, ASR lag 5.4 s] | 21.12 | 86.6 | –/– | 2/2 | 0.0 | 0 | 8.33/9.41 | 117.0 | ❌ |
| apple-on-device · human · pauses | LibriSpeech reader 174 (M), pause [human: LibriSpeech 174, WER 5%, ASR lag 0.4 s] | 12.17 | 70.0 | –/– | 1/1 | 0.0 | 0 | 0.46/0.75 | 85.0 | ❌ |
| apple-on-device · human · repeated | LibriSpeech reader 174 (M), reread [human: LibriSpeech 174, WER 6%, ASR lag 0.5 s] | 13.09 | 67.6 | –/– | 1/1 | 0.0 | 0 | 0.46/0.75 | 89.0 | ❌ |
| apple-on-device · human · skips | LibriSpeech reader 174 (M), skip [human: LibriSpeech 174, WER 3%, ASR lag 0.4 s] | 10.99 | 51.7 | 0.1/0.1 | 0/1 | 0.0 | 0 | 0.46/0.75 | 83.0 | ❌ |
| apple-on-device · human · baseline | LibriSpeech reader 174 (M), straight [human: LibriSpeech 174, WER 5%, ASR lag 0.4 s] | 7.63 | 66.2 | –/– | – | 0.0 | 0 | 0.46/0.75 | 85.0 | ❌ |
| apple-on-device · human · baseline | LibriSpeech reader 251 (M), straight [human: LibriSpeech 251, WER 6%, ASR lag 0.5 s] | 6.63 | 65.8 | –/– | – | 0.0 | 0 | 0.56/0.82 | 112.0 | ❌ |
| apple-on-device · human · baseline | LibriSpeech reader 422 (M), straight [human: LibriSpeech 422, WER 9%, ASR lag 19.5 s] | 6.69 | 75.8 | –/– | – | 0.0 | 0 | 0.60/0.97 | 129.0 | ❌ |
| apple-on-device · human · noise | LibriSpeech reader 84 (F), babble10 [human: LibriSpeech 84, WER 21%, ASR lag 1.4 s] | 7.35 | 66.1 | –/– | – | 0.0 | 0 | 0.56/0.99 | 132.0 | ❌ |
| apple-on-device · human · composite | LibriSpeech reader 84 (F), composite [human: LibriSpeech 84, WER 13%, ASR lag 0.5 s] | 26.42 | 66.6 | 0.7/0.7 | 2/3 | 0.0 | 0 | 0.52/0.76 | 131.0 | ❌ |
| apple-on-device · human · pauses | LibriSpeech reader 84 (F), pause [human: LibriSpeech 84, WER 39%, ASR lag 0.4 s] | 11.80 | 76.0 | –/– | 1/1 | 0.0 | 0 | 0.49/0.67 | 113.0 | ❌ |
| apple-on-device · human · repeated | LibriSpeech reader 84 (F), reread [human: LibriSpeech 84, WER 36%, ASR lag 0.3 s] | 20.14 | 69.4 | –/– | 2/2 | 0.0 | 0 | 0.48/0.67 | 123.0 | ❌ |
| apple-on-device · human · skips | LibriSpeech reader 84 (F), skip [human: LibriSpeech 84, WER 78%, ASR lag 0.1 s] | 18.48 | 62.7 | –/– | 2/2 | 0.0 | 0 | 0.49/0.67 | 131.0 | ❌ |
| apple-on-device · human · baseline | LibriSpeech reader 84 (F), straight [human: LibriSpeech 84, WER 36%, ASR lag 0.5 s] | 7.35 | 73.8 | –/– | – | 0.0 | 0 | 0.49/0.67 | 110.0 | ❌ |
| apple-on-device · human · noise | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), babble10 [human: Speechocean762 l2-0036, WER 16%, ASR lag 19.8 s] | 7.83 | 81.6 | –/– | – | 0.0 | 0 | 0.77/1.59 | 101.0 | ❌ |
| apple-on-device · human · composite | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), composite [human: Speechocean762 l2-0036, WER 11%, ASR lag 24.1 s] | 28.52 | 77.0 | –/– | 3/3 | 0.0 | 0 | 0.77/1.47 | 101.0 | ❌ |
| apple-on-device · human · pauses | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), pause [human: Speechocean762 l2-0036, WER 10%, ASR lag 4.2 s] | 12.42 | 82.3 | –/– | 1/1 | 0.0 | 0 | 0.63/1.20 | 105.0 | ❌ |
| apple-on-device · human · repeated | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), reread [human: Speechocean762 l2-0036, WER 12%, ASR lag 22.4 s] | 21.18 | 76.2 | –/– | 2/2 | 0.0 | 0 | 0.63/1.20 | 108.0 | ❌ |
| apple-on-device · human · skips | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), skip [human: Speechocean762 l2-0036, WER 10%, ASR lag 4.1 s] | 18.41 | 77.1 | 0.1/0.1 | 1/2 | 0.0 | 0 | 0.63/1.20 | 101.0 | ❌ |
| apple-on-device · human · baseline | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), straight [human: Speechocean762 l2-0036, WER 11%, ASR lag 20.3 s] | 7.83 | 81.6 | –/– | – | 0.0 | 0 | 0.63/1.20 | 105.0 | ❌ |
| apple-on-device · human · baseline | Speechocean762 speaker 0135 (Mandarin L1, F, age 20), straight [human: Speechocean762 l2-0135, WER 8%, ASR lag 10.9 s] | 8.01 | 92.7 | –/– | – | 0.0 | 0 | 0.63/0.90 | 117.0 | ❌ |
| apple-on-device · human · baseline | Speechocean762 speaker 0482 (Mandarin L1, M, age 28), straight [human: Speechocean762 l2-0482, WER 11%, ASR lag 0.6 s] | 7.51 | 80.1 | –/– | – | 0.0 | 0 | 0.51/0.90 | 92.0 | ❌ |
| apple-on-device · human · noise | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), babble10 [human: Speechocean762 l2-0560, WER 51%, ASR lag 2.4 s] | 7.07 | 91.0 | –/– | – | 0.0 | 0 | 0.61/0.96 | 113.0 | ⚠️ report-only |
| apple-on-device · human · composite | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), composite [human: Speechocean762 l2-0560, WER 52%, ASR lag 2.6 s] | 18.80 | 71.3 | 1.0/1.0 | 2/3 | 0.0 | 0 | 0.64/0.86 | 94.0 | ⚠️ report-only |
| apple-on-device · human · pauses | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), pause [human: Speechocean762 l2-0560, WER 37%, ASR lag 0.4 s] | 11.44 | 78.0 | –/– | 1/1 | 0.0 | 0 | 0.52/0.76 | 85.0 | ⚠️ report-only |
| apple-on-device · human · repeated | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), reread [human: Speechocean762 l2-0560, WER 42%, ASR lag 0.4 s] | 13.16 | 71.6 | –/– | 2/2 | 0.0 | 0 | 0.52/0.76 | 92.0 | ⚠️ report-only |
| apple-on-device · human · skips | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), skip [human: Speechocean762 l2-0560, WER 45%, ASR lag 0.4 s] | 17.33 | 76.2 | –/– | 2/2 | 0.0 | 0 | 0.52/0.77 | 93.0 | ⚠️ report-only |
| apple-on-device · human · baseline | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), straight [human: Speechocean762 l2-0560, WER 37%, ASR lag 0.4 s] | 7.07 | 76.3 | –/– | – | 0.0 | 0 | 0.52/0.76 | 92.0 | ⚠️ report-only |
| apple-on-device · noise | 4-talker babble, 10 dB [Samantha, WER 7%, ASR lag 0.8 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.46/0.88 | 0.0 | ✅ |
| apple-on-device · noise | 4-talker babble, 5 dB [Samantha, WER 15%, ASR lag 0.6 s] | 6.66 | 50.5 | –/– | – | 0.0 | 0 | 0.59/1.67 | 98.0 | ⚠️ report-only |
| apple-on-device · noise | HVAC rumble, 5 dB [Samantha, WER 4%, ASR lag 0.4 s] | 6.66 | 50.5 | –/– | – | 0.0 | 0 | 0.44/0.73 | 98.0 | ❌ |
| apple-on-device · noise | competing talker (TV), 10 dB [Samantha, WER 5%, ASR lag 0.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.46/0.79 | 0.0 | ✅ |
| apple-on-device · noise | competing talker (TV), 5 dB [Samantha, WER 42%, ASR lag 0.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.48/0.81 | 0.0 | ✅ |
| apple-on-device · paraphrase | ad-lib 15 and 40 words [Samantha, WER 4%, ASR lag 0.1 s] | 17.09 | 15.2 | 10.8/10.8 | 0/2 | 29.4 | 0 | 0.39/0.75 | 0.0 | ❌ |
| apple-on-device · paraphrase | contractions, synonyms, fillers [Karen, WER 8%, ASR lag -0.6 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.45/0.83 | 1.0 | ✅ |
| apple-on-device · pauses | pauses 5 s, 20 s, 60 s [Samantha, WER 3%, ASR lag 22.1 s] | 10.25 | 84.9 | 0.1/0.1 | 2/3 | 0.0 | 0 | 0.41/0.66 | 166.0 | ❌ |
| apple-on-device · repeated | refrains + restart sentence ×3 [Daniel, WER 3%, ASR lag 0.5 s] | 0.00 | 0.0 | 1.0/1.0 | 0/3 | 0.0 | 0 | 0.45/0.78 | 0.0 | ✅ |
| apple-on-device · repeated | re-read 12 words ×2, jump back 30 [Samantha, WER 5%, ASR lag 0.2 s] | 5.48 | 13.7 | 10.9/10.9 | 0/3 | 24.0 | 0 | 0.37/0.74 | 0.0 | ❌ |
| apple-on-device · skips | skip 10, 25, 60 words [Rishi, WER 3%, ASR lag 0.2 s] | 26.49 | 61.8 | –/– | 3/3 | 0.0 | 0 | 0.52/8.97 | 157.0 | ❌ |
| apple-on-device · speed | 130 wpm [Samantha, WER 4%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.46/0.77 | 0.0 | ✅ |
| apple-on-device · speed | 230 wpm [Samantha, WER 5%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.45/0.73 | 0.0 | ✅ |
| apple-on-device · technical | jargon, app's contextual hints on [Samantha, WER 13%, ASR lag -0.0 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.44/0.89 | 0.0 | ✅ |
| apple-on-device · technical | jargon, no hints [Samantha, WER 16%, ASR lag -0.2 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.43/1.03 | 0.0 | ✅ |
| apple-server-en-AU · accent | Australian English (Karen) [Karen, WER 3%, ASR lag 0.7 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.53/0.85 | 0.0 | ✅ |
| apple-server-en-CA · noise | 4-talker babble, 10 dB [Samantha, WER 9%, ASR lag 0.9 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.59/0.95 | 0.0 | ✅ |
| apple-server-en-CA · noise | competing talker (TV), 10 dB [Samantha, WER 4%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.57/0.88 | 0.0 | ✅ |
| apple-server-en-CA · repeated | re-read 12 words ×2, jump back 30 [Samantha, WER 5%, ASR lag 0.7 s] | 5.48 | 14.4 | 8.4/8.4 | 0/3 | 23.3 | 0 | 0.44/0.82 | 0.0 | ❌ |
| apple-server-en-GB · accent | UK English (Daniel) [Daniel, WER 6%, ASR lag 0.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.54/0.87 | 0.0 | ✅ |
| apple-server-en-GB · baseline | clean read, US voice [Samantha, WER 4%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.54/0.81 | 0.0 | ✅ |
| apple-server-en-IE · accent | Irish English (Moira) [Moira, WER 5%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.55/0.84 | 0.0 | ✅ |
| apple-server-en-IN · accent | Indian English (Rishi) [Rishi, WER 4%, ASR lag 0.7 s] | 0.00 | 0.0 | –/– | – | 0.7 | 0 | 0.56/0.97 | 0.0 | ✅ |
| apple-server-en-IN · accent | Indian English (Tara) [Tara, WER 6%, ASR lag 0.8 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.51/0.84 | 0.0 | ✅ |
| apple-server-en-NZ · paraphrase | ad-lib 15 and 40 words [Samantha, WER 4%, ASR lag 0.7 s] | 11.40 | 5.2 | 6.4/6.4 | 0/2 | 17.1 | 0 | 0.54/1.06 | 0.0 | ❌ |
| apple-server-en-NZ · pauses | pauses 5 s, 20 s, 60 s [Samantha, WER 4%, ASR lag 0.3 s] | 0.00 | 0.0 | 0.1/0.1 | 0/3 | 0.0 | 0 | 0.49/0.82 | 0.0 | ✅ |
| apple-server-en-SG · skips | skip 10, 25, 60 words [Rishi, WER 4%, ASR lag 0.9 s] | 26.49 | 61.8 | –/– | 3/3 | 0.0 | 0 | 0.63/8.97 | 157.0 | ❌ |
| apple-server-en-SG · technical | jargon, app's contextual hints on [Samantha, WER 24%, ASR lag -0.4 s] | 0.00 | 0.0 | –/– | – | 0.7 | 0 | 0.44/1.03 | 0.0 | ✅ |
| apple-server-en-ZA · accent | South African English (Tessa) [Tessa, WER 5%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.59/0.93 | 0.0 | ✅ |
| local-canary · accent | UK English (Daniel) [Daniel, rolling window: WER n/a] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.45/1.17 | 0.0 | ✅ |
| local-canary · accent | Indian English (Rishi) [Rishi, rolling window: WER n/a] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.56/1.56 | 0.0 | ❌ |
| local-canary · accent (non-native proxy) | French voice reading English [Thomas, rolling window: WER n/a] | 11.51 | 87.3 | –/– | – | 0.0 | 0 | 2.01/8.06 | 173.0 | ⚠️ report-only |
| local-canary · accent (non-native proxy) | German voice reading English [Anna, rolling window: WER n/a] | 11.83 | 83.3 | –/– | – | 0.0 | 0 | 2.46/7.24 | 166.0 | ⚠️ report-only |
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
| local-nemotron · accent (non-native proxy) | French voice reading English [Thomas, WER 58%, ASR lag 11.8 s] | 5.76 | 96.2 | –/– | – | 0.0 | 0 | 6.41/9.04 | 139.0 | ⚠️ report-only |
| local-nemotron · accent (non-native proxy) | German voice reading English [Anna, WER 53%, ASR lag 17.2 s] | 5.91 | 97.1 | –/– | – | 0.0 | 0 | 4.47/7.79 | 152.0 | ⚠️ report-only |
| local-nemotron · accent (non-native proxy) | Mandarin voice reading English [Tingting, WER 2%, ASR lag 0.1 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.43/0.93 | 0.0 | ✅ |
| local-nemotron · accent (non-native proxy) | Spanish voice reading English [Mónica, WER 0%, ASR lag 0.1 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.37/0.76 | 0.0 | ✅ |
| local-nemotron · baseline | clean read, US voice [Samantha, WER 0%, ASR lag 0.1 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.36/0.73 | 0.0 | ✅ |
| local-nemotron · composite | realistic take, UK voice, babble 15 dB [Daniel, WER 3%, ASR lag 0.6 s] | 11.50 | 34.7 | 0.2/0.2 | 2/4 | 0.0 | 0 | 0.40/0.85 | 89.0 | ❌ |
| local-nemotron · human · baseline | LibriSpeech reader 1462 (F), straight [human: LibriSpeech 1462, WER 4%, ASR lag 0.6 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.43/0.77 | 0.0 | ✅ |
| local-nemotron · human · baseline | LibriSpeech reader 1673 (F), straight [human: LibriSpeech 1673, WER 0%, ASR lag 0.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.47/0.82 | 0.0 | ✅ |
| local-nemotron · human · noise | LibriSpeech reader 174 (M), babble10 [human: LibriSpeech 174, WER 3%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.55/0.91 | 0.0 | ✅ |
| local-nemotron · human · composite | LibriSpeech reader 174 (M), composite [human: LibriSpeech 174, WER 0%, ASR lag 0.3 s] | 7.04 | 37.3 | 1.0/1.0 | 0/2 | 37.3 | 0 | 0.32/0.79 | 0.0 | ❌ |
| local-nemotron · human · pauses | LibriSpeech reader 174 (M), pause [human: LibriSpeech 174, WER 1%, ASR lag 0.3 s] | 0.00 | 0.0 | 0.0/0.0 | 0/1 | 0.0 | 0 | 0.45/0.82 | 0.0 | ✅ |
| local-nemotron · human · repeated | LibriSpeech reader 174 (M), reread [human: LibriSpeech 174, WER 0%, ASR lag 0.3 s] | 6.55 | 22.6 | 0.0/0.0 | 0/1 | 28.9 | 0 | 0.36/0.76 | 0.0 | ❌ |
| local-nemotron · human · skips | LibriSpeech reader 174 (M), skip [human: LibriSpeech 174, WER 0%, ASR lag 0.2 s] | 10.99 | 51.7 | 0.1/0.1 | 0/1 | 0.0 | 0 | 0.40/0.79 | 60.0 | ❌ |
| local-nemotron · human · baseline | LibriSpeech reader 174 (M), straight [human: LibriSpeech 174, WER 1%, ASR lag 0.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.42/0.80 | 0.0 | ✅ |
| local-nemotron · human · baseline | LibriSpeech reader 251 (M), straight [human: LibriSpeech 251, WER 4%, ASR lag 0.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.46/0.97 | 0.0 | ✅ |
| local-nemotron · human · baseline | LibriSpeech reader 422 (M), straight [human: LibriSpeech 422, WER 1%, ASR lag -0.1 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.47/0.81 | 0.0 | ✅ |
| local-nemotron · human · noise | LibriSpeech reader 84 (F), babble10 [human: LibriSpeech 84, WER 8%, ASR lag 0.7 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.51/0.95 | 0.0 | ✅ |
| local-nemotron · human · composite | LibriSpeech reader 84 (F), composite [human: LibriSpeech 84, WER 6%, ASR lag 0.8 s] | 19.82 | 40.5 | 13.5/13.5 | 2/3 | 11.3 | 0 | 0.43/0.85 | 45.0 | ❌ |
| local-nemotron · human · pauses | LibriSpeech reader 84 (F), pause [human: LibriSpeech 84, WER 4%, ASR lag 0.3 s] | 0.00 | 0.0 | 0.0/0.0 | 0/1 | 0.0 | 0 | 0.49/0.87 | 2.0 | ✅ |
| local-nemotron · human · repeated | LibriSpeech reader 84 (F), reread [human: LibriSpeech 84, WER 5%, ASR lag 0.3 s] | 0.00 | 0.0 | 1.0/1.0 | 0/2 | 6.2 | 0 | 0.45/0.84 | 2.0 | ❌ |
| local-nemotron · human · skips | LibriSpeech reader 84 (F), skip [human: LibriSpeech 84, WER 5%, ASR lag 0.3 s] | 18.48 | 62.7 | –/– | 2/2 | 0.0 | 0 | 0.50/0.82 | 98.0 | ❌ |
| local-nemotron · human · baseline | LibriSpeech reader 84 (F), straight [human: LibriSpeech 84, WER 4%, ASR lag 0.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.48/0.86 | 2.0 | ✅ |
| local-nemotron · human · noise | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), babble10 [human: Speechocean762 l2-0036, WER 12%, ASR lag 0.7 s] | 7.83 | 32.9 | –/– | – | 0.0 | 0 | 0.68/4.12 | 33.0 | ❌ |
| local-nemotron · human · composite | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), composite [human: Speechocean762 l2-0036, WER 13%, ASR lag 0.2 s] | 14.26 | 64.2 | 0.0/0.0 | 1/3 | 3.3 | 0 | 0.73/1.45 | 48.0 | ❌ |
| local-nemotron · human · pauses | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), pause [human: Speechocean762 l2-0036, WER 12%, ASR lag 0.3 s] | 6.21 | 24.3 | 0.1/0.1 | 0/1 | 0.0 | 0 | 0.73/7.84 | 32.0 | ❌ |
| local-nemotron · human · repeated | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), reread [human: Speechocean762 l2-0036, WER 10%, ASR lag 0.3 s] | 0.00 | 0.0 | 0.0/0.0 | 0/2 | 0.0 | 0 | 0.63/1.50 | 0.0 | ✅ |
| local-nemotron · human · skips | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), skip [human: Speechocean762 l2-0036, WER 12%, ASR lag 0.3 s] | 18.41 | 72.1 | 0.1/0.1 | 1/2 | 0.0 | 0 | 0.97/1.45 | 69.0 | ❌ |
| local-nemotron · human · baseline | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), straight [human: Speechocean762 l2-0036, WER 8%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.61/1.27 | 0.0 | ✅ |
| local-nemotron · human · baseline | Speechocean762 speaker 0135 (Mandarin L1, F, age 20), straight [human: Speechocean762 l2-0135, WER 6%, ASR lag 0.9 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.60/1.10 | 0.0 | ✅ |
| local-nemotron · human · baseline | Speechocean762 speaker 0482 (Mandarin L1, M, age 28), straight [human: Speechocean762 l2-0482, WER 11%, ASR lag 0.1 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.58/1.20 | 0.0 | ✅ |
| local-nemotron · human · noise | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), babble10 [human: Speechocean762 l2-0560, WER 37%, ASR lag 5.0 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.82/2.79 | 0.0 | ✅ |
| local-nemotron · human · composite | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), composite [human: Speechocean762 l2-0560, WER 31%, ASR lag 2.6 s] | 12.54 | 59.5 | 0.2/0.2 | 1/3 | 3.9 | 0 | 0.84/7.65 | 52.0 | ⚠️ report-only |
| local-nemotron · human · pauses | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), pause [human: Speechocean762 l2-0560, WER 30%, ASR lag 1.9 s] | 5.72 | 49.8 | 0.2/0.2 | 0/1 | 0.0 | 0 | 0.78/5.45 | 52.0 | ⚠️ report-only |
| local-nemotron · human · repeated | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), reread [human: Speechocean762 l2-0560, WER 29%, ASR lag 0.2 s] | 0.00 | 0.0 | 0.1/0.1 | 0/2 | 3.0 | 0 | 0.73/2.49 | 0.0 | ⚠️ report-only |
| local-nemotron · human · skips | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), skip [human: Speechocean762 l2-0560, WER 24%, ASR lag 0.4 s] | 17.33 | 76.2 | –/– | 2/2 | 0.0 | 0 | 0.86/1.20 | 52.0 | ⚠️ report-only |
| local-nemotron · human · baseline | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), straight [human: Speechocean762 l2-0560, WER 28%, ASR lag 1.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.75/2.25 | 0.0 | ✅ |
| local-nemotron · noise | 4-talker babble, 10 dB [Samantha, WER 3%, ASR lag 0.0 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.43/0.84 | 0.0 | ✅ |
| local-nemotron · noise | competing talker (TV), 10 dB [Samantha, WER 2%, ASR lag 0.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.40/0.79 | 0.0 | ✅ |
| local-nemotron · paraphrase | ad-lib 15 and 40 words [Samantha, WER 0%, ASR lag 0.1 s] | 17.09 | 15.2 | 9.3/9.3 | 0/2 | 28.7 | 0 | 0.29/0.76 | 0.0 | ❌ |
| local-nemotron · pauses | pauses 5 s, 20 s, 60 s [Samantha, WER 1%, ASR lag 0.1 s] | 0.00 | 0.0 | 0.1/0.1 | 0/3 | 0.0 | 0 | 0.39/0.83 | 0.0 | ✅ |
| local-nemotron · repeated | re-read 12 words ×2, jump back 30 [Samantha, WER 0%, ASR lag 0.1 s] | 5.48 | 13.0 | 5.9/5.9 | 0/3 | 19.4 | 0 | 0.29/0.78 | 0.0 | ❌ |
| local-nemotron · skips | skip 10, 25, 60 words [Rishi, WER 1%, ASR lag 0.2 s] | 26.49 | 61.8 | –/– | 3/3 | 0.0 | 0 | 0.43/8.90 | 157.0 | ❌ |
| local-nemotron · technical | jargon, app's contextual hints on [Samantha, WER 14%, ASR lag 0.7 s] | 0.00 | 0.0 | –/– | – | 2.5 | 0 | 0.29/1.07 | 0.0 | ❌ |
| local-qwen3 · human · noise | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), babble10 [human: Speechocean762 l2-0560, rolling window: WER n/a] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 1.04/2.58 | 0.0 | ✅ |
| local-qwen3 · human · composite | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), composite [human: Speechocean762 l2-0560, rolling window: WER n/a] | 12.54 | 59.0 | 0.2/0.2 | 1/3 | 4.2 | 0 | 0.65/4.10 | 42.0 | ⚠️ report-only |
| local-qwen3 · human · pauses | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), pause [human: Speechocean762 l2-0560, rolling window: WER n/a] | 0.00 | 0.0 | 5.2/5.2 | 0/1 | 18.4 | 8 | 0.96/2.16 | 1.0 | ❌ |
| local-qwen3 · human · repeated | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), reread [human: Speechocean762 l2-0560, rolling window: WER n/a] | 0.00 | 0.0 | 0.1/0.1 | 0/2 | 1.4 | 0 | 1.02/2.11 | 0.0 | ❌ |
| local-qwen3 · human · skips | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), skip [human: Speechocean762 l2-0560, rolling window: WER n/a] | 17.33 | 76.2 | –/– | 2/2 | 0.0 | 0 | 0.49/1.27 | 66.0 | ❌ |
| local-qwen3 · human · baseline | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), straight [human: Speechocean762 l2-0560, rolling window: WER n/a] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 1.00/2.29 | 0.0 | ✅ |
| local-whisper-tiny-q8-0 · baseline | clean read, US voice [Samantha, rolling window: WER n/a] | 0.00 | 0.0 | –/– | – | 16.6 | 0 | 0.43/1.59 | 0.0 | ⚠️ report-only |

Layer B (synthetic voices → real recognizers, real audio, one take per case per engine). Matcher: legacy (git f9c6c94)

50/108 gating cases pass the launch bar (PLAN.md §8); 28 report-only.

