//
//  SpeechRecognizer.swift
//  Textream
//
//  Created by Fatih Kadir Akın on 8.02.2026.
//

import AppKit
import Foundation
import Speech
import AVFoundation
import CoreAudio

private let waveformUpdatesPerSecond = 20.0
private let speechCaptureBuffersPerSecond = 40.0

func speechCaptureFormat(for hardwareFormat: AVAudioFormat) -> AVAudioFormat? {
    guard hardwareFormat.channelCount > 1 else { return hardwareFormat }

    // An input-node tap must use the hardware sample rate. AVAudioEngine can
    // downmix channels here, but requesting a different rate raises an
    // uncaught AVFAudio format-mismatch exception on high-rate USB devices.
    return AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: hardwareFormat.sampleRate,
        channels: 1,
        interleaved: false
    )
}

func speechCaptureBufferSize(for format: AVAudioFormat) -> AVAudioFrameCount {
    AVAudioFrameCount(max(1024, format.sampleRate / speechCaptureBuffersPerSecond))
}

struct AudioInputDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String

    static func allInputDevices() -> [AudioInputDevice] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize) == noErr else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs) == noErr else { return [] }

        var result: [AudioInputDevice] = []
        for deviceID in deviceIDs {
            // Check if device has input streams
            var inputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(deviceID, &inputAddress, 0, nil, &streamSize) == noErr, streamSize > 0 else { continue }

            // Get UID
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var uid: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            let uidStatus = withUnsafeMutablePointer(to: &uid) { uidPointer in
                AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, uidPointer)
            }
            guard uidStatus == noErr else { continue }

            // Get name
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var name: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            let nameStatus = withUnsafeMutablePointer(to: &name) { namePointer in
                AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, namePointer)
            }
            guard nameStatus == noErr else { continue }

            result.append(AudioInputDevice(id: deviceID, uid: uid as String, name: name as String))
        }
        return result
    }

    static func deviceID(forUID uid: String) -> AudioDeviceID? {
        allInputDevices().first(where: { $0.uid == uid })?.id
    }
}

@Observable
class SpeechRecognizer {
    var recognizedCharCount: Int = 0
    var isListening: Bool = false
    var isStarting: Bool = false
    var error: String?
    var audioLevels: [CGFloat] = Array(repeating: 0, count: 30)
    var lastSpokenText: String = ""
    var shouldDismiss: Bool = false
    var shouldAdvancePage: Bool = false

    /// True when recent audio levels indicate the user is actively speaking
    var isSpeaking: Bool {
        voiceActivityDetector.isActive(at: ProcessInfo.processInfo.systemUptime)
    }

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var sourceText: String = ""
    private var voiceActivityDetector = VoiceActivityDetector()
    /// Shared with iOS (Shared/PromptMatcher.swift); benchmarked by benchmarks/speech-tracking.
    private var matcher = PromptMatcher(source: PromptScript(""))
    private var retryCount: Int = 0
    private let maxRetries: Int = 10
    private var configurationChangeObserver: Any?
    private var pendingRestart: DispatchWorkItem?
    private var sessionGeneration: Int = 0
    private var recognitionGeneration: Int = 0
    private var shouldListen: Bool = false
    private var suppressConfigChange: Bool = false
    private var requestLock = NSLock()
    private var preemptiveRestartTimer: Timer?

    // Local (custom model) engine state
    private var localEngineInfo: LocalSpeechEngineInfo?
    private var currentLocalEngineIsActive = false
    private var localEngineSessionID: Int?
    private var localAudioConverter: AVAudioConverter?
    private var localConverterInputFormat: AVAudioFormat?
    private var localConverterOutputFormat: AVAudioFormat?
    /// Transcript prefix to ignore when matching — set on jumps so the task
    /// can keep running instead of being restarted (a restart loses the words
    /// the user re-speaks right after the jump). Stored as the prefix string,
    /// not a char count: partial results revise earlier text, and trimming by
    /// the surviving common prefix avoids swallowing post-jump speech when
    /// the pre-jump portion changes length. Cleared whenever a new
    /// recognition task starts a fresh transcript.
    private var spokenAnchorPrefix: String = ""
    /// Results computed before a jump can be delivered after it; matching
    /// ignores results for a short window so pre-jump speech isn't matched
    /// against the text at the new offset.
    private var lastJumpAt: Date = .distantPast

    /// Update the source text while preserving the current recognized char count.
    /// Used by Director Mode to live-edit unread text without resetting read progress.
    func updateText(_ text: String, preservingCharCount: Int) {
        let words = splitTextIntoWords(text)
        let collapsed = words.joined(separator: " ")
        sourceText = collapsed
        matcher = PromptMatcher(source: PromptScript(collapsed), startingAt: min(preservingCharCount, collapsed.count))
        recognizedCharCount = matcher.recognizedCharacterCount
    }

    /// Jump highlight to a specific char offset (e.g. when user taps a word).
    /// Nearby jumps keep the recognition task alive and anchor matching past
    /// the already-spoken transcript, so tracking resumes on the first
    /// re-spoken word. Far jumps restart the task instead: contextualStrings
    /// are built for the section being read, and after a page-scale jump
    /// stale hints hurt recognition more than the task warm-up costs.
    /// retryCount is deliberately not touched here — resetting it on every
    /// tap would let a user keep a failing availability-retry loop alive
    /// forever.
    func jumpTo(charOffset: Int) {
        let targetOffset = matcher.jump(to: charOffset)
        let distance = abs(targetOffset - recognizedCharCount)
        recognizedCharCount = targetOffset
        if isListening && (distance > 500 || !audioEngine.isRunning) {
            // Far jump, or the engine died without a config-change callback —
            // fall back to a full restart (also refreshes contextualStrings).
            restartRecognition(resetRetryCount: false)
            return
        }
        spokenAnchorPrefix = lastSpokenText
        lastJumpAt = Date()
    }

    func start(with text: String) {
        // Clean up any previous session immediately so pending restarts
        // and stale taps are removed before the async auth callback fires.
        cleanupRecognition()

        let words = splitTextIntoWords(text)
        let collapsed = words.joined(separator: " ")
        sourceText = collapsed
        matcher = PromptMatcher(source: PromptScript(collapsed))
        recognizedCharCount = matcher.recognizedCharacterCount
        retryCount = 0
        error = nil
        sessionGeneration &+= 1
        shouldListen = true
        isListening = false
        isStarting = true
        #if BENCHMARK
        if Bench.stopListeningAfterShow {
            // Overlay open with recognition paused: nothing listening, no mic.
            isStarting = false
            benchLog("read.paused")
            return
        }
        if Bench.autoplayWPM > 0 {
            isStarting = false
            isListening = true
            Bench.startAutoplay(self, collapsedText: collapsed)
            return
        }
        #endif
        requestMicrophoneAccessAndBegin(for: sessionGeneration)
    }

    private func requestMicrophoneAccessAndBegin(for generation: Int) {
        guard shouldListen, sessionGeneration == generation else { return }

        #if BENCHMARK
        // File-fed audio never opens the microphone.
        if BenchAudioSource.shared != nil {
            beginAfterMicrophoneAccess(for: generation)
            return
        }
        #endif

        // Check microphone permission first
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .denied, .restricted:
            failListening("Microphone access denied. Open System Settings → Privacy & Security → Microphone to allow Textream.")
            openMicrophoneSettings()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self,
                          self.shouldListen,
                          self.sessionGeneration == generation else { return }
                    if granted {
                        self.beginAfterMicrophoneAccess(for: generation)
                    } else {
                        self.failListening("Microphone access denied. Open System Settings → Privacy & Security → Microphone to allow Textream.")
                    }
                }
            }
        case .authorized:
            beginAfterMicrophoneAccess(for: generation)
        @unknown default:
            failListening("Microphone authorization is unavailable.")
        }
    }

    private func beginAfterMicrophoneAccess(for generation: Int) {
        guard shouldListen, sessionGeneration == generation else { return }
        if NotchSettings.shared.listeningMode == .wordTracking {
            if NotchSettings.shared.speechEngine == .local {
                prepareLocalRecognition(for: generation)
            } else {
                requestSpeechAuthAndBegin(for: generation)
            }
        } else {
            beginRecognition()
        }
    }

    /// Loads (or reuses) the selected custom model before starting recognition.
    /// The model stays loaded inside the engine for the app's lifetime so
    /// restarts are fast; switching models reloads on the next session.
    private func prepareLocalRecognition(for generation: Int) {
        guard shouldListen, sessionGeneration == generation else { return }
        let filename = NotchSettings.shared.localModelFilename
        guard !filename.isEmpty else {
            failListening("No local model selected. Open Settings → Guidance → Manage Models to download one.")
            return
        }
        let modelURL = LocalSpeechModelStore.modelsDirectory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            failListening("The local model \"\(filename)\" is missing from the models folder. Download it again in Settings → Guidance → Manage Models.")
            return
        }

        let engine = LocalSpeechEngine.shared
        isStarting = true
        engine.loadModel(at: modelURL.path) { [weak self] result in
            guard let self,
                  self.shouldListen,
                  self.sessionGeneration == generation else { return }
            switch result {
            case .success(let info):
                self.localEngineInfo = info
                self.beginRecognition()
            case .failure(let error):
                self.localEngineInfo = nil
                self.failListening("Couldn't load the local model \"\(filename)\": \(error.localizedDescription)")
            }
        }
    }

    private func requestSpeechAuthAndBegin(for generation: Int) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self,
                      self.shouldListen,
                      self.sessionGeneration == generation else { return }
                switch status {
                case .authorized:
                    self.beginRecognition()
                default:
                    self.failListening("Speech recognition not authorized. Open System Settings → Privacy & Security → Speech Recognition to allow Textream.")
                    self.openSpeechRecognitionSettings()
                }
            }
        }
    }

    private func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openSpeechRecognitionSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition") {
            NSWorkspace.shared.open(url)
        }
    }

    private func failListening(_ message: String) {
        voiceActivityDetector.reset()
        shouldListen = false
        isListening = false
        isStarting = false
        error = message
        cleanupRecognition()
        releaseLocalModel()
    }

    /// Frees the local model's RAM once a reading session has truly ended.
    /// Pauses (`stop()`/`resume()`) keep the model loaded; only real ends
    /// (dismiss, force close, failure) release it.
    private func releaseLocalModel() {
        LocalSpeechEngine.shared.unloadModel()
    }

    func stop() {
        shouldListen = false
        sessionGeneration &+= 1
        isListening = false
        isStarting = false
        cleanupRecognition()
    }

    func forceStop() {
        shouldListen = false
        sessionGeneration &+= 1
        isListening = false
        isStarting = false
        sourceText = ""
        matcher = PromptMatcher(source: PromptScript(""))
        retryCount = maxRetries
        cleanupRecognition()
        releaseLocalModel()
    }

    func resume() {
        guard !sourceText.isEmpty else { return }
        cleanupRecognition()
        retryCount = 0
        recognizedCharCount = matcher.jump(to: recognizedCharCount)
        shouldDismiss = false
        error = nil
        sessionGeneration &+= 1
        shouldListen = true
        isListening = false
        isStarting = true
        requestMicrophoneAccessAndBegin(for: sessionGeneration)
    }

    private func cleanupRecognitionTask() {
        recognitionGeneration &+= 1
        // Cancel any pending restart to prevent overlapping beginRecognition calls
        pendingRestart?.cancel()
        pendingRestart = nil

        stopPreemptiveTimer()

        if let observer = configurationChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            configurationChangeObserver = nil
        }
        requestLock.lock()
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        requestLock.unlock()
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    private func cleanupAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    private func cleanupRecognition() {
        cleanupRecognitionTask()
        cleanupAudioEngine()
        voiceActivityDetector.reset()
        stopLocalEngineSession()
    }

    /// Ends the active local engine session without unloading the model.
    private func stopLocalEngineSession() {
        guard currentLocalEngineIsActive else { return }
        currentLocalEngineIsActive = false
        if let localEngineSessionID {
            LocalSpeechEngine.shared.cancel(sessionID: localEngineSessionID)
        }
        localEngineSessionID = nil
        localAudioConverter = nil
        localConverterInputFormat = nil
        localConverterOutputFormat = nil
    }

    /// Coalesces all delayed beginRecognition() calls into a single pending work item.
    /// Any previously scheduled restart is cancelled before the new one is queued.
    private func scheduleBeginRecognition(after delay: TimeInterval) {
        pendingRestart?.cancel()
        guard shouldListen, !sourceText.isEmpty else { return }
        isListening = false
        isStarting = true
        let expectedSessionGeneration = sessionGeneration
        let work = DispatchWorkItem { [weak self] in
            guard let self,
                  self.shouldListen,
                  self.sessionGeneration == expectedSessionGeneration,
                  !self.sourceText.isEmpty else { return }
            self.pendingRestart = nil
            self.beginRecognition()
        }
        pendingRestart = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func beginRecognition() {
        guard shouldListen, !sourceText.isEmpty else {
            isListening = false
            isStarting = false
            return
        }
        // Engine switched to Local mid-session (or a restart raced the first
        // load): load the model before starting, rather than falling back to
        // Apple Speech while the user selected local.
        if NotchSettings.shared.listeningMode == .wordTracking,
           NotchSettings.shared.speechEngine == .local,
           localEngineInfo == nil {
            prepareLocalRecognition(for: sessionGeneration)
            return
        }
        let expectedSessionGeneration = sessionGeneration
        let requiresSpeechRecognition = NotchSettings.shared.listeningMode == .wordTracking
        let usesLocalEngine = requiresSpeechRecognition
            && NotchSettings.shared.speechEngine == .local
            && localEngineInfo != nil
        // Ensure clean state
        cleanupRecognition()
        guard shouldListen, sessionGeneration == expectedSessionGeneration else {
            isListening = false
            isStarting = false
            return
        }
        isListening = false
        isStarting = true
        // New session = fresh transcript (see restartTask for why
        // lastSpokenText must be cleared alongside the anchor)
        spokenAnchorPrefix = ""
        lastSpokenText = ""

        // Create a fresh engine so it picks up the current hardware format.
        // AVAudioEngine caches the device format internally and reset() alone
        // does not reliably flush it after a mic switch.
        audioEngine = AVAudioEngine()
        suppressConfigChange = false

        // Set selected microphone if configured
        let micUID = NotchSettings.shared.selectedMicUID
        if !micUID.isEmpty, let deviceID = AudioInputDevice.deviceID(forUID: micUID) {
            // Suppress config-change observer during our own device switch
            suppressConfigChange = true
            let inputUnit = audioEngine.inputNode.audioUnit
            if let audioUnit = inputUnit {
                var devID = deviceID
                AudioUnitSetProperty(
                    audioUnit,
                    kAudioOutputUnitProperty_CurrentDevice,
                    kAudioUnitScope_Global,
                    0,
                    &devID,
                    UInt32(MemoryLayout<AudioDeviceID>.size)
                )
                // Re-initialize audio unit so it picks up the new device's format
                AudioUnitUninitialize(audioUnit)
                AudioUnitInitialize(audioUnit)
            }
            // Allow config changes again after a settle period
            let expectedSessionGeneration = sessionGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self,
                      self.sessionGeneration == expectedSessionGeneration else { return }
                self.suppressConfigChange = false
            }
        }

        if usesLocalEngine {
            // Custom local models replace SFSpeechRecognizer entirely; the
            // same audio tap below feeds the local engine instead.
            speechRecognizer = nil
            recognitionRequest = nil
        } else if requiresSpeechRecognition {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: NotchSettings.shared.speechLocale))
            guard let speechRecognizer else {
                // nil means the locale isn't supported for speech recognition —
                // that's permanent, so fail immediately instead of retrying.
                failListening("Speech recognition isn't supported for the selected language.")
                return
            }
            guard speechRecognizer.isAvailable else {
                // Unavailability is often transient (the recognition service
                // churns briefly after a task cancellation or device change).
                // Giving up here leaves the engine stopped and the app deaf —
                // retry like the invalid-format guard below does.
                if retryCount < maxRetries {
                    retryCount += 1
                    scheduleBeginRecognition(after: 0.5)
                } else {
                    failListening("Speech recognizer is not available.")
                }
                return
            }

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest else {
                failListening("Unable to create a speech recognition request.")
                return
            }
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.taskHint = .dictation

            // Add contextual strings from the source text to improve STT accuracy
            let upcoming = String(sourceText.dropFirst(matcher.matchStartOffset))
            let contextWords = upcoming.split(separator: " ")
                .map { String($0).lowercased().filter { $0.isLetter || $0.isNumber } }
                .filter { $0.count >= 5 }
            let uniqueContextWords = Array(Set(contextWords).prefix(50))
            if !uniqueContextWords.isEmpty {
                recognitionRequest.contextualStrings = uniqueContextWords
            }
        } else {
            speechRecognizer = nil
            recognitionRequest = nil
        }

        #if BENCHMARK
        let inputNode: AVAudioNode = BenchAudioSource.shared?.attach(to: audioEngine) ?? audioEngine.inputNode
        #else
        let inputNode = audioEngine.inputNode
        #endif
        let hardwareFormat = inputNode.outputFormat(forBus: 0)

        // Guard against invalid format during device transitions (e.g. mic switch)
        guard hardwareFormat.sampleRate > 0, hardwareFormat.channelCount > 0 else {
            // Retry after a longer delay to let the audio system settle
            if retryCount < maxRetries {
                retryCount += 1
                scheduleBeginRecognition(after: 0.5)
            } else {
                failListening("Audio input is unavailable.")
            }
            return
        }

        // SFSpeechRecognizer expects mono voice audio. Downmix multi-channel
        // devices without changing the input node's hardware sample rate.
        guard let tapFormat = speechCaptureFormat(for: hardwareFormat) else {
            failListening("Audio input format is unsupported.")
            return
        }

        // Observe audio configuration changes (e.g. mic switched externally) to restart gracefully
        configurationChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: .main
        ) { [weak self] _ in
            guard let self,
                  self.shouldListen,
                  !self.suppressConfigChange,
                  !self.sourceText.isEmpty else { return }
            self.restartRecognition()
        }

        // Belt-and-suspenders: ensure no stale tap exists before installing
        inputNode.removeTap(onBus: 0)

        let waveformFrameInterval = AVAudioFrameCount(
            max(1, tapFormat.sampleRate / waveformUpdatesPerSecond)
        )
        var framesSinceWaveformUpdate = waveformFrameInterval

        inputNode.installTap(
            onBus: 0,
            bufferSize: speechCaptureBufferSize(for: tapFormat),
            format: tapFormat
        ) { [weak self] buffer, _ in
            self?.appendBufferToRequest(buffer)

            framesSinceWaveformUpdate &+= buffer.frameLength
            guard framesSinceWaveformUpdate >= waveformFrameInterval else { return }
            framesSinceWaveformUpdate %= waveformFrameInterval

            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameLength {
                sum += channelData[i] * channelData[i]
            }
            let rms = sqrt(sum / Float(max(frameLength, 1)))
            let level = CGFloat(min(rms * 5, 1.0))

            DispatchQueue.main.async {
                guard let self,
                      self.shouldListen,
                      self.sessionGeneration == expectedSessionGeneration else { return }
                self.recordAudioLevel(level)
            }
        }

        if let speechRecognizer, let recognitionRequest {
            recognitionGeneration &+= 1
            let currentRecognitionGeneration = recognitionGeneration
            let currentGeneration = sessionGeneration
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self else { return }
                if let result {
                    let spoken = result.bestTranscription.formattedString
                    benchLog("asr.partial", ["engine": "apple", "len": spoken.count])
                    DispatchQueue.main.async {
                        // Ignore stale results from a previous session
                        guard self.sessionGeneration == currentGeneration,
                              self.recognitionGeneration == currentRecognitionGeneration else { return }
                        self.retryCount = 0 // Reset on success
                        self.lastSpokenText = spoken
                        self.matchCharacters(spoken: spoken)
                    }
                }
                if let error {
                    DispatchQueue.main.async {
                        guard self.sessionGeneration == currentGeneration,
                              self.recognitionGeneration == currentRecognitionGeneration else { return }
                        // If recognitionRequest is nil, cleanup already ran (intentional cancel) — don't retry
                        guard self.recognitionRequest != nil else { return }
                        guard self.shouldListen && !self.shouldDismiss && !self.sourceText.isEmpty else {
                            self.isListening = false
                            self.isStarting = false
                            return
                        }

                        self.recognizedCharCount = self.matcher.restartFromCurrentProgress()
                        benchNewSession("taskError")

                        // Distinguish timeout errors (expected every ~60s) from real errors.
                        // SFSpeechRecognizer timeout is error code 1110 in kAFAssistantErrorDomain,
                        // or 216 (kAudioConverterErr_FormatNotSupported). Retry immediately for
                        // timeouts with no retry limit; use backoff for real errors.
                        let nsError = error as NSError
                        let isTimeout = nsError.code == 1110 || nsError.code == 216

                        if isTimeout {
                            // Expected timeout — restart immediately, no retry limit
                            self.retryCount = 0
                            if self.audioEngine.isRunning {
                                self.restartTask()
                            } else {
                                self.scheduleBeginRecognition(after: 0.1)
                            }
                        } else if self.retryCount < self.maxRetries {
                            self.retryCount += 1
                            let delay = min(Double(self.retryCount) * 0.5, 1.5)
                            self.scheduleBeginRecognition(after: delay)
                        } else {
                            self.failListening("Speech recognition stopped: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            guard shouldListen, sessionGeneration == expectedSessionGeneration else {
                cleanupRecognition()
                return
            }
            #if BENCHMARK
            BenchAudioSource.shared?.play()
            #endif
            benchNewSession("begin")
            error = nil
            isStarting = false
            isListening = true
            if usesLocalEngine {
                startLocalEngineSession()
            } else if requiresSpeechRecognition {
                startPreemptiveTimer()
            }
        } catch {
            // Transient failure after a device switch — retry with longer delay
            if retryCount < maxRetries {
                retryCount += 1
                scheduleBeginRecognition(after: 0.5)
            } else {
                failListening("Audio engine failed: \(error.localizedDescription)")
            }
        }
    }

    private func restartRecognition(resetRetryCount: Bool = true) {
        guard shouldListen, !sourceText.isEmpty else {
            isListening = false
            isStarting = false
            return
        }
        if resetRetryCount {
            retryCount = 0
        }
        isListening = false
        isStarting = true
        cleanupRecognition()
        scheduleBeginRecognition(after: 0.5)
    }

    // MARK: - Thread-safe buffer appending

    private func recordAudioLevel(_ level: CGFloat) {
        audioLevels.append(level)
        if audioLevels.count > 30 {
            audioLevels.removeFirst()
        }
        voiceActivityDetector.process(level: level, at: ProcessInfo.processInfo.systemUptime)
    }

    private func appendBufferToRequest(_ buffer: AVAudioPCMBuffer) {
        if currentLocalEngineIsActive {
            feedLocalEngine(buffer)
            return
        }
        requestLock.lock()
        recognitionRequest?.append(buffer)
        requestLock.unlock()
    }

    // MARK: - Local engine

    private func startLocalEngineSession() {
        guard let info = localEngineInfo else { return }
        let engine = LocalSpeechEngine.shared
        currentLocalEngineIsActive = true

        let generation = sessionGeneration
        let language = Self.localLanguageHint(
            for: info,
            preferredLocale: NotchSettings.shared.speechLocale
        )
        let prompt = localInitialPrompt()

        localEngineSessionID = engine.start(
            language: language,
            initialPrompt: prompt,
            wordTimestamps: false,
            onText: { [weak self] text, _, _, isNewWindow, engineSessionID in
                guard let self,
                      self.shouldListen,
                      self.sessionGeneration == generation,
                      self.localEngineSessionID == engineSessionID,
                      !self.sourceText.isEmpty else { return }
                if isNewWindow {
                    // Rolling window rolled over: re-anchor matching at the current
                    // progress so old transcripts can't be re-matched.
                    self.recognizedCharCount = self.matcher.restartFromCurrentProgress()
                    benchNewSession("localWindow")
                }
                self.retryCount = 0
                self.lastSpokenText = text
                self.matchCharacters(spoken: text)
            },
            onError: { [weak self] message, engineSessionID in
                guard let self,
                      self.shouldListen,
                      self.sessionGeneration == generation,
                      self.localEngineSessionID == engineSessionID else { return }
                self.failListening(message)
            },
            onFinished: { [weak self] engineSessionID in
                guard let self,
                      self.shouldListen,
                      self.sessionGeneration == generation,
                      self.localEngineSessionID == engineSessionID else { return }
                self.retryCount = 0
            }
        )
    }

    /// Converts the hardware-rate tap buffers to the 16 kHz mono float32 the
    /// local engine expects, then hands them over without blocking the tap.
    private func feedLocalEngine(_ buffer: AVAudioPCMBuffer) {
        guard buffer.frameLength > 0 else { return }
        let engine = LocalSpeechEngine.shared
        let inputFormat = buffer.format

        if localAudioConverter == nil
            || localConverterInputFormat?.sampleRate != inputFormat.sampleRate
            || localConverterInputFormat?.channelCount != inputFormat.channelCount {
            guard let outputFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 16_000,
                channels: 1,
                interleaved: false
            ), let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else { return }
            localConverterOutputFormat = outputFormat
            localConverterInputFormat = inputFormat
            localAudioConverter = converter
        }

        guard let converter = localAudioConverter,
              let outputFormat = localConverterOutputFormat else { return }

        let ratio = outputFormat.sampleRate / inputFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return }

        var conversionError: NSError?
        var suppliedInput = false
        converter.convert(to: output, error: &conversionError) { _, status in
            if suppliedInput {
                status.pointee = .noDataNow
                return nil
            }
            suppliedInput = true
            status.pointee = .haveData
            return buffer
        }

        guard conversionError == nil,
              output.frameLength > 0,
              let channel = output.floatChannelData?[0] else { return }
        guard let localEngineSessionID else { return }
        engine.feed(
            Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength))),
            sessionID: localEngineSessionID
        )
    }

    private func localInitialPrompt() -> String? {
        // Vocabulary hint, not a script echo: pasting the upcoming sentence as
        // the prompt can make Whisper skip words it assumes are already
        // transcribed. Distinctive words only (Handy's custom-words approach).
        let upcoming = String(sourceText.dropFirst(matcher.matchStartOffset))
        var seen = Set<String>()
        var words: [String] = []
        for raw in upcoming.split(separator: " ").prefix(80) {
            let word = raw.trimmingCharacters(in: .punctuationCharacters)
            guard word.count >= 6, seen.insert(word.lowercased()).inserted else { continue }
            words.append(word)
            if words.count >= 15 { break }
        }
        return words.isEmpty ? nil : words.joined(separator: ", ")
    }

    private static func localLanguageHint(
        for info: LocalSpeechEngineInfo,
        preferredLocale: String
    ) -> String? {
        // Mirrors Handy's run-plan language resolution: only ever pass a
        // language the model advertises, using the model's own concrete code
        // (Nemotron wants "en-US", not "en"); let the model auto-detect when
        // it can, and pin a fallback when it can't.
        guard !info.languages.isEmpty else { return nil }
        let preferred = baseLanguageCode(preferredLocale)
        if !preferred.isEmpty {
            if let exact = info.languages.first(where: {
                $0.caseInsensitiveCompare(preferredLocale) == .orderedSame
            }) {
                return exact
            }
            if let sameLanguage = info.languages.first(where: { baseLanguageCode($0) == preferred }) {
                return sameLanguage
            }
        }
        if info.supportsLanguageDetection { return nil }
        if let english = info.languages.first(where: { baseLanguageCode($0) == "en" }) {
            return english
        }
        return info.languages.first
    }

    private static func baseLanguageCode(_ identifier: String) -> String {
        identifier
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
            .first
            .map { String($0).lowercased() } ?? ""
    }

    // MARK: - Soft restart (task only, keeps audio engine running)

    private func restartTask() {
        guard shouldListen, isListening, audioEngine.isRunning, !sourceText.isEmpty else {
            isListening = false
            if shouldListen, !sourceText.isEmpty {
                cleanupRecognition()
                scheduleBeginRecognition(after: 0.5)
            }
            return
        }
        recognitionGeneration &+= 1
        let currentRecognitionGeneration = recognitionGeneration
        // Update match offset before restarting
        recognizedCharCount = matcher.restartFromCurrentProgress()
        benchNewSession("restartTask")
        // New task = fresh transcript. lastSpokenText must be cleared too:
        // a jump taken before the first new result would otherwise anchor on
        // the old task's transcript and trim away everything the new task
        // ever produces.
        spokenAnchorPrefix = ""
        lastSpokenText = ""

        // Cancel any pending restart to avoid stale beginRecognition clobbering this session
        pendingRestart?.cancel()
        pendingRestart = nil

        // Cancel the old task and atomically swap to a new request under lock.
        // The lock prevents the audio tap from appending to the old request
        // between endAudio() and the new assignment.
        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        newRequest.taskHint = .dictation

        // Add contextual strings for the remaining text
        let upcoming = String(sourceText.dropFirst(matcher.matchStartOffset))
        let contextWords = upcoming.split(separator: " ")
            .map { String($0).lowercased().filter { $0.isLetter || $0.isNumber } }
            .filter { $0.count >= 5 }
        let uniqueWords = Array(Set(contextWords).prefix(50))
        if !uniqueWords.isEmpty {
            newRequest.contextualStrings = uniqueWords
        }

        // Nil out recognitionRequest before cancelling the old task so the
        // old task's error callback sees nil and skips retry logic. Then set
        // the new request after cancellation.
        requestLock.lock()
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        requestLock.unlock()
        recognitionTask?.cancel()
        recognitionTask = nil

        requestLock.lock()
        recognitionRequest = newRequest
        requestLock.unlock()

        // Start new recognition task
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            // Transient unavailability — fall back to a full session restart
            // with retries rather than going permanently deaf.
            if retryCount < maxRetries {
                retryCount += 1
                scheduleBeginRecognition(after: 0.5)
            } else {
                // Don't leave the mic hot with no session consuming it
                failListening("Speech recognizer is not available.")
            }
            return
        }

        let currentGeneration = sessionGeneration
        recognitionTask = speechRecognizer.recognitionTask(with: newRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let spoken = result.bestTranscription.formattedString
                benchLog("asr.partial", ["engine": "apple", "len": spoken.count])
                DispatchQueue.main.async {
                    guard self.sessionGeneration == currentGeneration,
                          self.recognitionGeneration == currentRecognitionGeneration else { return }
                    self.retryCount = 0
                    self.lastSpokenText = spoken
                    self.matchCharacters(spoken: spoken)
                }
            }
            if let error {
                DispatchQueue.main.async {
                    guard self.sessionGeneration == currentGeneration,
                          self.recognitionGeneration == currentRecognitionGeneration else { return }
                    guard self.recognitionRequest != nil else { return }
                    guard self.shouldListen && !self.shouldDismiss && !self.sourceText.isEmpty else {
                        self.isListening = false
                        self.isStarting = false
                        return
                    }

                    self.recognizedCharCount = self.matcher.restartFromCurrentProgress()
                    benchNewSession("taskError")

                    let nsError = error as NSError
                    let isTimeout = nsError.code == 1110 || nsError.code == 216

                    if isTimeout {
                        self.retryCount = 0
                        if self.audioEngine.isRunning {
                            self.restartTask()
                        } else {
                            self.scheduleBeginRecognition(after: 0.1)
                        }
                    } else if self.retryCount < self.maxRetries {
                        self.retryCount += 1
                        let delay = min(Double(self.retryCount) * 0.5, 1.5)
                        self.scheduleBeginRecognition(after: delay)
                    } else {
                        self.failListening("Speech recognition stopped: \(error.localizedDescription)")
                    }
                }
            }
        }

        startPreemptiveTimer()
    }

    // MARK: - Pre-emptive restart timer

    private func startPreemptiveTimer() {
        preemptiveRestartTimer?.invalidate()
        preemptiveRestartTimer = Timer.scheduledTimer(withTimeInterval: 55.0, repeats: true) { [weak self] _ in
            guard let self, self.isListening, !self.sourceText.isEmpty else { return }
            self.restartTask()
        }
    }

    private func stopPreemptiveTimer() {
        preemptiveRestartTimer?.invalidate()
        preemptiveRestartTimer = nil
    }

    // MARK: - Fuzzy character-level matching

    private func matchCharacters(spoken fullSpoken: String) {
        // Results computed before a jump can be delivered just after it —
        // don't match pre-jump speech against the text at the new offset.
        guard Date().timeIntervalSince(lastJumpAt) > 0.3 else { return }
        #if BENCHMARK
        let benchStart = Bench.monoNanos()
        defer {
            Bench.log("match", [
                "chars": recognizedCharCount, "ns": Bench.monoNanos() - benchStart,
                "session": Bench.session, "text": fullSpoken,
            ])
        }
        #endif

        // Ignore transcript from before the most recent jump. Trim by the
        // common prefix that survived the recognizer's revisions, but never
        // less than the anchor length minus a small slack — a revision very
        // early in the transcript would otherwise leak the whole pre-jump
        // transcript back into matching.
        var spoken = fullSpoken
        if !spokenAnchorPrefix.isEmpty {
            let common = zip(spokenAnchorPrefix, fullSpoken).prefix(while: { $0 == $1 }).count
            let trimLen = min(fullSpoken.count, max(common, spokenAnchorPrefix.count - 24))
            spoken = String(fullSpoken.dropFirst(trimLen))
        }
        guard !spoken.isEmpty else { return }

        // Other code resets recognizedCharCount directly (e.g. to 0 on a new page);
        // re-anchor the matcher there before matching.
        if recognizedCharCount != matcher.recognizedCharacterCount {
            recognizedCharCount = matcher.jump(to: recognizedCharCount)
        }
        recognizedCharCount = matcher.match(transcript: spoken)
    }
}
