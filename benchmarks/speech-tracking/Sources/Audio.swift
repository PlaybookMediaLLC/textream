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
    var engine = "apple-on-device"
}

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

/// Which recognizer record-audio uses: ENGINE=apple-on-device (default), apple-server,
/// or local:<path to .gguf> (transcribe.cpp, run by ENGINE_TOOL from ../desktop).
let engineSpec = ProcessInfo.processInfo.environment["ENGINE"] ?? "apple-on-device"

/// Engines whose Layer B results gate CI (GATE_ENGINES=a,b overrides).
let gatingEngines = Set((ProcessInfo.processInfo.environment["GATE_ENGINES"] ?? "apple-on-device").split(separator: ",").map(String.init))

/// File-name-safe engine id, used as the fixture file name: <case>/<engine id>.jsonl.
func engineID(_ spec: String) -> String {
    guard spec.hasPrefix("local:") else { return spec }
    let file = URL(fileURLWithPath: String(spec.dropFirst(6))).deletingPathExtension().lastPathComponent
    return "local-" + file.lowercased().map { $0.isLetter || $0.isNumber || $0 == "." ? $0 : "-" }.map(String.init).joined()
}

func transcribe(_ audio: [Float], script: PromptScript, tl: Timeline, hints: Bool) throws -> [Partial] {
    if engineSpec.hasPrefix("local:") {
        return try transcribeLocal(audio, model: String(engineSpec.dropFirst(6)), script: script, hints: hints)
    }
    return try transcribeApple(audio, script: script, tl: tl, hints: hints, onDevice: engineSpec != "apple-server")
}

/// Runs the local engine through the ../desktop engine tool (it links transcribe.cpp,
/// which this harness doesn't, so CI can score fixtures without the native library).
func transcribeLocal(_ audio: [Float], model: String, script: PromptScript, hints: Bool) throws -> [Partial] {
    guard let tool = ProcessInfo.processInfo.environment["ENGINE_TOOL"] else {
        throw NSError(domain: "speech", code: 2, userInfo: [NSLocalizedDescriptionKey: "ENGINE_TOOL not set (go run ../desktop/run.go engine-tool)"])
    }
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("speech-tracking-local-\(getpid())")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let wav = dir.appendingPathComponent("audio.wav"), out = dir.appendingPathComponent("partials.jsonl")
    try writeWav(audio, to: wav)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: tool)
    var arguments = ["transcribe", "--audio", wav.path, "--model", model, "--out", out.path]
    if hints {   // the app's local initial prompt: distinctive upcoming words
        var seen = Set<String>()
        let words = script.words.map(\.text).filter { $0.count >= 6 && seen.insert($0.lowercased()).inserted }.prefix(15)
        arguments += ["--prompt", words.joined(separator: ", ")]
    }
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw NSError(domain: "speech", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "engine tool failed"])
    }
    return try String(contentsOf: out, encoding: .utf8).split(separator: "\n")
        .map { try JSONDecoder().decode(Partial.self, from: Data($0.utf8)) }
}

func writeWav(_ samples: [Float], to url: URL) throws {
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    let file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
    buffer.frameLength = AVAudioFrameCount(samples.count)
    samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
    try file.write(from: buffer)
}

/// Streams `audio` in real time into SFSpeechRecognizer and collects every partial.
func transcribeApple(_ audio: [Float], script: PromptScript, tl: Timeline, hints: Bool, onDevice: Bool) throws -> [Partial] {
    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
          !onDevice || recognizer.supportsOnDeviceRecognition else {
        throw NSError(domain: "speech", code: 1, userInfo: [NSLocalizedDescriptionKey: "on-device en-US recognition unavailable"])
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
    var sessionStart = 0.0
    while i < audio.count {
        if clock() - sessionStart >= 55 || taskEnded {   // app: preemptive restart / restart on end
            begin()
            sessionStart = clock()
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

// MARK: - Commands

/// A case's audio (speech plus noise) and its ground-truth timeline.
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

/// Writes <out>/<case>/{audio.wav, truth.json, case.json, script.txt} for app-level runs.
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
        try writeWav(audio, to: dir.appendingPathComponent("audio.wav"))
        try encoder.encode(c.info).write(to: dir.appendingPathComponent("case.json"))
        try encoder.encode(tl).write(to: dir.appendingPathComponent("truth.json"))
        try String(contentsOf: root.appendingPathComponent("scripts/\(c.info.script).txt"), encoding: .utf8)
            .write(to: dir.appendingPathComponent("script.txt"), atomically: true, encoding: .utf8)
        FileHandle.standardError.write("rendered \(c.info.id) (\(Int(tl.end)) s)\n".data(using: .utf8)!)
    }
}

func recordAudio(root: URL, filter: String?) throws {
    let scripts = try loadScripts(root)
    let cache = try ttsCache()
    let status = SFSpeechRecognizer.authorizationStatus()
    if engineSpec.hasPrefix("apple"), status != .authorized {
        let sema = DispatchSemaphore(value: 0)
        SFSpeechRecognizer.requestAuthorization { _ in sema.signal() }
        sema.wait()
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    for c in audioCases() where filter == nil || c.info.id.contains(filter!) || c.info.name.contains(filter!) {
        let script = scripts[c.info.script]!
        let (audio, tl) = try renderCase(c, script: script, cache: cache)
        FileHandle.standardError.write("recording \(c.info.id) with \(engineID(engineSpec)) (\(Int(tl.end)) s)…\n".data(using: .utf8)!)
        let partials = try transcribe(audio, script: script, tl: tl, hints: c.info.hints)

        let dir = root.appendingPathComponent("fixtures/\(c.info.id)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try encoder.encode(c.info).write(to: dir.appendingPathComponent("case.json"))
        try encoder.encode(tl).write(to: dir.appendingPathComponent("truth.json"))
        let lines = try partials.map { String(data: try JSONEncoder().encode($0), encoding: .utf8)! }
        try (lines.joined(separator: "\n") + "\n").write(to: dir.appendingPathComponent("\(engineID(engineSpec)).jsonl"),
                                                         atomically: true, encoding: .utf8)
    }
}

func scoreAudio(root: URL, filter: String?) throws -> String {
    let scripts = try loadScripts(root)
    let fixtures = root.appendingPathComponent("fixtures")
    let ids = (try? FileManager.default.contentsOfDirectory(atPath: fixtures.path))?.sorted() ?? []
    var out = tableHeader
    var failures = 0, gated = 0, total = 0
    // One fixture file per engine in each case directory; rows grouped by engine.
    var rows: [(engine: String, row: String)] = []
    for id in ids where filter == nil || id.contains(filter!) {
        let dir = fixtures.appendingPathComponent(id)
        guard let caseData = try? Data(contentsOf: dir.appendingPathComponent("case.json")) else { continue }
        let info = try JSONDecoder().decode(AudioCaseInfo.self, from: caseData)
        let tl = try JSONDecoder().decode(Timeline.self, from: Data(contentsOf: dir.appendingPathComponent("truth.json")))
        let engines = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasSuffix(".jsonl") }.map { String($0.dropLast(6)) }.sorted()
        for engine in engines {
            let partials = try String(contentsOf: dir.appendingPathComponent("\(engine).jsonl"), encoding: .utf8)
                .split(separator: "\n").map { try JSONDecoder().decode(Partial.self, from: Data($0.utf8)) }
            let result = score(script: scripts[info.script]!, tl: tl, partials: partials)
            // Only the shipping default engine gates CI; other engines are report-only
            // until one is chosen as a default (benchmarks/PLAN.md #1).
            let gating = info.gating && gatingEngines.contains(engine)
            let (row, pass) = reportRow(dimension: info.dimension, name: "\(info.name) [\(info.voice)] · `\(engine)`",
                                        gating: gating, runs: [result])
            rows.append((engine, row))
            total += 1
            if gating { gated += 1; if !pass { failures += 1 } }
        }
    }
    for r in rows.sorted(by: { $0.engine < $1.engine }) { out += r.row }
    out += "\nLayer B (synthetic voices → real recognizers, real audio, one take per case and engine). Matcher: \(matcherLabel)\n"
    out += "\n\(gated - failures)/\(gated) gating cases pass the launch bar (PLAN.md §8); \(total - gated) report-only.\n"
    return out
}
