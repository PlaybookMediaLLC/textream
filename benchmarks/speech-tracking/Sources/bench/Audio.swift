// Layer B: real audio through a real recognizer.
//
// record-audio: each case's performance (same speaker model as Layer A) is spoken by a
// macOS voice (accents: US, UK, IN, AU, IE, ZA, plus non-native voices reading English),
// mixed with generated noise (multi-talker babble, a single competing "TV" talker, HVAC
// rumble) at a target SNR, and streamed in real time into Apple's on-device
// SFSpeechRecognizer exactly like the app does it (partials on, `.dictation` hint,
// contextual strings, a new task every 55 s or when a task ends). The recognizer's
// partials and the ground-truth timeline are saved under fixtures/<case>/.
//
// score-audio: replays those fixtures through the matcher. No audio or recognizer is
// needed, so CI can gate on real-recognizer behaviour.
//
// Limits: synthetic voices are cleaner and more regular than people; word timings
// inside a sentence are interpolated by length. Real readers (PLAN.md §5) remain the
// final word.

import AVFoundation
import Foundation
import Speech

let sampleRate = 16_000.0

enum NoiseKind: String, Codable { case babble, tv, hvac }

struct AudioCaseInfo: Codable {
    var id: String
    var dimension: String
    var name: String
    var script: String
    var voice: String
    var wpm: Double
    var noise: NoiseKind?
    var snr: Double?
    var hints = true
    var gating = true
    /// nil = exact (from synthesis); "auto-aligned" = human take, timings from the recognizer, review pending.
    var truthSource: String?
}

/// A recognizer the app can use. Fixture files are named `<id>.jsonl`.
///
/// Apple's server path: macOS 26 only has on-device models for a few English locales (en-US,
/// en-PH, en-SA, en-ID). For en-GB, en-IN, en-AU, en-IE, en-ZA, en-CA… recognition goes to the
/// server, so a user who picks their own English variant gets the server path. (With en-US the
/// server option is moot: macOS stays on-device even when server is allowed; partials matched
/// on-device 327/327.)
enum Engine {
    case appleOnDevice
    case appleServer(locale: String)
    case local(name: String, path: String)   // transcribe.cpp model, via the app's LocalSpeechEngine

    var id: String {
        switch self {
        case .appleOnDevice: "apple-on-device"
        case .appleServer(let locale): "apple-server-\(locale)"
        case .local(let name, _): "local-\(name)"
        }
    }

    /// PLAN.md §4.9: the full matrix on the default engine, a fixed core set on the others.
    var recordsFullMatrix: Bool { if case .appleOnDevice = self { true } else { false } }

    static func parse(_ s: String) -> Engine? {
        switch s {
        case "apple-on-device": return .appleOnDevice
        case _ where s.hasPrefix("apple-server:"): return .appleServer(locale: String(s.dropFirst("apple-server:".count)))
        default:
            guard s.hasSuffix(".gguf") else { return nil }
            let name = URL(fileURLWithPath: s).deletingPathExtension().lastPathComponent
            return .local(name: name, path: s)
        }
    }
}

/// Engines whose results gate (PLAN.md §8, §10.3). Others are reported only.
func isGatingEngine(_ id: String) -> Bool {
    id.hasPrefix("apple-") || ["local-nemotron", "local-canary", "local-qwen3"].contains(id)
}

/// Recognizer limits verified outside the matcher, reported but not gated (PLAN.md Status). Values are
/// fixture-id prefixes.
/// - Canary-180M-flash decodes 10 dB 4-talker babble to empty text in ~50% of windows of any length
///   (2–15 s) and any run options; Nemotron transcribes the same audio at 3% WER.
/// - Speechocean762 speaker 0560 (strong Mandarin-L1 accent): Apple 37–52% WER, Nemotron 24–37%; the
///   same audio through Qwen3-ASR has zero lost-place events, so the gap is the recognizer.
/// - Apple, LibriSpeech reader 174 in 10 dB babble: Apple's own transcript arrives 6.8 s late (34% WER);
///   Nemotron passes the same audio.
/// - Qwen3 on 0560's composite (strong accent + 15 dB babble + skip/re-read/pause): no lost-place
///   events, lag p95 3.6 s.
let reportOnlyByEngine: [String: [String]] = [
    "local-canary": ["noise-babble-10"],
    "apple-on-device": ["human-l2-0560-", "human-174-babble10"],
    "local-nemotron": ["human-l2-0560-"],
    "local-qwen3": ["human-l2-0560-composite"],
]

/// Engines whose partials are one cumulative transcript per session (WER/lag diagnostics apply).
func hasCumulativeTranscripts(_ id: String) -> Bool { id.hasPrefix("apple-") || id == "local-nemotron" }

/// Cases recorded on every engine (PLAN.md §4.9).
let coreCaseIDs: Set<String> = ["baseline-us", "accent-gb", "accent-in", "noise-babble-10", "noise-tv-10", "repeated-reread",
                                "paraphrase-adlib", "pauses", "skips", "technical-hints", "composite"]

struct AudioCase {
    var info: AudioCaseInfo
    var perf = Performance()
}

func audioCases() -> [AudioCase] {
    func c(_ id: String, _ dim: String, _ name: String, script: String = "general", voice: String = "Samantha",
           wpm: Double = 175, noise: NoiseKind? = nil, snr: Double? = nil, hints: Bool = true, gating: Bool = true,
           perf: Performance = Performance()) -> AudioCase {
        AudioCase(info: AudioCaseInfo(id: id, dimension: dim, name: name, script: script, voice: voice, wpm: wpm,
                                      noise: noise, snr: snr, hints: hints, gating: gating), perf: perf)
    }
    var out: [AudioCase] = [
        c("baseline-us", "baseline", "clean read, US voice"),
        c("accent-gb", "accent", "UK English (Daniel)", voice: "Daniel"),
        c("accent-in", "accent", "Indian English (Rishi)", voice: "Rishi"),
        c("accent-in-f", "accent", "Indian English (Tara)", voice: "Tara"),
        c("accent-au", "accent", "Australian English (Karen)", voice: "Karen"),
        c("accent-ie", "accent", "Irish English (Moira)", voice: "Moira"),
        c("accent-za", "accent", "South African English (Tessa)", voice: "Tessa"),
        c("speed-130", "speed", "130 wpm", wpm: 130),
        c("speed-230", "speed", "230 wpm", wpm: 230),
        c("noise-babble-10", "noise", "4-talker babble, 10 dB", noise: .babble, snr: 10),
        c("noise-babble-5", "noise", "4-talker babble, 5 dB", noise: .babble, snr: 5, gating: false),
        c("noise-tv-10", "noise", "competing talker (TV), 10 dB", noise: .tv, snr: 10),
        c("noise-tv-5", "noise", "competing talker (TV), 5 dB", noise: .tv, snr: 5, gating: false),
        c("noise-hvac-5", "noise", "HVAC rumble, 5 dB", noise: .hvac, snr: 5),
        c("repeated-refrains", "repeated", "refrains + restart sentence ×3", script: "repeated", voice: "Daniel",
          perf: Performance(restartSentenceAfter: [30, 90, 150])),
        c("repeated-reread", "repeated", "re-read 12 words ×2, jump back 30", perf: Performance(backAfter: [60: 12, 150: 12, 220: 30])),
        c("paraphrase-light", "paraphrase", "contractions, synonyms, fillers", voice: "Karen",
          perf: Performance(paraphrase: 1.0, filler: 0.06)),
        c("paraphrase-adlib", "paraphrase", "ad-lib 15 and 40 words", perf: Performance(adlibAfter: [40: 15, 180: 40])),
        c("pauses", "pauses", "pauses 5 s, 20 s, 60 s", perf: Performance(pauseAfter: [50: 5, 140: 20, 230: 60])),
        c("skips", "skips", "skip 10, 25, 60 words", voice: "Rishi", perf: Performance(skipBefore: [60: 10, 130: 25, 200: 60])),
        c("technical-hints", "technical", "jargon, app's contextual hints on", script: "technical"),
        c("technical-nohints", "technical", "jargon, no hints", script: "technical", hints: false),
        c("composite", "composite", "realistic take, UK voice, babble 15 dB", voice: "Daniel", wpm: 165, noise: .babble, snr: 15,
          perf: Performance(skipBefore: [180: 10], restartSentenceAfter: [70], adlibAfter: [120: 12], pauseAfter: [240: 4],
                            paraphrase: 0.3, filler: 0.04, stutter: 0.02)),
    ]
    // Non-native accents: voices of other languages reading English. Report-only: a
    // TTS voice applying foreign phonetics is harsher and less natural than a person.
    let installed = Set(AVSpeechSynthesisVoice.speechVoices().map(\.name))
    for (voice, label) in [("Thomas", "French"), ("Anna", "German"), ("Mónica", "Spanish"), ("Tingting", "Mandarin")]
        where installed.contains(voice) {
        out.append(c("accent-l1-\(label.lowercased())", "accent (non-native proxy)", "\(label) voice reading English",
                     voice: voice, gating: false))
    }
    return out
}

// MARK: - Synthesis

func fnv(_ s: String) -> String {
    var h: UInt64 = 0xcbf2_9ce4_8422_2325
    for b in s.utf8 { h = (h ^ UInt64(b)) &* 0x100_0000_01b3 }
    return String(h, radix: 16)
}

func readMono(_ url: URL) throws -> [Float] {
    let file = try AVAudioFile(forReading: url)
    let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
    try file.read(into: buffer)
    return Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
}

/// `say` output for one phrase, cached on disk, with leading/trailing silence trimmed.
func synth(_ text: String, voice: String, wpm: Double, cache: URL) throws -> [Float] {
    let url = cache.appendingPathComponent(fnv("\(voice)|\(Int(wpm))|\(text)") + ".wav")
    if !FileManager.default.fileExists(atPath: url.path) {
        let say = Process()
        say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        say.arguments = ["-v", voice, "-r", String(Int(wpm)), "--file-format=WAVE", "--data-format=LEF32@16000", "-o", url.path, text]
        try say.run()
        say.waitUntilExit()
        guard say.terminationStatus == 0 else { throw NSError(domain: "say", code: Int(say.terminationStatus)) }
    }
    let samples = try readMono(url)
    let loud = samples.indices.filter { abs(samples[$0]) > 0.01 }
    guard let first = loud.first, let last = loud.last else { return [] }
    let margin = Int(0.02 * sampleRate)
    return Array(samples[max(0, first - margin)...min(samples.count - 1, last + margin)])
}

/// Renders a performance to audio, returning the ground-truth timeline. Phrases are
/// synthesized whole (natural prosody) and word times interpolated by length inside them.
func render(_ acts: [Act], voice: String, wpm: Double, cache: URL) throws -> (audio: [Float], tl: Timeline) {
    var audio = [Float](repeating: 0, count: Int(0.5 * sampleRate))
    var tl = Timeline()
    var phrase: [Spoken] = []

    func now() -> Double { Double(audio.count) / sampleRate }
    func silence(_ seconds: Double) { audio += [Float](repeating: 0, count: Int(seconds * sampleRate)) }
    func flush() throws {
        guard !phrase.isEmpty else { return }
        let samples = try synth(phrase.map { $0.display ?? $0.text }.joined(separator: " "), voice: voice, wpm: wpm, cache: cache)
        let start = now()
        let duration = Double(samples.count) / sampleRate
        let weights = phrase.map { Double(($0.display ?? $0.text).count + 2) }
        let total = weights.reduce(0, +)
        var t = start
        for (word, w) in zip(phrase, weights) {
            let d = duration * w / total
            tl.tokens.append(Timed(text: word.text, index: word.index, start: t, end: t + d))
            t += d
        }
        audio += samples
        silence(phrase.last!.sentenceEnd ? 0.3 : 0.1)
        phrase = []
    }

    for act in acts {
        switch act {
        case .say(let s):
            phrase.append(s)
            if s.sentenceEnd { try flush() }
        case .pause(let seconds):
            try flush()
            tl.pauses.append(Pause(start: now(), end: now() + seconds))
            silence(seconds)
        case .resume:
            try flush()
            tl.resumes.append(now())
        }
    }
    try flush()
    tl.end = now()
    silence(1.0)
    return (audio, tl)
}

// MARK: - Noise

let noiseText = """
Good evening and welcome to the late news. Heavy rain is expected across the region this weekend, \
with flooding possible near the river. In sports, the home side won again last night with a goal \
in the final minute, and fans celebrated in the streets until early morning. Traffic on the main \
bridge will be reduced to one lane next week while engineers repair the surface. Markets closed \
slightly higher today as investors waited for the central bank decision on interest rates.
"""

func noise(_ kind: NoiseKind, length: Int, cache: URL) throws -> [Float] {
    func loop(_ x: [Float], offset: Int) -> [Float] {
        (0..<length).map { x[($0 + offset) % x.count] }
    }
    switch kind {
    case .hvac:   // brown noise: low rumble like air handling
        var rng = RNG(state: 42)
        var v: Float = 0
        return (0..<length).map { _ in
            v = 0.995 * v + Float(rng.unit() - 0.5) * 0.1
            return v
        }
    case .tv:
        return loop(try synth(noiseText, voice: "Fred", wpm: 170, cache: cache), offset: 0)
    case .babble:
        var mix = [Float](repeating: 0, count: length)
        for (k, voice) in ["Daniel", "Karen", "Moira", "Tessa"].enumerated() {
            let talker = loop(try synth(noiseText, voice: voice, wpm: 160 + Double(k) * 10, cache: cache),
                              offset: k * Int(3.7 * sampleRate))
            for i in 0..<length { mix[i] += talker[i] }
        }
        return mix
    }
}

/// RMS level; for speech only over active samples, so pauses don't dilute it.
func rms(_ x: [Float], activeOnly: Bool) -> Double {
    let samples = activeOnly ? x.filter { abs($0) > 0.01 } : x
    guard !samples.isEmpty else { return 0 }
    return sqrt(samples.reduce(0) { $0 + Double($1 * $1) } / Double(samples.count))
}

func mix(_ speech: [Float], _ noise: [Float], snr: Double) -> [Float] {
    let gain = Float(rms(speech, activeOnly: true) / rms(noise, activeOnly: false) / pow(10, snr / 20))
    var out = zip(speech, noise).map { $0 + $1 * gain }
    let peak = out.map(abs).max() ?? 1
    if peak > 0.99 { out = out.map { $0 * 0.99 / peak } }
    return out
}

// MARK: - Recognition (mirrors SpeechFollower / SpeechRecognizer)

func contextualStrings(script: PromptScript, fromWord word: Int) -> [String] {
    var seen = Set<String>()
    var out: [String] = []
    for w in script.words.dropFirst(word) {
        let t = w.text.lowercased().filter { $0.isLetter || $0.isNumber }
        if t.count >= 5, seen.insert(t).inserted { out.append(t) }
        if out.count == 50 { break }
    }
    return out
}

func transcribe(_ audio: [Float], script: PromptScript, tl: Timeline, hints: Bool, engine: Engine) throws -> [Partial] {
    switch engine {
    case .appleOnDevice: try transcribeApple(audio, script: script, tl: tl, hints: hints, onDevice: true)
    case .appleServer(let locale): try transcribeApple(audio, script: script, tl: tl, hints: hints, onDevice: false, locale: locale)
    case .local(_, let path): try transcribeLocal(audio, script: script, hints: hints, modelPath: path)
    }
}

/// Streams `audio` in real time into SFSpeechRecognizer and collects every partial.
func transcribeApple(_ audio: [Float], script: PromptScript, tl: Timeline, hints: Bool, onDevice: Bool,
                     locale: String = "en-US") throws -> [Partial] {
    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)),
          onDevice ? recognizer.supportsOnDeviceRecognition : !recognizer.supportsOnDeviceRecognition else {
        throw NSError(domain: "speech", code: 1, userInfo: [NSLocalizedDescriptionKey:
            "\(locale): \(onDevice ? "no on-device model" : "has an on-device model, so it would not use the server")"])
    }
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    let started = Date()
    func clock() -> Double { Date().timeIntervalSince(started) }

    var partials: [Partial] = []
    var session = -1
    var request: SFSpeechAudioBufferRecognitionRequest?
    var task: SFSpeechRecognitionTask?
    var taskEnded = false

    func begin() {
        task?.cancel()
        request?.endAudio()
        session += 1
        taskEnded = false
        let id = session
        let r = SFSpeechAudioBufferRecognitionRequest()
        r.shouldReportPartialResults = true
        r.requiresOnDeviceRecognition = onDevice
        r.taskHint = .dictation
        if hints {
            let reading = tl.tokens.last { $0.end <= clock() && $0.index != nil }?.index ?? 0
            r.contextualStrings = contextualStrings(script: script, fromWord: reading)
        }
        request = r
        partials.append(Partial(t: clock(), session: id, text: ""))
        task = recognizer.recognitionTask(with: r) { result, error in
            guard id == session else { return }   // like the app's generation check
            if let result {
                partials.append(Partial(t: clock(), session: id, text: result.bestTranscription.formattedString))
                if result.isFinal { taskEnded = true }
            }
            if error != nil { taskEnded = true }
        }
    }

    begin()
    let chunk = Int(0.1 * sampleRate)
    var i = 0
    var policy = RecognitionRestartPolicy()   // as SpeechRecognizer / SpeechFollower
    policy.sessionStarted(at: 0)
    while i < audio.count {
        // The apps' audio level (min(rms × 5, 1)) for this 100 ms, as two ~50 ms updates.
        let audioTime = Double(i) / sampleRate
        var restartNow = taskEnded
        for half in 0..<2 {
            let a = i + half * chunk / 2, b = min(audio.count, a + chunk / 2)
            guard a < b else { continue }
            let rms = sqrt(audio[a..<b].reduce(Float(0)) { $0 + $1 * $1 } / Float(b - a))
            if policy.shouldRestart(level: CGFloat(min(rms * 5, 1)), at: audioTime) { restartNow = true }
        }
        if restartNow {
            begin()
            policy.sessionStarted(at: audioTime)
        }
        let n = min(chunk, audio.count - i)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n))!
        buffer.frameLength = AVAudioFrameCount(n)
        audio.withUnsafeBufferPointer { src in
            buffer.floatChannelData![0].update(from: src.baseAddress! + i, count: n)
        }
        request?.append(buffer)
        i += n
        RunLoop.main.run(until: started.addingTimeInterval(Double(i) / sampleRate))
    }
    request?.endAudio()
    RunLoop.main.run(until: Date().addingTimeInterval(2))
    task?.cancel()
    return partials
}

/// Streams `audio` in real time through the app's LocalSpeechEngine (transcribe.cpp), the way
/// SpeechRecognizer drives it: one session, `isNewWindow` re-anchors the matcher.
func transcribeLocal(_ audio: [Float], script: PromptScript, hints: Bool, modelPath: String) throws -> [Partial] {
    let engine = LocalSpeechEngine.shared
    var info: LocalSpeechEngineInfo?
    var loadError: Error?
    engine.loadModel(at: modelPath) { result in
        switch result {
        case .success(let loaded): info = loaded
        case .failure(let error): loadError = error
        }
    }
    while info == nil && loadError == nil { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
    if let loadError { throw loadError }
    guard let info else { return [] }

    // SpeechRecognizer.localLanguageHint with an en-US preference.
    let language = info.languages.first { $0.caseInsensitiveCompare("en-US") == .orderedSame }
        ?? info.languages.first { $0.lowercased().hasPrefix("en") }
        ?? (info.supportsLanguageDetection ? nil : info.languages.first)
    // SpeechRecognizer.localInitialPrompt: distinctive upcoming words, not a script echo.
    var prompt: String?
    if hints {
        var seen = Set<String>()
        var words: [String] = []
        for raw in script.text.split(separator: " ").prefix(80) {
            let word = raw.trimmingCharacters(in: .punctuationCharacters)
            guard word.count >= 6, seen.insert(word.lowercased()).inserted else { continue }
            words.append(word)
            if words.count >= 15 { break }
        }
        prompt = words.isEmpty ? nil : words.joined(separator: ", ")
    }

    let started = Date()
    func clock() -> Double { Date().timeIntervalSince(started) }
    var session = 0
    var partials = [Partial(t: 0, session: 0, text: "")]
    var finished = false
    let sessionID = engine.start(
        language: language, initialPrompt: prompt, wordTimestamps: false,
        retryEmptyWindowsOnRecentAudio: true,   // as SpeechRecognizer
        onText: { text, _, _, isNewWindow, _ in
            if isNewWindow {
                session += 1
                partials.append(Partial(t: clock(), session: session, text: ""))
            }
            partials.append(Partial(t: clock(), session: session, text: text))
        },
        onError: { message, _ in
            FileHandle.standardError.write("local engine error: \(message)\n".data(using: .utf8)!)
            finished = true
        },
        onFinished: { _ in finished = true }
    )
    let chunk = Int(0.1 * sampleRate)
    var i = 0
    while i < audio.count {
        let n = min(chunk, audio.count - i)
        engine.feed(Array(audio[i..<(i + n)]), sessionID: sessionID)
        i += n
        RunLoop.main.run(until: started.addingTimeInterval(Double(i) / sampleRate))
    }
    engine.stop(sessionID: sessionID)
    let deadline = Date().addingTimeInterval(15)
    while !finished && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
    return partials
}

// MARK: - Commands

func renderCase(_ c: AudioCase, script: PromptScript, cache: URL) throws -> (audio: [Float], tl: Timeline) {
    var rng = RNG(state: 1)
    let (speech, tl) = try render(perform(script, c.perf, &rng), voice: c.info.voice, wpm: c.info.wpm, cache: cache)
    var audio = speech
    if let kind = c.info.noise, let snr = c.info.snr {
        audio = mix(speech, try noise(kind, length: speech.count, cache: cache), snr: snr)
    }
    return (audio, tl)
}

func ttsCache() throws -> URL {
    let cache = FileManager.default.temporaryDirectory.appendingPathComponent("speech-tracking-tts")
    try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
    return cache
}

/// Writes <out>/<case>/{audio.wav, truth.json, case.json, script.txt} for app-level runs (../desktop).
func renderAudio(root: URL, out: URL, filter: String?) throws {
    let scripts = try loadScripts(root)
    let cache = try ttsCache()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    for c in audioCases() where filter == nil || c.info.id.contains(filter!) {
        let dir = out.appendingPathComponent(c.info.id)
        if FileManager.default.fileExists(atPath: dir.appendingPathComponent("audio.wav").path) { continue }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let (audio, tl) = try renderCase(c, script: scripts[c.info.script]!, cache: cache)
        try writeWAV(audio, to: dir.appendingPathComponent("audio.wav"))
        try encoder.encode(c.info).write(to: dir.appendingPathComponent("case.json"))
        try encoder.encode(tl).write(to: dir.appendingPathComponent("truth.json"))
        try String(contentsOf: root.appendingPathComponent("scripts/\(c.info.script).txt"), encoding: .utf8)
            .write(to: dir.appendingPathComponent("script.txt"), atomically: true, encoding: .utf8)
        FileHandle.standardError.write("rendered \(c.info.id) (\(Int(tl.end)) s)\n".data(using: .utf8)!)
    }
}

func recordAudio(root: URL, filter: String?, engine: Engine) throws {
    let scripts = try loadScripts(root)
    let cache = FileManager.default.temporaryDirectory.appendingPathComponent("speech-tracking-tts")
    try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
    let status = SFSpeechRecognizer.authorizationStatus()
    if status != .authorized {
        let sema = DispatchSemaphore(value: 0)
        SFSpeechRecognizer.requestAuthorization { _ in sema.signal() }
        sema.wait()
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    // Core set unless CASE names cases explicitly.
    for c in audioCases() where filter.map({ c.info.id.contains($0) || c.info.name.contains($0) })
        ?? (engine.recordsFullMatrix || coreCaseIDs.contains(c.info.id)) {
        let script = scripts[c.info.script]!
        var rng = RNG(state: 1)
        let (speech, tl) = try render(perform(script, c.perf, &rng), voice: c.info.voice, wpm: c.info.wpm, cache: cache)
        var audio = speech
        if let kind = c.info.noise, let snr = c.info.snr {
            audio = mix(speech, try noise(kind, length: speech.count, cache: cache), snr: snr)
        }
        FileHandle.standardError.write("recording \(c.info.id) with \(engine.id) (\(Int(tl.end)) s)…\n".data(using: .utf8)!)
        let partials = try transcribe(audio, script: script, tl: tl, hints: c.info.hints, engine: engine)

        let dir = root.appendingPathComponent("fixtures/\(c.info.id)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try encoder.encode(c.info).write(to: dir.appendingPathComponent("case.json"), options: .atomic)
        try encoder.encode(tl).write(to: dir.appendingPathComponent("truth.json"), options: .atomic)
        let lines = try partials.map { String(data: try JSONEncoder().encode($0), encoding: .utf8)! }
        try (lines.joined(separator: "\n") + "\n").write(to: dir.appendingPathComponent("\(engine.id).jsonl"),
                                                         atomically: true, encoding: .utf8)
    }
}

/// Word error rate of what the recognizer finally wrote vs what the voice actually said.
/// Each utterance's last partial counts (a new session, or a transcript that starts over:
/// different first words *and* shorter; revisions keep or grow their length). Separates recognizer quality from matcher quality.
func recognizerWER(_ partials: [Partial], spoken: [String]) -> Double {
    var finals: [String] = []
    var previous: [String] = []
    var previousSession = -1
    for p in partials where !p.text.isEmpty {
        let words = PromptMatcher.canonicalTokens(p.text)
        if p.session != previousSession || PromptMatcher.startsOver(words, after: previous) {
            finals += previous
        }
        previous = words
        previousSession = p.session
    }
    finals += previous
    let reference = spoken.flatMap { PromptMatcher.canonicalTokens($0) }
    guard !reference.isEmpty else { return 0 }
    var row = Array(0...finals.count)
    for i in 1...reference.count {
        var diagonal = row[0]
        row[0] = i
        for j in stride(from: 1, through: finals.count, by: 1) {
            let up = row[j]
            row[j] = reference[i - 1] == finals[j - 1] ? diagonal : min(diagonal, row[j], row[j - 1]) + 1
            diagonal = up
        }
    }
    return Double(row[finals.count]) / Double(reference.count)
}

/// Median seconds from the voice finishing a word until the recognizer's transcript
/// contains that many words. A diagnostic: high values mean the recognizer (or the
/// machine it was recorded on) fell behind, not the matcher.
func recognizerLag(_ partials: [Partial], tl: Timeline) -> Double {
    var curve: [(t: Double, words: Int)] = []
    var done = 0, current = 0, session = 0
    for p in partials {
        if p.session != session { done += current; current = 0; session = p.session }
        if !p.text.isEmpty { current = PromptMatcher.canonicalTokens(p.text).count }
        curve.append((p.t, done + current))
    }
    let lags: [Double] = tl.tokens.enumerated().compactMap { i, word in
        curve.first { $0.words >= i + 1 && $0.t >= word.end - 1 }.map { $0.t - word.end }
    }
    return percentile(lags, 0.5) ?? 0
}

func scoreAudio(root: URL, filter: String?) throws -> String {
    let scripts = try loadScripts(root)
    let fixtures = root.appendingPathComponent("fixtures")
    let ids = (try? FileManager.default.contentsOfDirectory(atPath: fixtures.path))?.sorted() ?? []
    var out = tableHeader
    var rows: [(engine: String, row: String)] = []
    var failures = 0, gated = 0, total = 0
    for id in ids where filter == nil || id.contains(filter!) {
        let dir = fixtures.appendingPathComponent(id)
        guard let caseData = try? Data(contentsOf: dir.appendingPathComponent("case.json")) else { continue }
        let info = try JSONDecoder().decode(AudioCaseInfo.self, from: caseData)
        let tl = try JSONDecoder().decode(Timeline.self, from: Data(contentsOf: dir.appendingPathComponent("truth.json")))
        let engines = (try FileManager.default.contentsOfDirectory(atPath: dir.path))
            .filter { $0.hasSuffix(".jsonl") }.map { String($0.dropLast(6)) }.sorted()
        for engine in engines {
            let partials = try String(contentsOf: dir.appendingPathComponent("\(engine).jsonl"), encoding: .utf8)
                .split(separator: "\n").map { try JSONDecoder().decode(Partial.self, from: Data($0.utf8)) }
            let result = score(script: scripts[info.script]!, tl: tl, partials: partials)
            let gating = info.gating && isGatingEngine(engine)
                && !(reportOnlyByEngine[engine]?.contains { info.id.hasPrefix($0) } ?? false)
            // WER and recognizer lag assume cumulative transcripts. Rolling-window engines
            // re-transcribe overlapping audio (and may emit recent-only text), so skip them.
            var diagnostics = "rolling window: WER n/a"
            if hasCumulativeTranscripts(engine) {
                let wer = Int((recognizerWER(partials, spoken: tl.tokens.map(\.text)) * 100).rounded())
                diagnostics = "WER \(wer)%, ASR lag " + String(format: "%.1f", recognizerLag(partials, tl: tl)) + " s"
            }
            let (row, pass) = reportRow(dimension: "\(engine) · \(info.dimension)",
                                        name: "\(info.name) [\(info.voice), \(diagnostics)]",
                                        gating: gating, noisy: info.noise != nil || info.id.hasPrefix("human-l2-"),
                                        runs: [result])
            rows.append((engine, row))
            total += 1
            if gating { gated += 1; if !pass { failures += 1 } }
        }
    }
    for (_, row) in rows.sorted(by: { $0.engine < $1.engine }) { out += row }
    out += "\nLayer B (synthetic voices → real recognizers, real audio, one take per case per engine). Matcher: \(matcherLabel)\n"
    out += "\n\(gated - failures)/\(gated) gating cases pass the launch bar (PLAN.md §8); \(total - gated) report-only.\n"
    return out
}
