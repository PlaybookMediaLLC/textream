// score-app: scores a BENCHMARK build of the app (benchmarks/desktop) that read a rendered
// case (render-audio) from its own event log. Unlike score-audio, nothing is replayed: the
// track scored is what the app's overlay actually showed, frame by frame, and the latency
// of every word is split into stages (benchmarks/PLAN.md #2, #6).

import Foundation

struct AppEvent {
    var e: String
    var mono: UInt64
    var fields: [String: Any]
    func int(_ key: String) -> Int? { (fields[key] as? NSNumber)?.intValue }
    func double(_ key: String) -> Double? { (fields[key] as? NSNumber)?.doubleValue }
    func string(_ key: String) -> String? { fields[key] as? String }
}

func readAppLog(_ url: URL) throws -> [AppEvent] {
    try String(contentsOf: url, encoding: .utf8).split(separator: "\n").compactMap { line in
        guard let object = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
              let e = object["e"] as? String, let mono = (object["mono"] as? NSNumber)?.uint64Value else { return nil }
        return AppEvent(e: e, mono: mono, fields: object)
    }
}

/// Repeats a case's timeline `loops` times back to back: looped audio, with the app jumping
/// back to the top of the script at each loop (so indices restart and each loop start is a
/// recovery point).
func looped(_ tl: Timeline, period: Double, loops: Int) -> Timeline {
    guard loops > 1 else { return tl }
    var out = Timeline()
    for k in 0..<loops {
        let dt = Double(k) * period
        out.tokens += tl.tokens.map { Timed(text: $0.text, index: $0.index, start: $0.start + dt, end: $0.end + dt) }
        out.pauses += tl.pauses.map { Pause(start: $0.start + dt, end: $0.end + dt) }
        out.resumes += tl.resumes.map { $0 + dt } + (k > 0 ? [dt] : [])
    }
    out.end = Double(loops - 1) * period + tl.end
    return out
}

/// Adds p50/p95 of each latency stage (seconds) to `metrics`; returns "" for interpolation.
func recordStages(_ stats: StageStats, into metrics: inout [String: Double]) -> String {
    for (name, xs) in [("asr", stats.asr), ("hop", stats.hop), ("matcher", stats.matcher), ("render", stats.render), ("e2e", stats.total)] {
        if let p50 = percentile(xs, 0.5) { metrics["\(name)P50"] = p50 }
        if let p95 = percentile(xs, 0.95) { metrics["\(name)P95"] = p95 }
    }
    return ""
}

struct StageStats {
    var asr: [Double] = [], hop: [Double] = [], matcher: [Double] = [], render: [Double] = [], total: [Double] = []
}

func ms(_ xs: [Double]) -> String {
    guard !xs.isEmpty else { return "–" }
    return "\(fmt(percentile(xs, 0.5).map { $0 * 1000 }, 0)) / \(fmt(percentile(xs, 0.95).map { $0 * 1000 }, 0)) / \(fmt(xs.max().map { $0 * 1000 }, 0))"
}

func scoreApp(root: URL, caseDir: URL, log: URL, loops: Int) throws -> String {
    let info = try JSONDecoder().decode(AudioCaseInfo.self, from: Data(contentsOf: caseDir.appendingPathComponent("case.json")))
    let baseTL = try JSONDecoder().decode(Timeline.self, from: Data(contentsOf: caseDir.appendingPathComponent("truth.json")))
    let scriptOnce = try String(contentsOf: caseDir.appendingPathComponent("script.txt"), encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let script = PromptScript(scriptOnce)
    let events = try readAppLog(log)

    guard let audioStart = events.first(where: { $0.e == "audio.start" }) else {
        return "No audio.start in \(log.path): the app never started file-fed audio (see error events).\n"
    }
    let period = audioStart.double("seconds") ?? baseTL.end
    let tl = looped(baseTL, period: period, loops: loops)
    let t0 = audioStart.mono
    func t(_ mono: UInt64) -> Double { (Double(mono) - Double(t0)) / 1e9 }

    let frames = events.filter { $0.e == "frame" && $0.string("probe") == "overlay" }
    let matches = events.filter { $0.e == "match" }
    let partials = events.filter { $0.e == "asr.partial" }
    let shown = (frames.isEmpty ? matches : frames).map { (t: t($0.mono), chars: $0.int("chars") ?? 0) }

    var metrics: [String: Double] = [:]
    var out = "### \(info.name) [\(info.voice)]\(loops > 1 ? " × \(loops) loops" : "")\n\n"
    out += "Source: \(frames.isEmpty ? "matcher output (no frame probe)" : "frames the overlay showed")\n\n"
    if let lastFrame = frames.last, let lastMatch = matches.last, lastMatch.mono > lastFrame.mono + 30_000_000_000 {
        out += "⚠️ Overlay frames stopped \(Int(t(lastFrame.mono))) s in while recognition went on to \(Int(t(lastMatch.mono))) s "
            + "(display asleep or overlay gone): scores after that point are not meaningful.\n\n"
    }

    // Tracking quality of what was on screen.
    let result = score(script: script, tl: tl, partials: [], track: shown)
    metrics["lostPer10Min"] = Double(result.lostEvents) / max(result.seconds, 1) * 600
    metrics["finalErrorWords"] = Double(result.finalError)
    out += tableHeader + reportRow(dimension: info.dimension, name: info.name, gating: info.gating, runs: [result]).row + "\n"

    // Soak: does the last loop track like the first? Each loop is scored on its own,
    // shifted back to time 0 and char offset 0.
    if loops > 1 {
        var rows = ""
        for k in 0..<loops {
            let start = Double(k) * period
            // Ends just before the loop boundary, where the app jumps back to the top.
            let loopTrack = shown.filter { $0.t >= start && $0.t < start + period - 1 }
                .map { (t: $0.t - start, chars: $0.chars) }
            let r = score(script: PromptScript(scriptOnce), tl: baseTL, partials: [], track: loopTrack)
            rows += reportRow(dimension: "soak", name: "loop \(k + 1) of \(loops)", gating: info.gating, runs: [r]).row
        }
        out += "Every loop (loop 1 starts fresh; each later loop starts with a jump to the top):\n\n" + tableHeader + rows + "\n"
    }

    // Per-word latency, split by stage, for fresh forward progress outside recovery windows.
    let upper = script.words.map(\.characterRange.upperBound)
    var stats = StageStats()
    var best = -1
    var mi = 0, fi = 0
    for tok in tl.tokens {
        guard let index = tok.index, index > best else { continue }
        best = index
        if tl.resumes.contains(where: { tok.end >= $0 && tok.end < $0 + recoveryGrace }) { continue }
        let target = upper[index]
        while mi < matches.count && t(matches[mi].mono) < tok.start { mi += 1 }
        guard let match = matches[mi...].first(where: { ($0.int("chars") ?? 0) >= target }),
              t(match.mono) <= tok.end + 10 else { continue }
        let matchEnd = match.mono
        let matchStart = matchEnd - UInt64(match.int("ns") ?? 0)
        stats.matcher.append(Double(match.int("ns") ?? 0) / 1e9)
        if let partial = partials.last(where: { $0.mono <= matchStart }) {
            stats.asr.append(max(0, t(partial.mono) - tok.end))
            stats.hop.append(Double(matchStart - partial.mono) / 1e9)
        }
        while fi < frames.count && frames[fi].mono < matchEnd { fi += 1 }
        if let frame = frames[fi...].first(where: { ($0.int("chars") ?? 0) >= target }) {
            stats.render.append(Double(frame.mono - matchEnd) / 1e9)
            stats.total.append(max(0, t(frame.mono) - tok.end))
        } else if frames.isEmpty {
            stats.total.append(max(0, t(matchEnd) - tok.end))
        }
    }
    out += """
    | Stage (word end → …) | p50 / p95 / max (ms) | n |
    |---|---|---|
    | ASR: word end → partial delivered | \(ms(stats.asr)) | \(stats.asr.count) |
    | Main-queue hop: partial → matcher start | \(ms(stats.hop)) | \(stats.hop.count) |
    | Matcher | \(ms(stats.matcher)) | \(stats.matcher.count) |
    | Render: matcher done → frame shows it | \(ms(stats.render)) | \(stats.render.count) |
    | **End to end: word end → on screen** | \(ms(stats.total)) | \(stats.total.count) |

    Word end times are interpolated inside synthesized phrases, so the ASR and end-to-end rows
    carry roughly ±100 ms of ground-truth error; the hop, matcher and render rows don't.
    \(recordStages(stats, into: &metrics))All matcher calls: \(ms(matches.map { Double($0.int("ns") ?? 0) / 1e9 })) over \(matches.count) partials.


    """

    // Resources over the run (soak): memory slope after warm-up, CPU, sessions.
    let samples = events.filter { $0.e == "sample" }
    if let first = samples.first, let last = samples.last, last.mono > first.mono {
        // Memory rises and falls with every recognition window, so a fitted line
        // over a short session reports noise as growth. Compare the median footprint
        // of the first and last quarter after warm-up (10 min) instead.
        let warm = samples.filter { t($0.mono) >= 600 }
        let quarter = max(1, warm.count / 4)
        func medianMB(_ xs: ArraySlice<AppEvent>) -> Double {
            let v = xs.map { Double($0.int("physFootprint") ?? 0) / 1_048_576 }.sorted()
            return v.isEmpty ? 0 : v[v.count / 2]
        }
        let early = warm.prefix(quarter), late = warm.suffix(quarter)
        let hours = warm.count >= 4 ? (t(late[late.startIndex + late.count / 2].mono) - t(early[early.startIndex + early.count / 2].mono)) / 3600 : 0
        let slope = hours > 0 ? (medianMB(late) - medianMB(early)) / hours : 0
        let cpu = { (s: AppEvent) in Double((s.int("cpuUserNs") ?? 0) + (s.int("cpuSystemNs") ?? 0)) / 1e9 }
        let seconds = Double(last.mono - first.mono) / 1e9
        let sessions = Dictionary(grouping: events.filter { $0.e == "asr.session" }, by: { $0.string("reason") ?? "?" })
            .map { "\($0.key) \($0.value.count)" }.sorted().joined(separator: ", ")
        let peak = samples.compactMap { $0.int("physFootprint") }.max() ?? 0
        if warm.count >= 4 { metrics["memSlopeMBPerHour"] = slope }
        metrics["peakMemoryMB"] = Double(peak) / 1_048_576
        metrics["cpuPercent"] = (cpu(last) - cpu(first)) / seconds * 100
        out += """
        | Resource | Value |
        |---|---|
        | Duration | \(fmt(seconds / 60)) min |
        | Memory start → end (peak) | \(fmt(Double(first.int("physFootprint") ?? 0) / 1_048_576)) → \(fmt(Double(last.int("physFootprint") ?? 0) / 1_048_576)) MB (\(fmt(Double(peak) / 1_048_576)) MB) |
        | Memory growth after 10 min (median of last vs first quarter) | \(warm.count >= 4 ? "\(fmt(slope)) MB/h" : "– (run shorter than 10 min: growth is warm-up)") |
        | CPU average | \(fmt((cpu(last) - cpu(first)) / seconds * 100)) % |
        | Recognition sessions | \(sessions.isEmpty ? "–" : sessions) |


        """
    }
    if let error = events.first(where: { $0.e == "error" }) {
        out += "⚠️ App reported: \(error.string("message") ?? "?")\n\n"
    }
    // One machine-readable line for ../desktop/run.go (regression tracking).
    let json = String(data: try JSONSerialization.data(withJSONObject: metrics, options: [.sortedKeys]), encoding: .utf8)!
    return out + "METRICS \(json)\n"
}
