// Human readers (PLAN.md §5): the same Layer B cases, performed by people.
//
//   bench reader-scripts <root>                       → scripts/readers/<case>.md (stage directions)
//   bench ingest-audio <root> <case> <reader> <wav>   → fixtures/<case>-human-<reader>/
//   bench export-audio <root> <case> <wav>            → the synthetic voice's clean take (to validate ingest)
//   bench offline-words <wav>                         → debug: word timings ingest would use (TRUTH_DEBUG=1)
//
// Ingest builds ground truth automatically: Apple's on-device recognizer gives word timings
// (in ~45 s chunks, see offlineWordTimings), which are aligned to the case's expected performance,
// so each spoken word gets its script index. case.json marks it `truthSource: auto-aligned` until
// someone reviews it. Validated on synthetic takes with exact truth: word end times within 0.07 s
// median (≤0.26 s p95), skip/pause boundaries within 0.1 s, identical scores.

import AVFoundation
import Foundation
import Speech

/// The case's performance as stage directions a person can read from.
func readerScript(_ c: AudioCase, script: PromptScript) -> String {
    let p = c.perf
    var out = "# \(c.info.name): reader's script\n\n"
    out += "- Read at about \(Int(c.info.wpm)) words per minute, in a quiet room, mono, as close to 16 kHz WAV as your recorder allows.\n"
    out += "- Follow the **[bracketed directions]** exactly; they are what this case measures.\n"
    if p.paraphrase > 0 { out += "- Paraphrase lightly: use contractions (don't, it's) and your own synonyms where natural.\n" }
    if p.filler > 0 { out += "- Add the occasional filler (um, uh, you know).\n" }
    if p.stutter > 0 { out += "- Now and then repeat a word, as people do.\n" }
    if let noise = c.info.noise, let snr = c.info.snr {
        out += "- Don't add noise yourself: \(noise.rawValue) at \(Int(snr)) dB SNR is mixed in at ingest.\n"
    }
    out += "\n---\n\n"
    var skipUntil = -1
    var sinceBreak = 0
    for (i, word) in script.words.enumerated() {
        if let n = p.skipBefore[i] {
            out += "**[SKIP the struck-out words, continue at “\(script.words[min(i + n, script.words.count - 1)].text)”]** "
            skipUntil = i + n
        }
        out += i < skipUntil ? "~~\(word.text)~~ " : "\(word.text) "
        if let n = p.adlibAfter[i] { out += "**[AD-LIB about \(n) words in your own words, then continue]** " }
        if let s = p.pauseAfter[i] { out += "**[PAUSE \(Int(s)) s]** " }
        if let n = p.backAfter[i] {
            out += "**[GO BACK and re-read from “\(script.words[max(0, i - n + 1)].text)” (\(n) words back)]** "
        }
        if p.restartSentenceAfter.contains(i) { out += "**[STOP, restart this sentence from its first word]** " }
        sinceBreak += 1
        if sinceBreak >= 40, word.text.last.map({ ".!?".contains($0) }) == true {   // paragraph roughly every 40 words
            out += "\n\n"
            sinceBreak = 0
        }
    }
    return out + "\n"
}

func writeReaderScripts(root: URL) throws {
    let scripts = try loadScripts(root)
    let dir = root.appendingPathComponent("scripts/readers")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for c in audioCases() where !c.info.id.hasPrefix("accent-l1") {   // non-native proxies need real L2 readers instead
        try readerScript(c, script: scripts[c.info.script]!).write(
            to: dir.appendingPathComponent("\(c.info.id).md"), atomically: true, encoding: .utf8)
    }
}

func writeWAV(_ samples: [Float], to url: URL) throws {
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
    buffer.frameLength = AVAudioFrameCount(samples.count)
    samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
    try file.write(from: buffer)
}

func exportAudio(root: URL, caseID: String, out: URL) throws {
    guard let c = audioCases().first(where: { $0.info.id == caseID }) else { throw usage("unknown case \(caseID)") }
    let scripts = try loadScripts(root)
    let cache = FileManager.default.temporaryDirectory.appendingPathComponent("speech-tracking-tts")
    try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
    var rng = RNG(state: 1)
    let (speech, _) = try render(perform(scripts[c.info.script]!, c.perf, &rng), voice: c.info.voice, wpm: c.info.wpm, cache: cache)
    // WITH_NOISE=1 exports what the recognizer heard (for debugging engines).
    if ProcessInfo.processInfo.environment["WITH_NOISE"] != nil, let kind = c.info.noise, let snr = c.info.snr {
        try writeWAV(mix(speech, try noise(kind, length: speech.count, cache: cache), snr: snr), to: out)
    } else {
        try writeWAV(speech, to: out)
    }
}

func usage(_ message: String) -> NSError {
    NSError(domain: "bench", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
}

/// Word timings for a whole take. A recognition request stops after about a minute, so the
/// take is recognized in ~45 s chunks cut at the quietest nearby moment (no split words).
func offlineWordTimings(_ url: URL) throws -> [(word: String, start: Double, end: Double)] {
    let audio = try readMono(url)
    let frame = Int(0.2 * sampleRate)
    var cuts = [0]
    while audio.count - cuts.last! > Int(50 * sampleRate) {
        let target = cuts.last! + Int(45 * sampleRate)
        let candidates = stride(from: target - Int(5 * sampleRate), to: target + Int(5 * sampleRate), by: frame)
        let quietest = candidates.min { a, b in
            audio[a..<a + frame].reduce(0) { $0 + abs($1) } < audio[b..<b + frame].reduce(0) { $0 + abs($1) }
        }!
        cuts.append(quietest + frame / 2)
    }
    cuts.append(audio.count)
    var all: [(word: String, start: Double, end: Double)] = []
    for (a, b) in zip(cuts, cuts.dropFirst()) {
        // A chunk cut inside continuous speech decodes to nothing without a clean onset,
        // so each gets 0.5 s of lead-in silence (subtracted from the timestamps).
        let leadIn = 0.5
        let offset = Double(a) / sampleRate - leadIn
        let samples = [Float](repeating: 0, count: Int(leadIn * sampleRate)) + Array(audio[a..<b])
        all += try recognizeChunk(samples).map { ($0.word, $0.start + offset, $0.end + offset) }
        RunLoop.main.run(until: Date().addingTimeInterval(1))   // let the previous task wind down
    }
    if ProcessInfo.processInfo.environment["TRUTH_DEBUG"] != nil {
        print("offline words:", all.count, "last end:", all.last?.end ?? 0, "chunks:", cuts.count - 1)
    }
    return all
}

/// Apple's on-device recognizer, fed one chunk faster than real time. Segment timestamps are in
/// audio time. A new utterance after a pause starts the transcript over, so each utterance's
/// last partial is kept.
/// Wall-clock seconds per 1 s audio buffer when deriving truth timings. Faster than real time
/// drops audio on some real voices (a LibriSpeech take lost 60% of its words at 4×).
let truthFeedSeconds = Double(ProcessInfo.processInfo.environment["TRUTH_FEED_SECONDS"] ?? "1.0")!

func recognizeChunk(_ audio: [Float]) throws -> [(word: String, start: Double, end: Double)] {
    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else { throw usage("no en-US recognizer") }
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.requiresOnDeviceRecognition = true
    request.shouldReportPartialResults = true
    var committed: [(word: String, start: Double, end: Double)] = []
    var current: [(word: String, start: Double, end: Double)] = []
    var done = false
    func words(_ t: SFTranscription) -> [(word: String, start: Double, end: Double)] {
        t.segments.flatMap { segment in
            let pieces = PromptMatcher.canonicalTokens(segment.substring)
            let step = segment.duration / Double(max(1, pieces.count))
            return pieces.enumerated().map { (k, piece) in
                (word: piece, start: segment.timestamp + Double(k) * step, end: segment.timestamp + Double(k + 1) * step)
            }
        }
    }
    let task = recognizer.recognitionTask(with: request) { result, error in
        if let result {
            let next = words(result.bestTranscription)
            if result.isFinal { done = true }
            // The recognizer often ends with an empty final result; it isn't a transcript.
            guard !next.isEmpty else { return }
            if PromptMatcher.startsOver(next.map(\.word), after: current.map(\.word)) {
                committed += current   // the previous utterance ended
            }
            current = next
        }
        if let error {
            if ProcessInfo.processInfo.environment["TRUTH_DEBUG"] != nil { print("  chunk error:", error.localizedDescription) }
            done = true
        }
    }
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    let chunk = Int(sampleRate)   // 1 s buffers, paced by truthFeedSeconds
    var i = 0
    while i < audio.count {
        let n = min(chunk, audio.count - i)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n))!
        buffer.frameLength = AVAudioFrameCount(n)
        audio.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress! + i, count: n) }
        request.append(buffer)
        i += n
        RunLoop.main.run(until: Date().addingTimeInterval(truthFeedSeconds))
    }
    request.endAudio()
    let deadline = Date().addingTimeInterval(120)
    while !done && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
    task.cancel()
    if ProcessInfo.processInfo.environment["TRUTH_DEBUG"] != nil {
        print("  chunk \(String(format: "%.1f", Double(audio.count) / sampleRate)) s → \(committed.count + current.count) words, finished: \(done)")
    }
    return committed + current
}

/// Aligns recognized words to the expected performance (global alignment, Levenshtein-style):
/// matched or substituted words take the expected token's script index and the recognized
/// timing; expected words the recognizer missed get interpolated times; extra words (the
/// reader's own ad-lib, fillers) become off-script tokens.
func alignTruth(acts: [Act], heard: [(word: String, start: Double, end: Double)]) -> Timeline {
    var expected: [(text: String, index: Int?)] = []
    var resumeBefore = Set<Int>()
    var pauseBefore = Set<Int>()
    for act in acts {
        switch act {
        case .say(let s):
            for t in PromptMatcher.canonicalTokens(s.text) { expected.append((t, s.index)) }
        case .resume: resumeBefore.insert(expected.count)
        case .pause: pauseBefore.insert(expected.count)
        }
    }
    let n = expected.count, m = heard.count
    func same(_ a: String, _ b: String) -> Bool {
        a == b || (min(a.count, b.count) >= 4 && PromptMatcher.editDistance(a, b) <= 1)
    }
    var cost = [[Int]](repeating: [Int](repeating: 0, count: m + 1), count: n + 1)
    for i in 0...n { cost[i][0] = i }
    for j in 0...m { cost[0][j] = j }
    if n > 0 && m > 0 {
        for i in 1...n {
            for j in 1...m {
                cost[i][j] = min(cost[i - 1][j - 1] + (same(expected[i - 1].text, heard[j - 1].word) ? 0 : 1),
                                 cost[i - 1][j] + 1, cost[i][j - 1] + 1)
            }
        }
    }
    // Traceback: expected i ↔ heard j (or nil).
    var pairOf = [Int?](repeating: nil, count: n)
    var extras: [Int] = []
    var i = n, j = m
    while i > 0 || j > 0 {
        if i > 0, j > 0, cost[i][j] == cost[i - 1][j - 1] + (same(expected[i - 1].text, heard[j - 1].word) ? 0 : 1) {
            pairOf[i - 1] = j - 1; i -= 1; j -= 1
        } else if i > 0, cost[i][j] == cost[i - 1][j] + 1 {
            i -= 1
        } else {
            extras.append(j - 1); j -= 1
        }
    }
    // Times for every expected token; interpolate the ones the recognizer missed.
    var times = [(start: Double, end: Double)?](repeating: nil, count: n)
    for k in 0..<n { if let h = pairOf[k] { times[k] = (heard[h].start, heard[h].end) } }
    for k in 0..<n where times[k] == nil {
        let before = (0..<k).last { times[$0] != nil }.map { times[$0]!.end } ?? 0
        let afterIndex = (k + 1..<n).first { times[$0] != nil }
        let after = afterIndex.map { times[$0]!.start } ?? before + 0.3
        let missing = (afterIndex ?? n) - ((0..<k).last { times[$0] != nil }.map { $0 + 1 } ?? 0)
        let slot = max(0.05, (after - before) / Double(max(1, missing)))
        let offset = k - ((0..<k).last { times[$0] != nil }.map { $0 + 1 } ?? 0)
        times[k] = (before + Double(offset) * slot, before + Double(offset + 1) * slot)
    }
    var tl = Timeline()
    tl.tokens = expected.indices.map { Timed(text: expected[$0].text, index: expected[$0].index, start: times[$0]!.start, end: times[$0]!.end) }
    tl.tokens += extras.map { Timed(text: heard[$0].word, index: nil, start: heard[$0].start, end: heard[$0].end) }
    tl.tokens.sort { $0.start < $1.start }
    for k in resumeBefore where k < n { tl.resumes.append(times[k]!.start) }
    for k in pauseBefore where k > 0 && k < n { tl.pauses.append(Pause(start: times[k - 1]!.end, end: times[k]!.start)) }
    tl.resumes.sort()
    tl.pauses.sort { $0.start < $1.start }
    tl.end = tl.tokens.last?.end ?? 0
    return tl
}

func ingestAudio(root: URL, caseID: String, reader: String, wav: URL) throws {
    guard let c = audioCases().first(where: { $0.info.id == caseID }) else { throw usage("unknown case \(caseID)") }
    let scripts = try loadScripts(root)
    let script = scripts[c.info.script]!
    let speech = try readMono(wav)
    let file = try AVAudioFile(forReading: wav)
    guard file.processingFormat.sampleRate == sampleRate, file.processingFormat.channelCount == 1 else {
        throw usage("need 16 kHz mono: afconvert -f WAVE -d LEF32@16000 -c 1 in.m4a out.wav")
    }
    FileHandle.standardError.write("aligning truth for \(caseID) (\(reader))…\n".data(using: .utf8)!)
    var rng = RNG(state: 1)
    let tl = alignTruth(acts: perform(script, c.perf, &rng), heard: try offlineWordTimings(wav))
    var audio = speech
    if let kind = c.info.noise, let snr = c.info.snr {
        let cache = FileManager.default.temporaryDirectory.appendingPathComponent("speech-tracking-tts")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        audio = mix(speech, try noise(kind, length: speech.count, cache: cache), snr: snr)
    }
    FileHandle.standardError.write("streaming \(Int(Double(audio.count) / sampleRate)) s through the recognizer…\n".data(using: .utf8)!)
    let partials = try transcribe(audio, script: script, tl: tl, hints: c.info.hints, engine: .appleOnDevice)

    var info = c.info
    info.id = "\(caseID)-human-\(reader)"
    info.voice = "human: \(reader)"
    info.truthSource = "auto-aligned"
    let dir = root.appendingPathComponent("fixtures/\(info.id)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(info).write(to: dir.appendingPathComponent("case.json"), options: .atomic)
    try encoder.encode(tl).write(to: dir.appendingPathComponent("truth.json"), options: .atomic)
    let lines = try partials.map { String(data: try JSONEncoder().encode($0), encoding: .utf8)! }
    try (lines.joined(separator: "\n") + "\n").write(to: dir.appendingPathComponent("apple-on-device.jsonl"),
                                                     atomically: true, encoding: .utf8)
}
