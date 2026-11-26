| Dimension | Case | Lost/10 min | Lost % time | Recovery p50/p95 (s) | Never recovered | Ahead >3w % time | Silence drift (w) | Lag p50/p95 (s) | Final err (w) | Pass |
|---|---|---|---|---|---|---|---|---|---|---|
| apple-on-device · accent | Australian English (Karen) [Karen, WER 5%, ASR lag 0.6 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.44/0.75 | 0.0 | ✅ |
| apple-on-device · accent | UK English (Daniel) [Daniel, WER 4%, ASR lag 0.2 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.47/0.78 | 1.0 | ✅ |
| apple-on-device · accent | Irish English (Moira) [Moira, WER 6%, ASR lag 0.2 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.44/0.76 | 0.0 | ✅ |
| apple-on-device · accent | Indian English (Rishi) [Rishi, WER 3%, ASR lag 0.2 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.49/0.81 | 0.0 | ✅ |
| apple-on-device · accent | Indian English (Tara) [Tara, WER 3%, ASR lag 0.2 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.45/0.76 | 0.0 | ✅ |
| apple-on-device · accent (non-native proxy) | French voice reading English [Thomas, WER 52%, ASR lag 5.6 s] | 28.79 | 15.1 | –/– | – | 0.5 | 0 | 1.32/4.96 | 0.0 | ⚠️ report-only |
| apple-on-device · accent (non-native proxy) | German voice reading English [Anna, WER 28%, ASR lag 8.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.61/1.72 | 0.0 | ⚠️ report-only |
| apple-on-device · accent (non-native proxy) | Mandarin voice reading English [Tingting, WER 8%, ASR lag -0.1 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.46/1.00 | 0.0 | ✅ |
| apple-on-device · accent (non-native proxy) | Spanish voice reading English [Mónica, WER 4%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.43/0.76 | 0.0 | ✅ |
| apple-on-device · accent | South African English (Tessa) [Tessa, WER 5%, ASR lag 0.2 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.48/0.84 | 0.0 | ✅ |
| apple-on-device · baseline | clean read, US voice [Samantha, WER 4%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.43/0.76 | 0.0 | ✅ |
| apple-on-device · composite | realistic take, UK voice, babble 15 dB [Daniel, WER 32%, ASR lag 0.9 s] | 0.00 | 0.0 | 0.2/0.8 | 0/4 | 0.0 | 0 | 0.51/1.23 | 0.0 | ✅ |
| apple-on-device · human · baseline | LibriSpeech reader 1462 (F), straight [human: LibriSpeech 1462, WER 4%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.51/0.77 | 0.0 | ✅ |
| apple-on-device · human · baseline | LibriSpeech reader 1673 (F), straight [human: LibriSpeech 1673, WER 5%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.52/0.80 | 0.0 | ✅ |
| apple-on-device · human · noise | LibriSpeech reader 174 (M), babble10 [human: LibriSpeech 174, WER 34%, ASR lag 6.8 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.93/4.57 | 0.0 | ⚠️ report-only |
| apple-on-device · human · composite | LibriSpeech reader 174 (M), composite [human: LibriSpeech 174, WER 12%, ASR lag 5.4 s] | 0.00 | 0.0 | 0.0/0.0 | 0/2 | 0.3 | 0 | 0.56/1.93 | 0.0 | ✅ |
| apple-on-device · human · pauses | LibriSpeech reader 174 (M), pause [human: LibriSpeech 174, WER 5%, ASR lag 0.4 s] | 0.00 | 0.0 | 0.0/0.0 | 0/1 | 0.0 | 0 | 0.51/0.87 | 0.0 | ✅ |
| apple-on-device · human · repeated | LibriSpeech reader 174 (M), reread [human: LibriSpeech 174, WER 6%, ASR lag 0.5 s] | 0.00 | 0.0 | 0.0/0.0 | 0/1 | 0.0 | 0 | 0.50/0.82 | 1.0 | ✅ |
| apple-on-device · human · skips | LibriSpeech reader 174 (M), skip [human: LibriSpeech 174, WER 3%, ASR lag 0.4 s] | 0.00 | 0.0 | 0.1/0.1 | 0/1 | 0.0 | 0 | 0.50/0.76 | 0.0 | ✅ |
| apple-on-device · human · baseline | LibriSpeech reader 174 (M), straight [human: LibriSpeech 174, WER 5%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.52/0.82 | 0.0 | ✅ |
| apple-on-device · human · baseline | LibriSpeech reader 251 (M), straight [human: LibriSpeech 251, WER 6%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.54/0.80 | 0.0 | ✅ |
| apple-on-device · human · baseline | LibriSpeech reader 422 (M), straight [human: LibriSpeech 422, WER 9%, ASR lag 19.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.49/0.84 | 0.0 | ✅ |
| apple-on-device · human · noise | LibriSpeech reader 84 (F), babble10 [human: LibriSpeech 84, WER 21%, ASR lag 1.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.66/1.87 | 0.0 | ✅ |
| apple-on-device · human · composite | LibriSpeech reader 84 (F), composite [human: LibriSpeech 84, WER 13%, ASR lag 0.5 s] | 0.00 | 0.0 | 1.9/1.9 | 0/3 | 0.0 | 0 | 0.54/0.86 | 0.0 | ✅ |
| apple-on-device · human · pauses | LibriSpeech reader 84 (F), pause [human: LibriSpeech 84, WER 39%, ASR lag 0.4 s] | 0.00 | 0.0 | 0.0/0.0 | 0/1 | 0.0 | 0 | 0.49/0.83 | 0.0 | ✅ |
| apple-on-device · human · repeated | LibriSpeech reader 84 (F), reread [human: LibriSpeech 84, WER 36%, ASR lag 0.3 s] | 0.00 | 0.0 | 1.0/1.0 | 0/2 | 0.0 | 0 | 0.48/0.80 | 0.0 | ✅ |
| apple-on-device · human · skips | LibriSpeech reader 84 (F), skip [human: LibriSpeech 84, WER 78%, ASR lag 0.1 s] | 0.00 | 0.0 | 1.7/1.7 | 0/2 | 0.0 | 0 | 0.49/0.82 | 0.0 | ✅ |
| apple-on-device · human · baseline | LibriSpeech reader 84 (F), straight [human: LibriSpeech 84, WER 36%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.49/0.81 | 0.0 | ✅ |
| apple-on-device · human · noise | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), babble10 [human: Speechocean762 l2-0036, WER 16%, ASR lag 19.8 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.64/1.70 | 0.0 | ✅ |
| apple-on-device · human · composite | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), composite [human: Speechocean762 l2-0036, WER 11%, ASR lag 24.1 s] | 0.00 | 0.0 | 0.1/0.1 | 0/3 | 0.0 | 0 | 0.58/1.52 | 0.0 | ✅ |
| apple-on-device · human · pauses | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), pause [human: Speechocean762 l2-0036, WER 10%, ASR lag 4.2 s] | 0.00 | 0.0 | 0.1/0.1 | 0/1 | 0.0 | 0 | 0.53/1.25 | 0.0 | ✅ |
| apple-on-device · human · repeated | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), reread [human: Speechocean762 l2-0036, WER 12%, ASR lag 22.4 s] | 0.00 | 0.0 | 0.0/0.0 | 0/2 | 0.0 | 0 | 0.53/1.21 | 0.0 | ✅ |
| apple-on-device · human · skips | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), skip [human: Speechocean762 l2-0036, WER 10%, ASR lag 4.1 s] | 0.00 | 0.0 | 0.1/0.1 | 0/2 | 0.0 | 0 | 0.59/1.57 | 0.0 | ✅ |
| apple-on-device · human · baseline | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), straight [human: Speechocean762 l2-0036, WER 11%, ASR lag 20.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.51/1.12 | 0.0 | ✅ |
| apple-on-device · human · baseline | Speechocean762 speaker 0135 (Mandarin L1, F, age 20), straight [human: Speechocean762 l2-0135, WER 8%, ASR lag 10.9 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.55/0.98 | 0.0 | ✅ |
| apple-on-device · human · baseline | Speechocean762 speaker 0482 (Mandarin L1, M, age 28), straight [human: Speechocean762 l2-0482, WER 11%, ASR lag 0.6 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.59/2.07 | 1.0 | ✅ |
| apple-on-device · human · noise | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), babble10 [human: Speechocean762 l2-0560, WER 51%, ASR lag 2.4 s] | 7.07 | 6.8 | –/– | – | 0.0 | 0 | 1.17/5.62 | 0.0 | ⚠️ report-only |
| apple-on-device · human · composite | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), composite [human: Speechocean762 l2-0560, WER 52%, ASR lag 2.6 s] | 0.00 | 0.0 | 0.2/0.2 | 0/3 | 0.0 | 0 | 0.97/5.86 | 0.0 | ⚠️ report-only |
| apple-on-device · human · pauses | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), pause [human: Speechocean762 l2-0560, WER 37%, ASR lag 0.4 s] | 0.00 | 0.0 | 0.2/0.2 | 0/1 | 0.0 | 0 | 0.72/3.50 | 0.0 | ⚠️ report-only |
| apple-on-device · human · repeated | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), reread [human: Speechocean762 l2-0560, WER 42%, ASR lag 0.4 s] | 6.58 | 2.7 | 0.1/0.1 | 0/2 | 0.0 | 0 | 0.78/4.95 | 0.0 | ⚠️ report-only |
| apple-on-device · human · skips | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), skip [human: Speechocean762 l2-0560, WER 45%, ASR lag 0.4 s] | 0.00 | 0.0 | 0.0/0.0 | 0/2 | 0.0 | 0 | 0.73/4.00 | 7.0 | ⚠️ report-only |
| apple-on-device · human · baseline | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), straight [human: Speechocean762 l2-0560, WER 37%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.70/3.62 | 0.0 | ⚠️ report-only |
| apple-on-device · noise | 4-talker babble, 10 dB [Samantha, WER 7%, ASR lag 0.8 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.46/0.88 | 0.0 | ✅ |
| apple-on-device · noise | 4-talker babble, 5 dB [Samantha, WER 15%, ASR lag 0.6 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.57/1.57 | 0.0 | ✅ |
| apple-on-device · noise | HVAC rumble, 5 dB [Samantha, WER 4%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.45/0.79 | 0.0 | ✅ |
| apple-on-device · noise | competing talker (TV), 10 dB [Samantha, WER 5%, ASR lag 0.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.46/0.84 | 0.0 | ✅ |
| apple-on-device · noise | competing talker (TV), 5 dB [Samantha, WER 42%, ASR lag 0.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.48/0.84 | 0.0 | ✅ |
| apple-on-device · paraphrase | ad-lib 15 and 40 words [Samantha, WER 4%, ASR lag 0.1 s] | 0.00 | 0.0 | 0.2/0.2 | 0/2 | 0.0 | 0 | 0.43/0.75 | 0.0 | ✅ |
| apple-on-device · paraphrase | contractions, synonyms, fillers [Karen, WER 8%, ASR lag -0.6 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.45/0.95 | 1.0 | ✅ |
| apple-on-device · pauses | pauses 5 s, 20 s, 60 s [Samantha, WER 3%, ASR lag 22.1 s] | 0.00 | 0.0 | 0.1/0.1 | 0/3 | 0.0 | 0 | 0.43/0.75 | 0.0 | ✅ |
| apple-on-device · repeated | refrains + restart sentence ×3 [Daniel, WER 3%, ASR lag 0.5 s] | 0.00 | 0.0 | 1.0/1.0 | 0/3 | 0.0 | 0 | 0.43/0.69 | 0.0 | ✅ |
| apple-on-device · repeated | re-read 12 words ×2, jump back 30 [Samantha, WER 5%, ASR lag 0.2 s] | 0.00 | 0.0 | 1.9/1.9 | 0/3 | 0.0 | 0 | 0.43/0.74 | 0.0 | ✅ |
| apple-on-device · skips | skip 10, 25, 60 words [Rishi, WER 3%, ASR lag 0.2 s] | 0.00 | 0.0 | 2.1/2.1 | 0/3 | 0.0 | 0 | 0.48/0.80 | 0.0 | ✅ |
| apple-on-device · speed | 130 wpm [Samantha, WER 4%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.46/0.74 | 0.0 | ✅ |
| apple-on-device · speed | 230 wpm [Samantha, WER 5%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.45/0.74 | 0.0 | ✅ |
| apple-on-device · technical | jargon, app's contextual hints on [Samantha, WER 13%, ASR lag -0.0 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.40/0.98 | 0.0 | ✅ |
| apple-on-device · technical | jargon, no hints [Samantha, WER 16%, ASR lag -0.2 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.41/1.01 | 0.0 | ✅ |
| apple-server-en-AU · accent | Australian English (Karen) [Karen, WER 3%, ASR lag 0.7 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.53/0.88 | 0.0 | ✅ |
| apple-server-en-CA · noise | 4-talker babble, 10 dB [Samantha, WER 9%, ASR lag 0.9 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.60/1.02 | 0.0 | ✅ |
| apple-server-en-CA · noise | competing talker (TV), 10 dB [Samantha, WER 4%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.57/0.88 | 0.0 | ✅ |
| apple-server-en-CA · repeated | re-read 12 words ×2, jump back 30 [Samantha, WER 5%, ASR lag 0.7 s] | 0.00 | 0.0 | 2.4/2.4 | 0/3 | 0.0 | 0 | 0.50/0.82 | 0.0 | ✅ |
| apple-server-en-GB · accent | UK English (Daniel) [Daniel, WER 6%, ASR lag 0.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.54/0.87 | 0.0 | ✅ |
| apple-server-en-GB · baseline | clean read, US voice [Samantha, WER 4%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.54/0.85 | 0.0 | ✅ |
| apple-server-en-IE · accent | Irish English (Moira) [Moira, WER 5%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.55/0.98 | 0.0 | ✅ |
| apple-server-en-IN · accent | Indian English (Rishi) [Rishi, WER 4%, ASR lag 0.7 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.56/0.86 | 0.0 | ✅ |
| apple-server-en-IN · accent | Indian English (Tara) [Tara, WER 6%, ASR lag 0.8 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.51/0.92 | 0.0 | ✅ |
| apple-server-en-NZ · paraphrase | ad-lib 15 and 40 words [Samantha, WER 4%, ASR lag 0.7 s] | 0.00 | 0.0 | 0.2/0.2 | 0/2 | 0.0 | 0 | 0.55/0.87 | 0.0 | ✅ |
| apple-server-en-NZ · pauses | pauses 5 s, 20 s, 60 s [Samantha, WER 4%, ASR lag 0.3 s] | 0.00 | 0.0 | 0.1/0.1 | 0/3 | 0.0 | 0 | 0.49/0.83 | 0.0 | ✅ |
| apple-server-en-SG · skips | skip 10, 25, 60 words [Rishi, WER 4%, ASR lag 0.9 s] | 0.00 | 0.0 | 2.1/2.1 | 0/3 | 0.0 | 0 | 0.61/0.97 | 0.0 | ✅ |
| apple-server-en-SG · technical | jargon, app's contextual hints on [Samantha, WER 24%, ASR lag -0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.49/1.15 | 0.0 | ✅ |
| apple-server-en-ZA · accent | South African English (Tessa) [Tessa, WER 5%, ASR lag 0.5 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.59/0.95 | 0.0 | ✅ |
| local-canary · accent | UK English (Daniel) [Daniel, rolling window: WER n/a] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.45/1.15 | 0.0 | ✅ |
| local-canary · accent | Indian English (Rishi) [Rishi, rolling window: WER n/a] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.53/1.19 | 0.0 | ✅ |
| local-canary · accent (non-native proxy) | French voice reading English [Thomas, rolling window: WER n/a] | 23.03 | 17.0 | –/– | – | 0.0 | 0 | 1.21/6.35 | 0.0 | ⚠️ report-only |
| local-canary · accent (non-native proxy) | German voice reading English [Anna, rolling window: WER n/a] | 5.91 | 2.2 | –/– | – | 0.0 | 0 | 1.11/3.24 | 0.0 | ⚠️ report-only |
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
| local-nemotron · accent (non-native proxy) | French voice reading English [Thomas, WER 58%, ASR lag 11.8 s] | 11.51 | 6.0 | –/– | – | 0.0 | 0 | 0.87/3.75 | 0.0 | ⚠️ report-only |
| local-nemotron · accent (non-native proxy) | German voice reading English [Anna, WER 53%, ASR lag 17.2 s] | 17.74 | 8.9 | –/– | – | 0.0 | 0 | 0.91/4.07 | 9.0 | ⚠️ report-only |
| local-nemotron · accent (non-native proxy) | Mandarin voice reading English [Tingting, WER 2%, ASR lag 0.1 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.40/0.93 | 0.0 | ✅ |
| local-nemotron · accent (non-native proxy) | Spanish voice reading English [Mónica, WER 0%, ASR lag 0.1 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.34/0.76 | 0.0 | ✅ |
| local-nemotron · baseline | clean read, US voice [Samantha, WER 0%, ASR lag 0.1 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.33/0.73 | 0.0 | ✅ |
| local-nemotron · composite | realistic take, UK voice, babble 15 dB [Daniel, WER 3%, ASR lag 0.6 s] | 0.00 | 0.0 | 0.2/0.8 | 0/4 | 0.0 | 0 | 0.38/0.86 | 0.0 | ✅ |
| local-nemotron · human · baseline | LibriSpeech reader 1462 (F), straight [human: LibriSpeech 1462, WER 4%, ASR lag 0.6 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.43/0.78 | 0.0 | ✅ |
| local-nemotron · human · baseline | LibriSpeech reader 1673 (F), straight [human: LibriSpeech 1673, WER 0%, ASR lag 0.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.44/0.80 | 0.0 | ✅ |
| local-nemotron · human · noise | LibriSpeech reader 174 (M), babble10 [human: LibriSpeech 174, WER 3%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.52/0.90 | 0.0 | ✅ |
| local-nemotron · human · composite | LibriSpeech reader 174 (M), composite [human: LibriSpeech 174, WER 0%, ASR lag 0.3 s] | 0.00 | 0.0 | 0.0/0.0 | 0/2 | 0.0 | 0 | 0.45/0.81 | 0.0 | ✅ |
| local-nemotron · human · pauses | LibriSpeech reader 174 (M), pause [human: LibriSpeech 174, WER 1%, ASR lag 0.3 s] | 0.00 | 0.0 | 0.0/0.0 | 0/1 | 0.0 | 0 | 0.42/0.81 | 0.0 | ✅ |
| local-nemotron · human · repeated | LibriSpeech reader 174 (M), reread [human: LibriSpeech 174, WER 0%, ASR lag 0.3 s] | 0.00 | 0.0 | 0.0/0.0 | 0/1 | 0.0 | 0 | 0.44/0.81 | 0.0 | ✅ |
| local-nemotron · human · skips | LibriSpeech reader 174 (M), skip [human: LibriSpeech 174, WER 0%, ASR lag 0.2 s] | 0.00 | 0.0 | 0.1/0.1 | 0/1 | 0.0 | 0 | 0.37/0.72 | 0.0 | ✅ |
| local-nemotron · human · baseline | LibriSpeech reader 174 (M), straight [human: LibriSpeech 174, WER 1%, ASR lag 0.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.39/0.79 | 0.0 | ✅ |
| local-nemotron · human · baseline | LibriSpeech reader 251 (M), straight [human: LibriSpeech 251, WER 4%, ASR lag 0.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.44/0.94 | 0.0 | ✅ |
| local-nemotron · human · baseline | LibriSpeech reader 422 (M), straight [human: LibriSpeech 422, WER 1%, ASR lag -0.1 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.42/0.82 | 0.0 | ✅ |
| local-nemotron · human · noise | LibriSpeech reader 84 (F), babble10 [human: LibriSpeech 84, WER 8%, ASR lag 0.7 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.49/0.91 | 0.0 | ✅ |
| local-nemotron · human · composite | LibriSpeech reader 84 (F), composite [human: LibriSpeech 84, WER 6%, ASR lag 0.8 s] | 0.00 | 0.0 | 1.4/1.4 | 0/3 | 0.0 | 0 | 0.46/0.88 | 0.0 | ✅ |
| local-nemotron · human · pauses | LibriSpeech reader 84 (F), pause [human: LibriSpeech 84, WER 4%, ASR lag 0.3 s] | 0.00 | 0.0 | 0.0/0.0 | 0/1 | 0.0 | 0 | 0.43/0.81 | 0.0 | ✅ |
| local-nemotron · human · repeated | LibriSpeech reader 84 (F), reread [human: LibriSpeech 84, WER 5%, ASR lag 0.3 s] | 0.00 | 0.0 | 1.0/1.0 | 0/2 | 0.0 | 0 | 0.45/0.79 | 0.0 | ✅ |
| local-nemotron · human · skips | LibriSpeech reader 84 (F), skip [human: LibriSpeech 84, WER 5%, ASR lag 0.3 s] | 0.00 | 0.0 | 2.5/2.5 | 0/2 | 0.0 | 0 | 0.47/0.81 | 0.0 | ✅ |
| local-nemotron · human · baseline | LibriSpeech reader 84 (F), straight [human: LibriSpeech 84, WER 4%, ASR lag 0.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.44/0.81 | 0.0 | ✅ |
| local-nemotron · human · noise | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), babble10 [human: Speechocean762 l2-0036, WER 12%, ASR lag 0.7 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.67/2.86 | 1.0 | ✅ |
| local-nemotron · human · composite | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), composite [human: Speechocean762 l2-0036, WER 13%, ASR lag 0.2 s] | 0.00 | 0.0 | 0.1/0.1 | 0/3 | 0.0 | 0 | 0.65/1.88 | 1.0 | ✅ |
| local-nemotron · human · pauses | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), pause [human: Speechocean762 l2-0036, WER 12%, ASR lag 0.3 s] | 0.00 | 0.0 | 0.1/0.1 | 0/1 | 0.0 | 0 | 0.66/1.47 | 0.0 | ✅ |
| local-nemotron · human · repeated | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), reread [human: Speechocean762 l2-0036, WER 10%, ASR lag 0.3 s] | 0.00 | 0.0 | 0.0/0.0 | 0/2 | 0.0 | 0 | 0.63/1.45 | 0.0 | ✅ |
| local-nemotron · human · skips | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), skip [human: Speechocean762 l2-0036, WER 12%, ASR lag 0.3 s] | 0.00 | 0.0 | 0.1/0.1 | 0/2 | 0.0 | 0 | 0.68/1.88 | 0.0 | ✅ |
| local-nemotron · human · baseline | Speechocean762 speaker 0036 (Mandarin L1, F, age 21), straight [human: Speechocean762 l2-0036, WER 8%, ASR lag 0.4 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.62/2.36 | 0.0 | ✅ |
| local-nemotron · human · baseline | Speechocean762 speaker 0135 (Mandarin L1, F, age 20), straight [human: Speechocean762 l2-0135, WER 6%, ASR lag 0.9 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.60/1.02 | 0.0 | ✅ |
| local-nemotron · human · baseline | Speechocean762 speaker 0482 (Mandarin L1, M, age 28), straight [human: Speechocean762 l2-0482, WER 11%, ASR lag 0.1 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.59/1.27 | 0.0 | ✅ |
| local-nemotron · human · noise | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), babble10 [human: Speechocean762 l2-0560, WER 37%, ASR lag 5.0 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.95/3.44 | 0.0 | ⚠️ report-only |
| local-nemotron · human · composite | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), composite [human: Speechocean762 l2-0560, WER 31%, ASR lag 2.6 s] | 6.27 | 3.7 | 0.2/0.2 | 0/3 | 1.3 | 0 | 0.83/3.30 | 0.0 | ⚠️ report-only |
| local-nemotron · human · pauses | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), pause [human: Speechocean762 l2-0560, WER 30%, ASR lag 1.9 s] | 0.00 | 0.0 | 0.2/0.2 | 0/1 | 0.0 | 0 | 0.83/3.15 | 0.0 | ⚠️ report-only |
| local-nemotron · human · repeated | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), reread [human: Speechocean762 l2-0560, WER 29%, ASR lag 0.2 s] | 0.00 | 0.0 | 0.1/0.1 | 0/2 | 0.0 | 0 | 0.81/3.19 | 0.0 | ⚠️ report-only |
| local-nemotron · human · skips | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), skip [human: Speechocean762 l2-0560, WER 24%, ASR lag 0.4 s] | 8.67 | 3.6 | 0.0/0.0 | 0/2 | 0.0 | 0 | 0.86/3.41 | 0.0 | ⚠️ report-only |
| local-nemotron · human · baseline | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), straight [human: Speechocean762 l2-0560, WER 28%, ASR lag 1.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.91/3.65 | 0.0 | ⚠️ report-only |
| local-nemotron · noise | 4-talker babble, 10 dB [Samantha, WER 3%, ASR lag 0.0 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.40/0.84 | 0.0 | ✅ |
| local-nemotron · noise | competing talker (TV), 10 dB [Samantha, WER 2%, ASR lag 0.3 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.38/0.76 | 0.0 | ✅ |
| local-nemotron · paraphrase | ad-lib 15 and 40 words [Samantha, WER 0%, ASR lag 0.1 s] | 0.00 | 0.0 | 0.1/0.1 | 0/2 | 0.0 | 0 | 0.34/0.76 | 0.0 | ✅ |
| local-nemotron · pauses | pauses 5 s, 20 s, 60 s [Samantha, WER 1%, ASR lag 0.1 s] | 0.00 | 0.0 | 0.1/0.1 | 0/3 | 0.0 | 0 | 0.37/0.82 | 0.0 | ✅ |
| local-nemotron · repeated | re-read 12 words ×2, jump back 30 [Samantha, WER 0%, ASR lag 0.1 s] | 0.00 | 0.0 | 1.9/1.9 | 0/3 | 0.0 | 0 | 0.35/0.80 | 0.0 | ✅ |
| local-nemotron · skips | skip 10, 25, 60 words [Rishi, WER 1%, ASR lag 0.2 s] | 0.00 | 0.0 | 2.1/2.1 | 0/3 | 0.0 | 0 | 0.39/0.84 | 0.0 | ✅ |
| local-nemotron · technical | jargon, app's contextual hints on [Samantha, WER 14%, ASR lag 0.7 s] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.30/1.02 | 0.0 | ✅ |
| local-qwen3 · human · noise | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), babble10 [human: Speechocean762 l2-0560, rolling window: WER n/a] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 1.17/2.95 | 0.0 | ✅ |
| local-qwen3 · human · composite | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), composite [human: Speechocean762 l2-0560, rolling window: WER n/a] | 0.00 | 0.0 | 0.2/0.2 | 0/3 | 1.3 | 0 | 1.25/3.55 | 0.0 | ⚠️ report-only |
| local-qwen3 · human · pauses | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), pause [human: Speechocean762 l2-0560, rolling window: WER n/a] | 0.00 | 0.0 | 0.2/0.2 | 0/1 | 0.0 | 0 | 1.04/2.43 | 0.0 | ✅ |
| local-qwen3 · human · repeated | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), reread [human: Speechocean762 l2-0560, rolling window: WER n/a] | 0.00 | 0.0 | 0.1/0.1 | 0/2 | 0.0 | 0 | 1.11/2.19 | 0.0 | ✅ |
| local-qwen3 · human · skips | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), skip [human: Speechocean762 l2-0560, rolling window: WER n/a] | 0.00 | 0.0 | 0.0/0.0 | 0/2 | 0.0 | 0 | 1.07/2.26 | 0.0 | ✅ |
| local-qwen3 · human · baseline | Speechocean762 speaker 0560 (Mandarin L1, M, age 23), straight [human: Speechocean762 l2-0560, rolling window: WER n/a] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 1.01/2.19 | 0.0 | ✅ |
| local-whisper-tiny-q8-0 · baseline | clean read, US voice [Samantha, rolling window: WER n/a] | 0.00 | 0.0 | –/– | – | 0.0 | 0 | 0.81/1.64 | 0.0 | ⚠️ report-only |

Layer B (synthetic voices → real recognizers, real audio, one take per case per engine). Matcher: current

108/108 gating cases pass the launch bar (PLAN.md §8); 28 report-only.

