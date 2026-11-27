# [1.3.0](https://github.com/PlaybookMediaLLC/textream/compare/v1.2.0...v1.3.0) (2026-11-27)


### Features

* **retake:** add smart retake recovery and sentence rewind ([#11](https://github.com/PlaybookMediaLLC/textream/issues/11)) ([bdd59da](https://github.com/PlaybookMediaLLC/textream/commit/bdd59da7f3b9ef95929787a27aaf438371061178))

# [1.2.0](https://github.com/PlaybookMediaLLC/textream/compare/v1.1.0...v1.2.0) (2026-11-27)


### Features

* **ui:** studio redesign for snapped-to-notch and floating teleprompter overlays ([#10](https://github.com/PlaybookMediaLLC/textream/issues/10)) ([c655151](https://github.com/PlaybookMediaLLC/textream/commit/c655151754fe4da4a4ebd5f811ba7faf387ea748))

# [1.1.0](https://github.com/PlaybookMediaLLC/textream/compare/v1.0.0...v1.1.0) (2026-11-27)


### Bug Fixes

* **ui:** simplify ContentView body for Xcode 16 type-checker and deflake iOS classic timer test ([ec985fa](https://github.com/PlaybookMediaLLC/textream/commit/ec985fa121c22e602548a05bcadd6734b5dc6da2))


### Features

* **ui:** minimalist studio workspace with Dark & Light mode across macOS and iOS ([c41234b](https://github.com/PlaybookMediaLLC/textream/commit/c41234b7424f50e9b69507124eb23b6703ba0f9b)), closes [#3B5FEF](https://github.com/PlaybookMediaLLC/textream/issues/3B5FEF) [#456AF6](https://github.com/PlaybookMediaLLC/textream/issues/456AF6)

# 1.0.0 (2026-11-27)


### Bug Fixes

* add session token auth and connection limit to DirectorServer ([3b8eabc](https://github.com/PlaybookMediaLLC/textream/commit/3b8eabcc89d93e55f17b5898830a8ad290c17795))
* always show page sidebar and read current page on play ([248f232](https://github.com/PlaybookMediaLLC/textream/commit/248f23236ba33f997835a222d7ed7d6cfc15833b))
* broadcast only to authenticated connections after merge conflict resolution ([53bc99b](https://github.com/PlaybookMediaLLC/textream/commit/53bc99b6c6a89070777fff26e3b3eff936564ddb))
* **ci:** update git push command in release workflow ([4ad542b](https://github.com/PlaybookMediaLLC/textream/commit/4ad542bcfffe502524b162645d2d9d70960931d9))
* downmix multi-channel audio to mono for SFSpeechRecognizer ([fcaa54c](https://github.com/PlaybookMediaLLC/textream/commit/fcaa54c4cbff9f7940dcec7c83c1f116e55c590f))
* enforce connection limit, offload broadcast to background queue, add state-change debounce to prevent DoS (CWE-400) ([a1551f7](https://github.com/PlaybookMediaLLC/textream/commit/a1551f7a89920f3babe2bf83d88f6dc6c42efb41))
* generate auditable Homebrew cask URLs ([1ec7a78](https://github.com/PlaybookMediaLLC/textream/commit/1ec7a78efbb1baade9815fabb0e6fc3cb51aaa20))
* harden jump anchor and retry paths against lifecycle races ([de4e891](https://github.com/PlaybookMediaLLC/textream/commit/de4e891bedf15246cd8dc17a39ff16be145933ef))
* **ios:** keep speech progress out of unread cue-adjacent text ([3ffebf2](https://github.com/PlaybookMediaLLC/textream/commit/3ffebf2feae162de90d43ef0d52c8aa817b0a0ec))
* **ios:** preserve Hangul prompt reading units ([bfc3f55](https://github.com/PlaybookMediaLLC/textream/commit/bfc3f550548750ea991f76e08dd0882cafbc73ff))
* keep mouse-follow overlays within screen bounds ([75822e2](https://github.com/PlaybookMediaLLC/textream/commit/75822e239d31558aa7a43e26503988c0720feb00))
* keep recognition alive across jumps so tracking resumes instantly ([79bbc47](https://github.com/PlaybookMediaLLC/textream/commit/79bbc47d6d92b55241686744b1a338c590120800))
* **macos:** preserve Korean prompt spacing and cue boundaries ([59dba31](https://github.com/PlaybookMediaLLC/textream/commit/59dba3113f96e6c983c1d73400638a25e153d5ab))
* make PPTX import sandbox-safe ([befbdbb](https://github.com/PlaybookMediaLLC/textream/commit/befbdbbf710ceb889aa0d52261b9a4c92aadd64d))
* **notchoverlaycontroller:** fix cursor tracking and status bar item handling ([360fc09](https://github.com/PlaybookMediaLLC/textream/commit/360fc096dbe4931ea6d537e34adf2bb788af8573))
* responsive word highlighting and microphone-only voice-activated mode ([b83e18e](https://github.com/PlaybookMediaLLC/textream/commit/b83e18e0a941fdf09e4d6ca6e3533f649b8a079c))
* retry when the speech recognizer is transiently unavailable ([5f4f94f](https://github.com/PlaybookMediaLLC/textream/commit/5f4f94f2a48878899213aa33a03ce8719bc2e560))
* RTL text rendering for Arabic, Hebrew, and other right-to-left scripts ([#63](https://github.com/PlaybookMediaLLC/textream/issues/63)) ([ce11831](https://github.com/PlaybookMediaLLC/textream/commit/ce1183100f78926fd611a0d10af92e3fc256c9c4))
* start playback from selected page and install key monitor in pinned mode ([a399fc3](https://github.com/PlaybookMediaLLC/textream/commit/a399fc33298d367428491647b2159a9c7e243aa6))
* support macOS 15.0 ([#78](https://github.com/PlaybookMediaLLC/textream/issues/78)) ([37d323a](https://github.com/PlaybookMediaLLC/textream/commit/37d323abc350a9faa35f54b2e4e69e3037008ac2))
* **Textream:** Fix speech recognition state reset logic in MarqueeTextView and NotchOverlayController ([f6e14b9](https://github.com/PlaybookMediaLLC/textream/commit/f6e14b9801adaf112ffad1224fd295f2d7c29f61))
* **ui:** Fix conditional rendering issue for pill component ([83cc159](https://github.com/PlaybookMediaLLC/textream/commit/83cc159c8c12ce053d011bfc71485953f02e1e6c))
* voice tracking highlight and mic stall bugs in word tracking mode ([29b203e](https://github.com/PlaybookMediaLLC/textream/commit/29b203e941acc65a872b18d6ca760a3bb4fc340f))


### Features

* add cue color and brightness settings for annotation text ([6f481f9](https://github.com/PlaybookMediaLLC/textream/commit/6f481f953e2323227650ac37d259037af0999358))
* add language detection and resilient microphone handling ([5c9331b](https://github.com/PlaybookMediaLLC/textream/commit/5c9331b983ebd268e17dcf920fc4596966ed300e))
* **api:** Add Director Mode API documentation ([96f14e4](https://github.com/PlaybookMediaLLC/textream/commit/96f14e4b4693d816e6d05da5ce45f2aef2b0cca7))
* **browser:** add BrowserServer.swift for handling browser state and server functionality ([d9215ab](https://github.com/PlaybookMediaLLC/textream/commit/d9215aba55ab0481601fe9b8bfe3e5125a41b9b8))
* **contentview:** add dictation functionality and recording controls ([902ede9](https://github.com/PlaybookMediaLLC/textream/commit/902ede97c64640085ab33bc93513d7d4c0105ee3))
* **ContentView:** Add tracking of caret position for dictation and text editor ([97f7464](https://github.com/PlaybookMediaLLC/textream/commit/97f7464bc0ac7d2b9bcb70acdaa0b0e77505caa8))
* **director:** add remote director mode functionality ([50cd3d7](https://github.com/PlaybookMediaLLC/textream/commit/50cd3d78e44e43b64a3ca9f3971db020f029f4ac))
* **docs:** add new features to index.html ([03ea871](https://github.com/PlaybookMediaLLC/textream/commit/03ea8714b2ea8c401eba90378024ce936a4e5d51))
* **docs:** add video preview to README ([d6b5f5a](https://github.com/PlaybookMediaLLC/textream/commit/d6b5f5aaacddef29baa89f9a4c1bce5669cb2b51))
* **external display:** add ExternalDisplayController for managing external display functionality ([444a9e1](https://github.com/PlaybookMediaLLC/textream/commit/444a9e17cd4080436130330d0cc243a5ce7441a2))
* **NotchOverlayController:** add sharingType property to panel ([af5a88a](https://github.com/PlaybookMediaLLC/textream/commit/af5a88a7ded600bce6e136aca536fccbc32cd279))
* **notchsettings:** add showElapsedTime setting to NotchSettings class ([098a903](https://github.com/PlaybookMediaLLC/textream/commit/098a90356cfe012977c824fd92cd9f62d4a343e0))
* **overlay:** make floating window resizable ([9ad2ada](https://github.com/PlaybookMediaLLC/textream/commit/9ad2ada794413ec7e0e987e695514515fe882bc4))
* prepare Dante for Creators v1.0 for Universal App Store release ([9f71054](https://github.com/PlaybookMediaLLC/textream/commit/9f710543512bc1e79132267ce4d19774a66d64ba))
* **release:** add semantic-release and downloadable macOS/iOS CI build artifacts ([6225093](https://github.com/PlaybookMediaLLC/textream/commit/6225093edfa5fd510964c0a9472de9bea3396f28))
* **settings:** add option to hide overlay from screen shares ([5e23f45](https://github.com/PlaybookMediaLLC/textream/commit/5e23f457043298c2c345a98df6d54cb0db03f6ff))
* **Textream:** Add auto update checker feature for version tracking ([08868cf](https://github.com/PlaybookMediaLLC/textream/commit/08868cfd38055204bef338994bd72502bfb0229b))
* **Textream:** Add DirectorServer for managing director-client communication ([d4f4e03](https://github.com/PlaybookMediaLLC/textream/commit/d4f4e0349812880b6d1b22108526e38478ac9d71))
* **Textream:** Add remote connection feature for viewing teleprompter on any device ([259a741](https://github.com/PlaybookMediaLLC/textream/commit/259a74197960940ff9ac290160c96d4290c88cd0))
* **Textream:** Add support for PowerPoint notes import and .textream file saving ([479dab6](https://github.com/PlaybookMediaLLC/textream/commit/479dab6880c60875c9f55c3f518fbd22a560eb72))
