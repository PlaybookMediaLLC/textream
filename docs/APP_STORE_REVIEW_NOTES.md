# App Store Connect Submission & Review Kit — **Dante for Creators**

**Publisher:** Playbook Interactive Media LLC (Apple Developer Team `T44K9669GA` — D Yoan L Mekontchou Yomba individual account)  
**Bundle Identifier (Universal macOS + iOS + iPadOS):** `com.playbookinteractivemediallc.app`  
**Version / Build:** `1.0.0 (1)`  
**Monetization:** Paid Upfront (Universal Purchase; zero IAP / zero external donate links)

---

## 1. App Store Listing Metadata

- **App Name (18/30 chars):** `Dante for Creators`
- **iOS Home Screen Display Name:** `Dante`
- **Subtitle (24/30 chars):** `Smart Voice Teleprompter`
- **Primary Category:** `Photo & Video`
- **Secondary Category:** `Productivity`
- **Age Rating:** `4+`
- **Export Compliance:** `ITSAppUsesNonExemptEncryption = NO` (standard HTTPS / OS encryption only)
- **App Privacy Nutrition Label:** **Data Not Collected** (zero analytics, zero tracking, zero user accounts)
- **Privacy Policy URL:** `https://playbookmediallc.github.io/textream/privacy.html` *(update to final custom Playbook Interactive Media LLC domain if provisioned)*
- **Support URL:** `https://playbookmediallc.github.io/textream/support.html`

### Promotional Text (170 chars)
> Stay locked to the lens. Smart Follow tracks your voice through pauses, ad-libs, and re-reads—with offline AI speech models on Mac and camera capture on iPhone & iPad.

### Keywords (100 chars)
> teleprompter,autocue,youtube,creator,script,prompter,video,voice,speech,podcast,camera,mirror,notch

### Description
Dante for Creators is a studio-grade teleprompter built for YouTubers, podcasters, educators, and speakers across Mac, iPhone, and iPad—available together as a single Universal Purchase.

**SMART FOLLOW SPEECH TRACKING**
Speak like a human, not a robot. Dante’s streaming Smith–Waterman speech matcher follows your words in real time and automatically recovers when you pause, ad-lib an unscripted thought, skip ahead, or re-read a sentence.

**OPTIONAL 100% OFFLINE AI SPEECH MODELS (MACOS)**
Choose Apple Speech for instant setup or download open-weight on-device speech models (including Nemotron 3.5 Streaming, Qwen3-ASR 1.7B, Parakeet, and Canary 180M Flash) directly onto Apple Silicon Macs so your voice audio never leaves your device.

**BUILT FOR CREATOR WORKFLOWS**
• **Creator Script Library:** Create, search, pin, duplicate, and organize multi-page scripts with live spoken word counts and WPM read-time estimation.
• **Creator Format Presets:** One-tap setups for YouTube Studio (150 WPM), Shorts / Reels / TikTok (60-second duration guide), Podcast / Interview, and Keynote / Live Stream.
• **Stage Directions:** Put cues like `[smile]` or `[pause]` in brackets—Dante displays them clearly while skipping them during voice tracking.

**PRO DISPLAY & STUDIO RIG SUPPORT**
• **Mac Overlays:** Pin cleanly below your MacBook notch, float anywhere with translucent glass, go fullscreen, or hide from screen sharing during live calls and tutorials.
• **External & Mirror Rigs:** Output to an external monitor or Sidecar iPad with Horizontal, Vertical, or 180° flip for glass teleprompter rigs.
• **iPhone & iPad Camera Recording:** Record full-screen video while your script floats right beside the lens—presenter-only overlays never appear in the exported video saved to Photos.
• **LAN Remote & Director Mode:** Monitor on a tablet or let a producer push live script edits from a browser on the same Wi-Fi network.
• **PowerPoint Import:** Drop `.pptx` files on Mac to extract presenter notes directly into multi-page scripts.

**PRIVATE BY DESIGN**
No accounts. No subscriptions. No ads or analytics. Your scripts and recordings remain on your devices.

---

## 2. App Review Notes (Paste Verbatim into App Store Connect)

> **1. Open-Source MIT Heritage & Substantive Differentiation (Guideline 4.3)**  
> Dante for Creators incorporates open-source teleprompter foundations from the MIT-licensed Textream project, with complete copyright and license attribution included in-app under **About → Licenses** / **Settings → Acknowledgements** (macOS) and **Settings → Acknowledgements** (iOS/iPadOS).  
>
> Dante for Creators is a substantially engineered, distinct product built by Playbook Interactive Media LLC featuring:
> - A rebuilt streaming Smith–Waterman speech-alignment engine (`Smart Follow`) with bidirectional skip/re-read recovery, contraction/number normalization, and quiet-gap restarts.
> - Hardware-aware on-device neural ASR on macOS (`TranscribeCpp`) with benchmark-guided model badges, RAM headroom advisories, SHA-256 checksum verification, and Intel architecture awareness.
> - A dedicated **Creator Script Library** (search, pinning, multi-page scripts, live spoken word count & WPM read-time estimator with 60-second Shorts/Reels target indicators).
> - One-tap **Creator Format Presets** (YouTube Studio, Shorts / Reels / TikTok, Podcast / Interview, Keynote / Live Stream).
> - Guided first-run Creator Onboarding with transparent permission priming, original visual design system and app iconography, and pure in-process `.pptx` speaker-notes extraction (no subprocesses).
>
> **2. macOS App Sandbox Entitlement Justifications**
> - `com.apple.security.network.server`: Powers opt-in LAN-only **Remote Connection** (default port 7373) and **Director Mode** (default port 7575) so creators can view or control scripts from a tablet or producer’s browser on the same local Wi-Fi network. Disabled by default.
> - `com.apple.security.network.client`: Used solely when the user explicitly chooses to download optional open-weight GGUF speech recognition model data files (non-executable weights verified via SHA-256) from public Hugging Face repositories for offline transcription.
> - `com.apple.security.device.audio-input`: Microphone capture for Smart Follow (Word Tracking), Voice-Activated scrolling, and dictation.
> - `com.apple.security.files.user-selected.read-write`: Standard NSOpenPanel / NSSavePanel access to open/save `.dante` scripts and import `.pptx` presenter notes.
>
> **3. Quick Reviewer Test Script (5 Steps)**
> 1. **Onboarding & Presets:** Launch Dante for Creators. Step through the Creator Setup sheet, select a preset (e.g., *YouTube Studio* or *Shorts / Reels*), and confirm the main editor opens with the Creator Script Library and live WPM read-time estimator.
> 2. **Classic Mode (No Microphone Needed):** Open **Settings → Guidance** (macOS) or tap **Auto** (iOS), select **Classic**, and start the prompter to verify smooth auto-scrolling without granting microphone permissions.
> 3. **Smart Follow (Word Tracking):** Switch back to **Word Tracking**, grant Microphone & Speech Recognition, and read the welcome script aloud—pause, skip a sentence, or re-read a line to verify automatic recovery.
> 4. **On-Device Local AI Model (macOS Apple Silicon):** Open **Settings → Guidance → Local Model → Manage Models**, download **Canary 180M Flash** (~208 MB, fastest/smallest recommended model), select it, and click **Test Guidance** to verify offline transcription.
> 5. **Camera Recording & Photos Save (iOS / iPadOS):** Switch to **Record** mode, grant Camera, Microphone, and Photos add-only access, record a short clip while reading the floating script, stop recording, and confirm the saved video in Photos does **not** include the teleprompter text overlay.

---

## 3. Pre-Submission Operational Checklist

- [x] Configure Apple Developer Team ID (`DEVELOPMENT_TEAM = T44K9669GA`, `XCODE_DEVELOPMENT_TEAM = T44K9669GA`, D Yoan L Mekontchou Yomba individual account) across Xcode targets and `fastlane/Fastfile`.
- [ ] Complete the **Paid Applications Agreement**, W-9 tax forms, and banking in App Store Connect → Business.
- [ ] Verify explicit App ID `com.playbookinteractivemediallc.app` and Universal Purchase app record **`Dante for Creators`** in App Store Connect (macOS + iOS).
- [ ] Archive macOS (`AppStore` configuration) and upload to internal TestFlight to validate `CTranscribe.framework` re-signing, `Info.plist`, and `PrivacyInfo.xcprivacy` (`ITMS-91053` / `ITMS-90208` / `ITMS-90685`).
- [ ] Run `cd benchmarks/speech-tracking && go run run.go -check` (37/37 Layer A + 108/108 Layer B) and run all `TextreamTests` + `TextreamiOSTests` on Xcode 26.1.1+.
- [ ] Capture final macOS (2880×1800), iPhone (6.9"), and iPad (13") App Store screenshots.
- [ ] Submit both macOS 1.0.0 and iOS 1.0.0 with **Manual Release** enabled (`automatic_release: false` in `fastlane/Fastfile`) and release synchronously once both are approved.
