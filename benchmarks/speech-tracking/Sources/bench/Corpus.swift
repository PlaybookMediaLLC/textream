// Real human readers reading known text:
//   * LibriSpeech dev-clean (CC BY 4.0, openslr.org/12): native English audiobook readers.
//   * Speechocean762 (CC BY 4.0, openslr.org/101): adult Mandarin-L1 speakers reading English,
//     i.e. real non-native accents.
//
//   bench human-corpus <root> <LibriSpeech/dev-clean | speechocean762> <engine>
//
// Six readers (3 female, 3 male, the first by speaker id in SPEAKERS.TXT), ~75 s of consecutive
// sentences from one chapter each. Every reader gets a straight read; two readers also get
// performances built by editing their real audio at sentence boundaries: a skip (sentences
// dropped), a re-read (a sentence repeated), a 20 s pause, 10 dB babble, and a composite. Truth
// comes from the validated auto-alignment (Human.swift) on the clean audio. Scripts are written to
// scripts/human/ with attribution; fixtures to fixtures/human-<speaker>-<variant>/.

import Foundation

struct HumanVariant {
    var name: String
    var dimension: String
    var skip: Set<Int> = []           // sentence indices not read
    var rereadAfter: Set<Int> = []    // sentence read twice
    var pauseAfter: [Int: Double] = [:]
    var noise: NoiseKind?
    var snr: Double?
}

let humanVariants: [HumanVariant] = [
    HumanVariant(name: "straight", dimension: "baseline"),
    HumanVariant(name: "skip", dimension: "skips", skip: [3, 7, 8]),
    HumanVariant(name: "reread", dimension: "repeated", rereadAfter: [4, 9]),
    HumanVariant(name: "pause", dimension: "pauses", pauseAfter: [5: 20]),
    HumanVariant(name: "babble10", dimension: "noise", noise: .babble, snr: 10),
    HumanVariant(name: "composite", dimension: "composite", skip: [6], rereadAfter: [3], pauseAfter: [9: 8],
                 noise: .babble, snr: 15),
]

struct Reader {
    var id: String
    var label: String
    var sentences: [(text: String, url: URL)]
}

func librispeechReaders(_ dir: URL) throws -> [Reader] {
    let speakersFile = dir.deletingLastPathComponent().appendingPathComponent("SPEAKERS.TXT")
    let subset = dir.lastPathComponent
    var sexOf: [String: String] = [:]
    for line in try String(contentsOf: speakersFile, encoding: .utf8).split(separator: "\n") where !line.hasPrefix(";") {
        let f = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        if f.count >= 3, f[2] == subset { sexOf[f[0]] = f[1] }
    }
    let ids = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { sexOf[$0] != nil }
        .sorted { Int($0)! < Int($1)! }
    var readers: [Reader] = []
    for sex in ["F", "M"] {
        for id in ids.filter({ sexOf[$0] == sex }).prefix(3) {
            let chapters = try FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent(id).path).sorted()
            let chapter = dir.appendingPathComponent(id).appendingPathComponent(chapters[0])
            let trans = try FileManager.default.contentsOfDirectory(atPath: chapter.path).first { $0.hasSuffix(".trans.txt") }!
            let sentences = try String(contentsOf: chapter.appendingPathComponent(trans), encoding: .utf8)
                .split(separator: "\n").map { line -> (String, URL) in
                    let parts = line.split(separator: " ", maxSplits: 1)
                    return (String(parts[1]), chapter.appendingPathComponent("\(parts[0]).flac"))
                }
            readers.append(Reader(id: id, label: "LibriSpeech reader \(id) (\(sex))", sentences: sentences))
        }
    }
    return readers
}

/// Four adult (≥20) Mandarin-L1 speakers from the train split, 2 female and 2 male by id.
func speechoceanReaders(_ dir: URL) throws -> [Reader] {
    func table(_ name: String) throws -> [String: String] {
        var out: [String: String] = [:]
        for line in try String(contentsOf: dir.appendingPathComponent("train/\(name)"), encoding: .utf8).split(separator: "\n") {
            let f = line.split(maxSplits: 1, whereSeparator: { $0 == " " || $0 == "\t" })   // tab- or space-separated
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if f.count == 2 { out[f[0]] = f[1] }
        }
        return out
    }
    let ages = try table("spk2age"), genders = try table("spk2gender"), utts = try table("spk2utt")
    var texts: [String: String] = [:]
    for line in try String(contentsOf: dir.appendingPathComponent("train/text"), encoding: .utf8).split(separator: "\n") {
        let f = line.split(separator: "\t", maxSplits: 1)
        if f.count == 2 { texts[String(f[0])] = String(f[1]) }
    }
    let adults = ages.filter { (Int($0.value) ?? 0) >= 20 }.keys.sorted()
    var readers: [Reader] = []
    for sex in ["f", "m"] {
        for id in adults.filter({ genders[$0] == sex }).prefix(2) {
            let sentences = (utts[id] ?? "").split(separator: " ").compactMap { utt -> (String, URL)? in
                texts[String(utt)].map { ($0, dir.appendingPathComponent("WAVE/SPEAKER\(id)/\(utt).WAV")) }
            }
            readers.append(Reader(id: "l2-\(id)", label: "Speechocean762 speaker \(id) (Mandarin L1, \(sex.uppercased()), age \(ages[id]!))",
                                  sentences: sentences))
        }
    }
    return readers
}

/// Ground truth for one sentence clip, relative to the clip. Each sentence is its own recording, so
/// its span is exact; inside it, word times come from recognizing the clip alone and aligning to the
/// sentence's words, clamped to the clip's measured speech span (words the recognizer missed are
/// interpolated). A heavily accented clip can't drag timings into neighbouring sentences.
func sentenceTruth(_ clip: [Float], words: [(text: String, index: Int)]) throws -> [Timed] {
    let peak = clip.map(abs).max() ?? 0
    let loud = clip.indices.filter { abs(clip[$0]) > peak * 0.05 }
    let speechStart = Double(loud.first ?? 0) / sampleRate
    let speechEnd = Double(loud.last ?? clip.count) / sampleRate
    let leadIn = 0.5
    let heard = try recognizeChunk([Float](repeating: 0, count: Int(leadIn * sampleRate)) + clip)
        .map { (word: $0.word, start: $0.start - leadIn, end: $0.end - leadIn) }
    let acts = words.map { Act.say(Spoken(text: $0.text, index: $0.index)) }
    var aligned = alignTruth(acts: acts, heard: heard).tokens.filter { $0.index != nil }
    // No usable anchors (or clamping collapses them): spread the words over the speech span by length.
    let anchors = aligned.filter { $0.start >= speechStart - 0.3 && $0.end <= speechEnd + 0.3 }.count
    if anchors < max(1, aligned.count / 3) {
        let weights = aligned.map { Double($0.text.count + 2) }
        let total = weights.reduce(0, +)
        var t = speechStart
        for k in aligned.indices {
            let d = (speechEnd - speechStart) * weights[k] / total
            aligned[k].start = t; aligned[k].end = t + d; t += d
        }
    }
    var last = speechStart
    for k in aligned.indices {   // clamp into the clip's speech span, keep order
        aligned[k].start = min(max(aligned[k].start, last), speechEnd)
        aligned[k].end = min(max(aligned[k].end, aligned[k].start), speechEnd)
        last = aligned[k].end
    }
    return aligned
}

func recordHumanCorpus(root: URL, librispeech: URL, engine: Engine, filter: String?) throws {
    let cache = FileManager.default.temporaryDirectory.appendingPathComponent("speech-tracking-tts")
    try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
    let isSpeechocean = FileManager.default.fileExists(atPath: librispeech.appendingPathComponent("train/spk2utt").path)
    let readers = isSpeechocean ? try speechoceanReaders(librispeech) : try librispeechReaders(librispeech)
    let source = isSpeechocean ? "speechocean" : "librispeech" 
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    for (r, reader) in readers.enumerated() {
        // Consecutive sentences, ~75 s.
        var sentences: [(text: String, audio: [Float])] = []
        var seconds = 0.0
        for sentence in reader.sentences where seconds < 75 {
            let audio = try readMono(sentence.url)
            sentences.append((sentence.text.capitalized + ".", audio))
            seconds += Double(audio.count) / sampleRate
        }
        let scriptName = "human/\(source)-\(reader.id)"
        var sentenceTimings: [Int: [Timed]] = [:]
        let scriptText = "\(sentences.map(\.text).joined(separator: " "))\n"
        let scriptURL = root.appendingPathComponent("scripts/\(scriptName).txt")
        try FileManager.default.createDirectory(at: scriptURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try scriptText.write(to: scriptURL, atomically: true, encoding: .utf8)
        let script = PromptScript(scriptText)
        // Script word range of each sentence.
        var ranges: [Range<Int>] = []
        var offset = 0
        for s in sentences {
            let n = splitPromptTextIntoWords(s.text).count
            ranges.append(offset..<(offset + n))
            offset += n
        }

        for variant in humanVariants where variant.name == "straight" || r % 3 == 0 {   // variants for 2 readers
            let id = "human-\(reader.id)-\(variant.name)"
            if let filter, !id.contains(filter) { continue }
            // Assemble the take from the real sentence recordings; each sentence's truth is placed
            // at its exact offset (sentenceTruth, cached per sentence).
            var audio = [Float](repeating: 0, count: Int(0.5 * sampleRate))
            let gap = [Float](repeating: 0, count: Int(0.3 * sampleRate))
            var tl = Timeline()
            func now() -> Double { Double(audio.count) / sampleRate }
            func say(_ k: Int) throws {
                if sentenceTimings[k] == nil {
                    let words = ranges[k].flatMap { i in PromptMatcher.canonicalTokens(script.words[i].text).map { (text: $0, index: i) } }
                    sentenceTimings[k] = try sentenceTruth(sentences[k].audio, words: words)
                }
                let offset = now()
                tl.tokens += sentenceTimings[k]!.map { Timed(text: $0.text, index: $0.index, start: $0.start + offset, end: $0.end + offset) }
                audio += sentences[k].audio + gap
            }
            var pendingResume = false
            for k in sentences.indices {
                if variant.skip.contains(k) { pendingResume = true; continue }
                if pendingResume { tl.resumes.append(now()); pendingResume = false }
                try say(k)
                if variant.rereadAfter.contains(k) { tl.resumes.append(now()); try say(k) }
                if let s = variant.pauseAfter[k] {
                    tl.pauses.append(Pause(start: now(), end: now() + s))
                    audio += [Float](repeating: 0, count: Int(s * sampleRate))
                    tl.resumes.append(now())
                }
            }
            tl.end = now()
            audio += [Float](repeating: 0, count: Int(sampleRate))
            FileHandle.standardError.write("\(id): \(Int(Double(audio.count) / sampleRate)) s through \(engine.id)…\n".data(using: .utf8)!)
            var heardAudio = audio
            if let kind = variant.noise, let snr = variant.snr {
                heardAudio = mix(audio, try noise(kind, length: audio.count, cache: cache), snr: snr)
            }
            let truthOnly = ProcessInfo.processInfo.environment["TRUTH_ONLY"] != nil   // rebuild truth.json only
            let partials = truthOnly ? [] : try transcribe(heardAudio, script: script, tl: tl, hints: true, engine: engine)

            let info = AudioCaseInfo(id: id, dimension: "human · \(variant.dimension)",
                                     name: "\(reader.label), \(variant.name)",
                                     script: scriptName, voice: "human: \(isSpeechocean ? "Speechocean762" : "LibriSpeech") \(reader.id)", wpm: 0,
                                     noise: variant.noise, snr: variant.snr, truthSource: "auto-aligned")
            let dir = root.appendingPathComponent("fixtures/\(id)")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try encoder.encode(info).write(to: dir.appendingPathComponent("case.json"), options: .atomic)
            try encoder.encode(tl).write(to: dir.appendingPathComponent("truth.json"), options: .atomic)
            if truthOnly { continue }
            let lines = try partials.map { String(data: try JSONEncoder().encode($0), encoding: .utf8)! }
            try (lines.joined(separator: "\n") + "\n").write(to: dir.appendingPathComponent("\(engine.id).jsonl"),
                                                             atomically: true, encoding: .utf8)
        }
    }
}
