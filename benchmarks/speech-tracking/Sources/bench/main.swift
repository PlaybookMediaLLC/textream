// Speech-tracking benchmark, Layer A (matcher replay with simulated speakers and ASR).
// Compiled together with the shipping matcher sources by ../run.sh. See ../PLAN.md.
//
// Pipeline per case:  script ─► Performance (what the speaker says, with ground-truth
// script indices) ─► timeline (word timings, pauses) ─► ASR model (errors, latency,
// in-progress words, session restarts) ─► cumulative partials every 250 ms ─►
// PromptMatcher ─► predicted position vs truth ─► metrics.

import Foundation

// MARK: - Deterministic RNG

struct RNG {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double { Double(next() >> 11) / Double(UInt64(1) << 53) }
    mutating func chance(_ p: Double) -> Bool { p > 0 && unit() < p }
    mutating func pick<T>(_ items: [T]) -> T { items[Int(next() % UInt64(items.count))] }
    mutating func int(_ range: ClosedRange<Int>) -> Int { range.lowerBound + Int(next() % UInt64(range.count)) }
}

func plain(_ word: String) -> String { word.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "'" } }

/// Both matchers expose the same API; MATCHER=legacy selects the pre-benchmark one (git HEAD copy).
protocol Follower {
    var recognizedCharacterCount: Int { get }
    var matchStartOffset: Int { get }
    mutating func match(transcript: String) -> Int
    mutating func restart()
}
extension PromptMatcher: Follower { mutating func restart() { restartFromCurrentProgress() } }
extension LegacyPromptMatcher: Follower { mutating func restart() { restartFromCurrentProgress() } }
let useLegacy = ProcessInfo.processInfo.environment["MATCHER"] == "legacy"

// MARK: - Speaker performance

/// What the speaker does to the script. Keys are script word indices.
struct Performance {
    var skipBefore: [Int: Int] = [:]      // before reading word i, jump forward n words
    var backAfter: [Int: Int] = [:]       // after reading word i, jump back n words
    var restartSentenceAfter: Set<Int> = [] // after reading word i, restart its sentence
    var adlibAfter: [Int: Int] = [:]      // after word i, say n off-script words
    var pauseAfter: [Int: Double] = [:]   // after word i, stay silent n seconds
    var paraphrase = 0.0                  // chance to use a contraction/synonym where one exists
    var filler = 0.0                      // chance of "um"/"you know" before a word
    var stutter = 0.0                     // chance of repeating a word
}

/// `display` is what a voice should say (original casing and punctuation, for prosody).
struct Spoken { var text: String; var index: Int?; var sentenceEnd = false; var display: String? = nil }
enum Act { case say(Spoken), pause(Double), resume }   // resume = disturbance over, back on script

let contractions: [String: String] = [
    "do not": "don't", "it is": "it's", "we are": "we're", "you will": "you'll",
    "cannot": "can't", "that is": "that's", "will not": "won't", "let us": "let's",
    "i will": "i'll", "we will": "we'll", "you are": "you're",
]
let synonyms: [String: String] = [
    "small": "little", "great": "awesome", "start": "begin", "simple": "easy", "important": "crucial",
    "people": "folks", "quickly": "fast", "show": "present", "many": "lots of", "useful": "helpful",
    "finished": "completed", "result": "outcome", "numbers": "metrics", "happy": "pleased",
    "short": "brief", "strongest": "most powerful", "thank": "thanks", "surprised": "amazed",
]
let fillers = [["um"], ["uh"], ["you", "know"], ["so"], ["like"], ["i", "mean"]]
let adlibPool = """
honestly this is something i learned the hard way when i was running my first team and we made \
every mistake you can imagine but the thing that saved us was being honest with each other about \
what was not working and fixing it together instead of pretending everything was fine
""".split(separator: " ").map(String.init)

func perform(_ script: PromptScript, _ p: Performance, _ rng: inout RNG) -> [Act] {
    let words = script.words
    var acts: [Act] = []
    var used = Set<String>()
    var i = 0
    func isSentenceEnd(_ k: Int) -> Bool { words[k].text.last.map { ".!?".contains($0) } ?? false }

    while i < words.count {
        if let n = p.skipBefore[i], used.insert("skip\(i)").inserted {
            i = min(words.count, i + n); acts.append(.resume); continue
        }
        let w = words[i]
        if w.isAnnotation { i += 1; continue }

        if rng.chance(p.filler) { for f in rng.pick(fillers) { acts.append(.say(Spoken(text: f, index: nil))) } }

        // Paraphrase: two-word contractions consume both script words.
        var spokenIndex = i
        var said: [String] = [plain(w.text)]
        if i + 1 < words.count, let c = contractions[plain(w.text) + " " + plain(words[i + 1].text)],
           rng.chance(p.paraphrase) {
            said = [c]; spokenIndex = i + 1
        } else if let c = contractions[plain(w.text)] ?? synonyms[plain(w.text)], rng.chance(p.paraphrase) {
            said = c.split(separator: " ").map(String.init)
        }
        if rng.chance(p.stutter) { acts.append(.say(Spoken(text: said[0], index: nil))) }
        for (k, s) in said.enumerated() {
            let last = k == said.count - 1
            let original = said == [plain(w.text)] ? w.text : nil
            acts.append(.say(Spoken(text: s, index: last ? spokenIndex : nil,
                                    sentenceEnd: last && isSentenceEnd(spokenIndex), display: original)))
        }
        i = spokenIndex

        if let n = p.adlibAfter[i], used.insert("adlib\(i)").inserted {
            let start = rng.int(0...(adlibPool.count - 1))
            for k in 0..<n { acts.append(.say(Spoken(text: adlibPool[(start + k) % adlibPool.count], index: nil))) }
            acts.append(.resume)
        }
        if let s = p.pauseAfter[i], used.insert("pause\(i)").inserted { acts.append(.pause(s)); acts.append(.resume) }
        if let n = p.backAfter[i], used.insert("back\(i)").inserted {
            i = max(0, i - n + 1); acts.append(.resume); continue
        }
        if p.restartSentenceAfter.contains(i), used.insert("restart\(i)").inserted {
            var j = i
            while j > 0 && !isSentenceEnd(j - 1) { j -= 1 }
            i = j; acts.append(.resume); continue
        }
        i += 1
    }
    return acts
}

// MARK: - Timeline

struct Timed: Codable { var text: String; var index: Int?; var start: Double; var end: Double }
struct Pause: Codable { var start: Double; var end: Double }
/// One recognizer partial: cumulative transcript of `session` at time `t` (seconds of audio).
/// An empty `text` marks a new session starting (the app restarts its matcher then).
struct Partial: Codable { var t: Double; var session: Int; var text: String }

struct Timeline: Codable {
    var tokens: [Timed] = []
    var resumes: [Double] = []
    var pauses: [Pause] = []
    var end = 0.0
}

func timeline(_ acts: [Act], wpm: Double, _ rng: inout RNG) -> Timeline {
    var tl = Timeline()
    var t = 0.5
    let base = 60.0 / wpm
    for act in acts {
        switch act {
        case .say(let s):
            let d = base * (0.55 + 0.45 * Double(s.text.count) / 4.7) * (0.85 + 0.3 * rng.unit())
            tl.tokens.append(Timed(text: s.text, index: s.index, start: t, end: t + d))
            t += d + (s.sentenceEnd ? 0.35 : 0.04)
        case .pause(let s):
            tl.pauses.append(Pause(start: t, end: t + s)); t += s
        case .resume:
            tl.resumes.append(t)
        }
    }
    tl.end = t
    return tl
}

// MARK: - ASR model

struct ASRModel {
    var substitution = 0.0     // word recognised wrong (accent / noise proxy)
    var deletion = 0.0         // word dropped
    var insertion = 0.0        // junk word added (noise)
    var competingSpeech = 0.0  // chance per word of a 3–8 word burst of unrelated speech (TV, colleague)
    var jargonMiss = 0.0       // chance a jargon word is transcribed with its common mis-hearing
    var latency = 0.35         // seconds from word start until it shows up in a partial
    var session = 55.0         // SFSpeech preemptive restart period (SpeechFollower)
    var restartGap = 0.6       // audio lost while a new task spins up
    var utteranceReset = 0.0   // chance the transcript starts over (same session) at a speech gap,
                               // as Apple's on-device recognizer does (seen in Layer B fixtures)
}

let jargon: [String: [String]] = [
    "kubernetes": ["cooper", "netties"], "terraform": ["terra", "form"], "postgresql": ["post", "gress", "q", "l"],
    "kubectl": ["cube", "control"], "nginx": ["engine", "x"], "prometheus": ["promethease"],
    "grafana": ["griffon", "a"], "api": ["a", "p", "i"], "json": ["jason"], "https": ["h", "t", "t", "p", "s"],
    "grpc": ["g", "r", "p", "c"], "oauth": ["oh", "off"], "jwt": ["j", "w", "t"], "yaml": ["yam", "all"],
    "ci": ["c", "i"], "redis": ["read", "is"], "ttl": ["t", "t", "l"], "sql": ["sequel"], "p99": ["p", "ninety", "nine"],
    "23": ["two", "point", "three"], "31": ["three", "point", "one"], "sdk": ["s", "d", "k"],
    "45m": ["four", "point", "five", "million"], "helm": ["hell", "um"], "git": ["get"],
]
let commonWords = ["the", "a", "and", "in", "on", "to", "of", "it", "is", "that", "for", "with", "this", "we", "you"]
let competingPool = """
and now the weather for the weekend expect heavy rain on saturday with clear skies returning on sunday \
afternoon in sports the home team won again last night with a late goal in the final minute of the match
""".split(separator: " ").map(String.init)

func corrupt(_ word: String, _ rng: inout RNG) -> String {
    var c = Array(word)
    switch rng.int(0...3) {
    case 0 where c.count > 3: c.removeLast()                         // dropped final consonant
    case 1: if let k = c.firstIndex(where: { "aeiou".contains($0) }) { c[k] = rng.pick(Array("aeiou")) } // vowel shift
    case 2 where c.count > 4: c.removeFirst(2)                       // clipped onset
    default: return rng.pick(commonWords)                            // misheard as a function word
    }
    return String(c)
}

func recognize(_ tl: Timeline, _ asr: ASRModel, _ rng: inout RNG) -> [Timed] {
    var out: [Timed] = []
    for tok in tl.tokens {
        if rng.chance(asr.competingSpeech) {
            let n = rng.int(3...8), start = rng.int(0...(competingPool.count - 1))
            let step = (tok.end - tok.start) / Double(n)
            for k in 0..<n {
                out.append(Timed(text: competingPool[(start + k) % competingPool.count], index: nil,
                                 start: tok.start + Double(k) * step, end: tok.start + Double(k + 1) * step))
            }
        }
        if rng.chance(asr.deletion) { continue }
        if let miss = jargon[tok.text], rng.chance(asr.jargonMiss) {
            let step = (tok.end - tok.start) / Double(miss.count)
            for (k, m) in miss.enumerated() {
                out.append(Timed(text: m, index: nil, start: tok.start + Double(k) * step, end: tok.start + Double(k + 1) * step))
            }
            continue
        }
        var r = tok
        if rng.chance(asr.substitution) { r.text = corrupt(tok.text, &rng) }
        out.append(r)
        if rng.chance(asr.insertion) {
            out.append(Timed(text: rng.pick(commonWords), index: nil, start: tok.end, end: tok.end + 0.05))
        }
    }
    return out
}

// MARK: - Replay + metrics

struct CaseResult {
    var seconds = 0.0
    var lostEvents = 0
    var lostSeconds = 0.0
    var aheadSeconds = 0.0
    var recoveries: [Double?] = []
    var lags: [Double] = []
    var silenceDrift = 0
    var finalError = 0
}

let tick = 0.25
let TRACE_N = Int(ProcessInfo.processInfo.environment["TRACE_N"] ?? "8") ?? 8
let trace = ProcessInfo.processInfo.environment["TRACE"] != nil
let lostWords = 8, lostAfter = 2.0, recoveredWords = 3, aheadWords = 3, recoveryGrace = 3.0

func run(script: PromptScript, perf: Performance, asr: ASRModel, wpm: Double, seed: UInt64) -> CaseResult {
    var rng = RNG(state: seed)
    let tl = timeline(perform(script, perf, &rng), wpm: wpm, &rng)
    let heard = recognize(tl, asr, &rng)
    return score(script: script, tl: tl, partials: simulatedPartials(heard, until: tl.end + 3, asr: asr, rng: &rng))
}

/// What a streaming recognizer would report every tick: cumulative transcript of the
/// current session, with the word being spoken shown as a growing prefix.
func simulatedPartials(_ heard: [Timed], until end: Double, asr: ASRModel, rng: inout RNG) -> [Partial] {
    var resets: [Double] = []
    for (a, b) in zip(heard, heard.dropFirst()) where b.start - a.end >= 0.25 && rng.chance(asr.utteranceReset) {
        resets.append(b.start)
    }
    var out: [Partial] = []
    var t = 0.0
    var session = 0
    while t <= end {
        let s = Int(t / asr.session)
        if s != session { session = s; out.append(Partial(t: t, session: s, text: "")) }
        let sessionStart = Double(s) * asr.session + (s > 0 ? asr.restartGap : 0)
        let utteranceStart = max(sessionStart, resets.last { $0 + asr.latency <= t } ?? 0)
        var parts: [String] = []
        for h in heard where h.start >= utteranceStart && h.start + asr.latency <= t {
            if h.end + asr.latency <= t {
                parts.append(h.text)
            } else {
                let frac = (t - asr.latency - h.start) / (h.end - h.start)
                parts.append(String(h.text.prefix(max(1, Int(frac * Double(h.text.count))))))
            }
        }
        if !parts.isEmpty { out.append(Partial(t: t, session: s, text: parts.joined(separator: " "))) }
        t += tick
    }
    return out
}

/// Replays partials through the matcher (as the app does: restart on each new session)
/// and scores the highlight against the ground-truth timeline.
func score(script: PromptScript, tl: Timeline, partials: [Partial]) -> CaseResult {
    let upperBounds = script.words.map(\.characterRange.upperBound)
    func wordsRead(_ offset: Int) -> Int { upperBounds.prefix { $0 <= offset }.count }

    var matcher: any Follower = useLegacy ? LegacyPromptMatcher(source: script) : PromptMatcher(source: script)
    var session = 0
    var times: [Double] = [], pred: [Int] = [], truth: [Int] = []
    var t = 0.0
    var truthNow = 0, nextTruthToken = 0, nextPartial = 0
    var lastText = ""
    let scripted = tl.tokens.filter { $0.index != nil }

    while t <= tl.end + 3 {
        while nextPartial < partials.count && partials[nextPartial].t <= t {
            let p = partials[nextPartial]
            if p.session != session { session = p.session; matcher.restart() }
            if !p.text.isEmpty { _ = matcher.match(transcript: p.text) }
            lastText = p.text
            nextPartial += 1
        }
        while nextTruthToken < scripted.count && scripted[nextTruthToken].end <= t {
            truthNow = scripted[nextTruthToken].index! + 1; nextTruthToken += 1
        }
        times.append(t); pred.append(wordsRead(matcher.recognizedCharacterCount)); truth.append(truthNow)
        if trace {
            print(String(format: "%6.2f", t), "truth", truthNow, "pred", pred.last!, "start", wordsRead(matcher.matchStartOffset), "|",
                  lastText.split(separator: " ").suffix(TRACE_N).joined(separator: " "))
        }
        t += tick
    }

    var r = CaseResult(seconds: tl.end)
    var run = 0.0
    for k in times.indices {
        // Right after the speaker skips, re-reads or returns from an ad-lib, being behind is
        // expected; that window is scored by recovery time, not as lost/ahead time.
        let inGrace = tl.resumes.contains { times[k] >= $0 && times[k] < $0 + recoveryGrace }
        let err = inGrace ? 0 : pred[k] - truth[k]
        if err > aheadWords { r.aheadSeconds += tick }
        if abs(err) > lostWords { run += tick }
        if abs(err) <= lostWords || k == times.count - 1 {
            if run >= lostAfter { r.lostEvents += 1; r.lostSeconds += run }
            run = 0
        }
    }
    r.finalError = abs(pred.last! - truth.last!)

    let hold = Int(1.0 / tick)
    for m in tl.resumes {
        guard let from = times.firstIndex(where: { $0 >= m }) else { r.recoveries.append(nil); continue }
        let hit = (from..<times.count).first { k in
            (k..<min(times.count, k + hold)).allSatisfy { abs(pred[$0] - truth[$0]) <= recoveredWords }
        }
        r.recoveries.append(hit.map { times[$0] - m })
    }

    var best = 0
    for tok in scripted {
        let need = tok.index! + 1
        guard need > best else { continue }      // only fresh forward progress
        best = need
        if tl.resumes.contains(where: { tok.end >= $0 && tok.end < $0 + recoveryGrace }) { continue } // scored as recovery
        if let k = times.firstIndex(where: { $0 >= tok.end && $0 <= tok.end + 10 && pred[times.firstIndex(of: $0)!] >= need }) {
            r.lags.append(times[k] - tok.end)
        }
    }

    for p in tl.pauses where p.end - p.start >= 1 {
        let a = times.firstIndex { $0 >= p.start + 1.0 } ?? 0
        let b = times.lastIndex { $0 <= p.end } ?? a
        // Drift = moving past where the reader stopped. Catching up to the last words
        // spoken before the pause (late transcripts) is correct, not drift.
        r.silenceDrift += max(0, pred[b] - max(pred[a], truth[b]))
    }
    return r
}

// MARK: - Cases (the eight dimensions + composite)

/// gating = false → report-only (PLAN.md §8: 0–5 dB, competing speech, extreme WER).
struct Case { var dimension: String; var name: String; var script: String; var perf = Performance(); var asr = ASRModel(); var wpm = 150.0; var gating = true }

func cases() -> [Case] {
    var c: [Case] = []
    let clean = ASRModel(substitution: 0.03, deletion: 0.01, insertion: 0.01, utteranceReset: 0.15)   // typical quiet-room on-device ASR
    c.append(Case(dimension: "baseline", name: "clean read, 150 wpm", script: "general", asr: clean))
    var resetting = clean; resetting.utteranceReset = 0.6
    c.append(Case(dimension: "baseline", name: "recognizer drops transcript at most gaps", script: "general",
                  perf: Performance(skipBefore: [150: 25], backAfter: [220: 15], adlibAfter: [90: 15], filler: 0.05), asr: resetting))

    // 1. Repeated sentences
    c.append(Case(dimension: "repeated", name: "refrains in script", script: "repeated", asr: clean))
    c.append(Case(dimension: "repeated", name: "restart sentence ×4", script: "general",
                  perf: Performance(restartSentenceAfter: [20, 75, 140, 210]), asr: clean))
    c.append(Case(dimension: "repeated", name: "re-read previous 12 words ×3", script: "general",
                  perf: Performance(backAfter: [60: 12, 150: 12, 230: 12]), asr: clean))
    c.append(Case(dimension: "repeated", name: "refrains + restart sentence ×3", script: "repeated",
                  perf: Performance(restartSentenceAfter: [30, 90, 150]), asr: clean))
    c.append(Case(dimension: "repeated", name: "stutters (8%)", script: "general", perf: Performance(stutter: 0.08), asr: clean))

    // 2. Paraphrasing
    c.append(Case(dimension: "paraphrase", name: "light: contractions + synonyms", script: "general",
                  perf: Performance(paraphrase: 1.0), asr: clean))
    c.append(Case(dimension: "paraphrase", name: "fillers + disfluency (10%)", script: "general",
                  perf: Performance(filler: 0.10, stutter: 0.03), asr: clean))
    c.append(Case(dimension: "paraphrase", name: "ad-lib 15 words ×3", script: "general",
                  perf: Performance(adlibAfter: [40: 15, 130: 15, 220: 15]), asr: clean))
    c.append(Case(dimension: "paraphrase", name: "ad-lib 45 words ×2", script: "general",
                  perf: Performance(adlibAfter: [80: 45, 200: 45]), asr: clean))

    // 3. Pauses
    for s in [2.0, 5.0, 15.0, 30.0, 60.0] {
        c.append(Case(dimension: "pauses", name: "pause \(Int(s)) s ×3", script: "general",
                      perf: Performance(pauseAfter: [50: s, 140: s, 230: s]), asr: clean))
    }

    // 4. Skipped lines
    for n in [1, 3, 6, 10, 25, 60] {
        c.append(Case(dimension: "skips", name: "skip \(n) words forward ×3", script: "general",
                      perf: Performance(skipBefore: [50: n, 140: n, 210: n]), asr: clean))
    }
    c.append(Case(dimension: "skips", name: "jump back 30 words ×2", script: "general",
                  perf: Performance(backAfter: [120: 30, 220: 30]), asr: clean))

    // 5. Speaking speed (faster speech → more ASR deletions)
    for wpm in [110.0, 150.0, 190.0, 230.0] {
        var a = clean; a.deletion += max(0, (wpm - 150) / 80 * 0.04)
        c.append(Case(dimension: "speed", name: "\(Int(wpm)) wpm", script: "general", asr: a, wpm: wpm))
    }

    // 6. Accents (simulated as ASR substitution rate — a proxy; real audio is Layer B)
    for (label, sub) in [("native-like, WER≈5%", 0.04), ("moderate, WER≈12%", 0.10), ("strong, WER≈22%", 0.18), ("very strong, WER≈35%", 0.30)] {
        c.append(Case(dimension: "accent (proxy)", name: label, script: "general",
                      asr: ASRModel(substitution: sub, deletion: sub / 4, insertion: 0.01), gating: sub < 0.3))
    }

    // 7. Background noise (SNR mapped to ASR error rates — proxy)
    for (label, e) in [("20 dB", 0.02), ("10 dB", 0.06), ("5 dB", 0.12), ("0 dB", 0.22)] {
        c.append(Case(dimension: "noise (proxy)", name: "stationary noise \(label)", script: "general",
                      asr: ASRModel(substitution: e, deletion: e, insertion: e), gating: e < 0.1))
    }
    c.append(Case(dimension: "noise (proxy)", name: "competing speech (TV) 5%", script: "general",
                  asr: ASRModel(substitution: 0.04, deletion: 0.03, insertion: 0.01, competingSpeech: 0.05)))
    c.append(Case(dimension: "noise (proxy)", name: "competing speech (TV) 12%", script: "general",
                  asr: ASRModel(substitution: 0.04, deletion: 0.03, insertion: 0.01, competingSpeech: 0.12), gating: false))

    // 8. Technical vocabulary
    for (label, miss) in [("jargon mostly recognised (hints work)", 0.2), ("jargon half mis-heard", 0.5), ("jargon mis-heard (no hints)", 0.9)] {
        var a = clean; a.jargonMiss = miss
        c.append(Case(dimension: "technical", name: label, script: "technical", asr: a))
    }

    // Composite: a realistic take with a bit of everything.
    c.append(Case(dimension: "composite", name: "realistic take", script: "general",
                  perf: Performance(skipBefore: [180: 10], restartSentenceAfter: [70], adlibAfter: [120: 12],
                                    pauseAfter: [240: 4], paraphrase: 0.3, filler: 0.04, stutter: 0.02),
                  asr: ASRModel(substitution: 0.06, deletion: 0.03, insertion: 0.02), wpm: 165))
    return c
}

// MARK: - Report

func percentile(_ xs: [Double], _ p: Double) -> Double? {
    guard !xs.isEmpty else { return nil }
    let s = xs.sorted()
    return s[min(s.count - 1, Int(Double(s.count - 1) * p))]
}
func fmt(_ x: Double?, _ digits: Int = 1) -> String { x.map { String(format: "%.\(digits)f", $0) } ?? "–" }

let tableHeader = """
| Dimension | Case | Lost/10 min | Lost % time | Recovery p50/p95 (s) | Never recovered | Ahead >3w % time | Silence drift (w) | Lag p50/p95 (s) | Final err (w) | Pass |
|---|---|---|---|---|---|---|---|---|---|---|

"""

/// One report row from all runs of a case, judged against the simplified PLAN.md §8 launch bar.
func reportRow(dimension: String, name: String, gating: Bool, runs: [CaseResult]) -> (row: String, pass: Bool) {
    var agg = CaseResult()
    for r in runs {
        agg.seconds += r.seconds; agg.lostEvents += r.lostEvents; agg.lostSeconds += r.lostSeconds
        agg.aheadSeconds += r.aheadSeconds; agg.recoveries += r.recoveries; agg.lags += r.lags
        agg.silenceDrift += r.silenceDrift; agg.finalError += r.finalError
    }
    let per10 = Double(agg.lostEvents) / agg.seconds * 600
    let never = agg.recoveries.filter { $0 == nil }.count
    let recovered = agg.recoveries.compactMap { $0 }
    let lostPct = agg.lostSeconds / agg.seconds * 100
    let aheadPct = agg.aheadSeconds / agg.seconds * 100
    let finalErr = Double(agg.finalError) / Double(runs.count)
    let lagP95 = percentile(agg.lags, 0.95)
    let recoveryP95 = percentile(recovered, 0.95)
    let pass = per10 <= 0.5 && never == 0 && agg.silenceDrift == 0 && aheadPct < 1 && (lagP95 ?? 99) <= 1.5
        && finalErr <= 3 && (recoveryP95 ?? 0) <= 4
    let row = "| \(dimension) | \(name) | \(fmt(per10, 2)) | \(fmt(lostPct)) | \(fmt(percentile(recovered, 0.5)))/\(fmt(recoveryP95)) "
        + "| \(agg.recoveries.isEmpty ? "–" : "\(never)/\(agg.recoveries.count)") | \(fmt(aheadPct)) | \(agg.silenceDrift) "
        + "| \(fmt(percentile(agg.lags, 0.5), 2))/\(fmt(lagP95, 2)) | \(fmt(finalErr)) | \(pass ? "✅" : gating ? "❌" : "⚠️ report-only") |\n"
    return (row, pass)
}

func loadScripts(_ root: URL) throws -> [String: PromptScript] {
    var scripts: [String: PromptScript] = [:]
    for name in ["general", "repeated", "technical"] {
        let text = try String(contentsOf: root.appendingPathComponent("scripts/\(name).txt"), encoding: .utf8)
        scripts[name] = PromptScript(text)
    }
    return scripts
}

let args = CommandLine.arguments
let only = ProcessInfo.processInfo.environment["CASE"]
let matcherLabel = useLegacy ? "legacy (git f9c6c94)" : "current"

switch args.count > 1 ? args[1] : "" {
case "record-audio":   // Layer B: synthesize real audio, run a real recognizer, save fixtures
    guard args.count > 3, let engine = Engine.parse(args[3]) else {
        fatalError("usage: bench record-audio <root> apple-on-device|<model.gguf>")
    }
    try recordAudio(root: URL(fileURLWithPath: args[2]), filter: only, engine: engine)
case "reader-scripts":  // stage-direction scripts for human readers (PLAN.md §5)
    try writeReaderScripts(root: URL(fileURLWithPath: args[2]))
case "ingest-audio":    // a person's take → fixture with auto-aligned truth
    guard args.count > 5 else { fatalError("usage: bench ingest-audio <root> <case> <reader> <wav>") }
    try ingestAudio(root: URL(fileURLWithPath: args[2]), caseID: args[3], reader: args[4], wav: URL(fileURLWithPath: args[5]))
case "offline-words":   // debug: offline recognizer word timings for a WAV
    _ = try offlineWordTimings(URL(fileURLWithPath: args[2]))
case "export-audio":    // the synthetic voice's clean take for a case (validates ingest)
    guard args.count > 4 else { fatalError("usage: bench export-audio <root> <case> <wav>") }
    try exportAudio(root: URL(fileURLWithPath: args[2]), caseID: args[3], out: URL(fileURLWithPath: args[4]))
case "score-audio":    // Layer B: replay saved recognizer fixtures through the matcher
    print(try scoreAudio(root: URL(fileURLWithPath: args[2]), filter: only))
default:               // Layer A: simulated speakers and ASR
    let root = URL(fileURLWithPath: args.count > 1 ? args[1] : ".")
    let seeds = args.count > 2 ? Int(args[2]) ?? 10 : 10
    let scripts = try loadScripts(root)
    var out = tableHeader
    var failures = 0, gated = 0, total = 0
    for cs in cases() where only == nil || cs.name.contains(only!) {
        let runs = (0..<seeds).map { seed in
            run(script: scripts[cs.script]!, perf: cs.perf, asr: cs.asr, wpm: cs.wpm, seed: UInt64(seed) &* 7919 &+ 17)
        }
        let (row, pass) = reportRow(dimension: cs.dimension, name: cs.name, gating: cs.gating, runs: runs)
        out += row
        total += 1
        if cs.gating { gated += 1; if !pass { failures += 1 } }
    }
    out += "\nLayer A (simulated speakers + ASR). Matcher: \(matcherLabel)\n"
    out += "\n\(gated - failures)/\(gated) gating cases pass the launch bar (PLAN.md §8); \(total - gated) report-only. Seeds per case: \(seeds).\n"
    print(out)
}
