# Human-reader scripts

Transcripts of real people reading, used by `bench human-corpus` (Sources/bench/Corpus.swift) to
benchmark tracking on human voices. Audio isn't stored here; fixtures hold only recognizer output
and auto-aligned word timings.

- `librispeech-*.txt`: six LibriSpeech dev-clean speakers (84, 174, 251, 422, 1462, 1673; the first
  three female and three male by id), native English audiobook readers.
  Vassil Panayotov, Guoguo Chen, Daniel Povey, Sanjeev Khudanpur, "LibriSpeech: an ASR corpus based on
  public domain audio books", ICASSP 2015. CC BY 4.0, https://www.openslr.org/12
- `speechocean-l2-*.txt`: four adult (≥20) Mandarin-L1 speakers reading English (two female, two male,
  first by id in the train split): real non-native accents.
  Junbo Zhang et al., "speechocean762: An Open-Source Non-native English Speech Corpus For
  Pronunciation Assessment", Interspeech 2021. CC BY 4.0, https://www.openslr.org/101

To rebuild:

    curl -O https://www.openslr.org/resources/12/dev-clean.tar.gz && tar xzf dev-clean.tar.gz
    curl -O https://www.openslr.org/resources/101/speechocean762.tar.gz && tar xzf speechocean762.tar.gz
    .build/release/bench human-corpus . LibriSpeech/dev-clean apple-on-device
    .build/release/bench human-corpus . speechocean762 apple-on-device
