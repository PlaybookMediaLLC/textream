# Dante for Creators

**Smart Voice-Following Teleprompter for macOS, iPhone, and iPad**  
Published by **Playbook Interactive Media LLC** (Universal Purchase · Bundle ID `com.playbookinteractivemediallc.app`)

---

## Highlights

- **Smart Follow Speech Tracking (`Textream/Shared/PromptMatcher.swift`):** Streaming Smith–Waterman local alignment with bidirectional skip/re-read recovery, contraction and number normalization, refrain protection, and quiet-gap restarts.
- **Hardware-Aware On-Device AI Speech Models (macOS):** Optional 100% offline transcription via `TranscribeCpp` with curated Hugging Face GGUF models (*Best Live Streaming:* Nemotron 3.5 ASR Streaming 0.6B, *Best for Strong Accents:* Qwen3-ASR 1.7B, *Fastest Low-Memory:* Canary 180M Flash), SHA-256 checksum verification, backup exclusion, RAM headroom warnings, and Intel compatibility notices.
- **Creator Script Library & WPM Read-Time Estimator (`Textream/Shared/ScriptLibrary.swift`):** Create, search, pin, rename, duplicate, and organize multi-page scripts with live spoken word counts (ignoring `[stage cues]`) and estimated read durations.
- **Creator Format Presets (`Textream/Shared/CreatorPreset.swift`):** One-tap configurations for **YouTube Studio**, **Shorts / Reels / TikTok** (with 60-second duration badge), **Podcast / Interview**, and **Keynote / Live Stream**.
- **Pro Display & Studio Rig Support:** MacBook notch overlay, floating glass window, fullscreen, hide from screen sharing, external/Sidecar mirror rigs, in-process `.pptx` speaker-notes import, `.dante` files, `dante://` URL scheme, macOS Services, and LAN Remote/Director web servers.
- **iPhone & iPad Camera Capture:** Presenter-only translucent overlay beside the lens (never burned into exported video), add-only Photos saving, saved-recordings gallery with native trim/edit, and landscape mirror mode.

---

## Building & Testing (Xcode 26.1.1+)

- **macOS (`Textream` scheme, `AppStore` archive configuration):** Universal `arm64 + x86_64`, macOS 15.0+, App Sandbox + Hardened Runtime enabled.
- **iOS / iPadOS (`TextreamiOS` scheme, `AppStore` archive configuration):** iOS 26.0+ (iPhone & iPad). Future iOS 27.1/27.2 dual-display APIs are gated behind `#if DANTE_ENABLE_IOS27_DUO`.
- **Unit Tests:** Run `TextreamTests` (macOS) and `TextreamiOSTests` (iOS Simulator).
- **Speech-Tracking Benchmark Gate:** `cd benchmarks/speech-tracking && go run run.go -check`
- **Desktop Performance Suite:** `cd benchmarks/desktop && go run run.go micro`

---

## App Store Release Automation

See [docs/APP_STORE_REVIEW_NOTES.md](docs/APP_STORE_REVIEW_NOTES.md) for App Store Connect metadata, MIT differentiation notes, entitlement justifications, and the reviewer test script.

```bash
export DANTE_TEAM_ID="<PLAYBOOK_INTERACTIVE_MEDIA_TEAM_ID>"
export ASC_KEY_ID="<ASC_KEY_ID>"
export ASC_ISSUER_ID="<ASC_ISSUER_ID>"
export ASC_KEY_PATH="/path/to/AuthKey.p8"

fastlane mac release
fastlane ios release
```

Both lanes use `automatic_release: false` (Manual Release) so macOS and iOS can be released synchronously as a Universal Purchase.

---

## License & Acknowledgements

Copyright © 2026 Playbook Interactive Media LLC.

Dante for Creators incorporates open-source foundations from MIT-licensed **Textream** (`Copyright (c) 2026 Fatih Kadir Akin`; original idea by Semih Kışlar — see [LICENSE](LICENSE)), **OpenDyslexic 3** (SIL Open Font License 1.1), and **TranscribeCpp / ggml / miniz** (MIT License). Full open-source licenses and speech model attributions are displayed inside both apps under **Acknowledgements**.
