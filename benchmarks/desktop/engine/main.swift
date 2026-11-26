// Local speech engine tool (benchmarks/PLAN.md #1 step 2 and #3). Compiled by ../run.go
// together with the app's own Textream/Textream/LocalSpeechEngine.swift and the vendored
// TranscribeCpp bindings, so it measures exactly what the app runs.
//
//   engine transcribe --audio a.wav --model m.gguf --out partials.jsonl [--prompt "w1, w2"]
//       Real-time-paced feed through LocalSpeechEngine (as the app's mic tap does);
//       writes Layer B partials {t, session, text}. A rolled-over window starts a new
//       session, which is where the app re-anchors its matcher.
//   engine perf --audio a.wav --model m.gguf --out metrics.json [--backend auto|cpu|metal]
//              [--sweep-runs 10] [--thermal-minutes 0]
//       Load time (fresh process, then reload), first-partial latency and partial
//       intervals in paced mode, decode time vs window length (rolling-window models)
//       or chunk real-time factor (streaming models), peak memory, and an optional
//       sustained run that tracks slowdown and thermal state.

import Foundation
import TranscribeCpp

/// The app's benchmark hook; a no-op here (the tool keeps its own timings).
func benchLog(_ event: String, _ fields: @autoclosure () -> [String: Any] = [:]) {}

// MARK: - Arguments and helpers

var options: [String: String] = [:]
let argv = CommandLine.arguments
let command = argv.count > 1 ? argv[1] : ""
var argIndex = 2
while argIndex + 1 < argv.count {
    options[String(argv[argIndex].drop(while: { $0 == "-" }))] = argv[argIndex + 1]
    argIndex += 2
}

func option(_ key: String) -> String {
    guard let value = options[key] else {
        FileHandle.standardError.write("missing --\(key)\n".data(using: .utf8)!)
        exit(2)
    }
    return value
}

func now() -> Double { Double(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / 1e9 }

func readWav16k(_ path: String) throws -> [Float] {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    // render-audio writes 16 kHz mono float32 WAV; find the "data" chunk.
    var offset = 12
    while offset + 8 <= data.count {
        let id = String(decoding: data[offset..<offset + 4], as: UTF8.self)
        let size = Int(data[offset + 4..<offset + 8].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) })
        if id == "data" {
            return data[offset + 8..<min(data.count, offset + 8 + size)].withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        }
        offset += 8 + size + (size & 1)
    }
    throw NSError(domain: "wav", code: 1, userInfo: [NSLocalizedDescriptionKey: "no data chunk in \(path)"])
}

func physFootprint() -> UInt64 {
    var vm = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    let result = withUnsafeMutablePointer(to: &vm) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    return result == KERN_SUCCESS ? vm.phys_footprint : 0
}

/// Samples phys_footprint at 10 Hz on its own thread.
final class PeakMemory: @unchecked Sendable {
    private let lock = NSLock()
    private var peakBytes: UInt64 = 0
    private var running = true
    init() {
        Thread.detachNewThread { [self] in
            while true {
                lock.lock()
                let keep = running
                peakBytes = max(peakBytes, physFootprint())
                lock.unlock()
                if !keep { return }
                usleep(100_000)
            }
        }
    }
    var peak: UInt64 { lock.lock(); defer { lock.unlock() }; return max(peakBytes, physFootprint()) }
    func stop() { lock.lock(); running = false; lock.unlock() }
}

func percentile(_ xs: [Double], _ p: Double) -> Double? {
    guard !xs.isEmpty else { return nil }
    let s = xs.sorted()
    return s[min(s.count - 1, Int(Double(s.count - 1) * p))]
}

func writeJSON(_ object: Any, to path: String) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: URL(fileURLWithPath: path))
}

/// Runs the main run loop (LocalSpeechEngine delivers callbacks on the main queue).
func spin(until deadline: Double) {
    while now() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(min(0.02, max(0, deadline - now())))) }
}

func loadEngine(_ path: String) throws -> (info: LocalSpeechEngineInfo, seconds: Double) {
    var result: Result<LocalSpeechEngineInfo, Error>?
    let start = now()
    LocalSpeechEngine.shared.loadModel(at: path) { result = $0 }
    while result == nil { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
    return (try result!.get(), now() - start)
}

// MARK: - Paced session through the app's engine

struct PacedRun {
    var partials: [(t: Double, session: Int, text: String)] = []
    var firstPartial: Double?
    var error: String?
}

/// Feeds `audio` in 100 ms chunks at real-time pace, like the app's mic tap.
func pacedSession(_ audio: [Float], prompt: String?, language: String?) -> PacedRun {
    var run = PacedRun()
    var session = 0
    let engine = LocalSpeechEngine.shared
    let start = now()
    var finished = false
    let id = engine.start(
        language: language, initialPrompt: prompt, wordTimestamps: false,
        onText: { text, _, _, isNewWindow, _ in
            if isNewWindow { session += 1 }
            let t = now() - start
            if run.firstPartial == nil, !text.trimmingCharacters(in: .whitespaces).isEmpty { run.firstPartial = t }
            run.partials.append((t, session, text))
        },
        onError: { message, _ in run.error = message; finished = true },
        onFinished: { _ in finished = true }
    )
    let chunk = 1_600
    var i = 0
    while i < audio.count, run.error == nil {
        let n = min(chunk, audio.count - i)
        engine.feed(Array(audio[i..<i + n]), sessionID: id)
        i += n
        spin(until: start + Double(i) / 16_000)
    }
    engine.stop(sessionID: id)
    let deadline = now() + 30
    while !finished, now() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
    return run
}

func languageHint(_ info: LocalSpeechEngineInfo) -> String? {
    // Mirrors SpeechRecognizer.localLanguageHint for an English script.
    if let english = info.languages.first(where: { $0.lowercased().hasPrefix("en") }) { return english }
    return info.supportsLanguageDetection ? nil : info.languages.first
}

// MARK: - Commands

func transcribeCommand() throws {
    let audio = try readWav16k(option("audio"))
    let (info, _) = try loadEngine(option("model"))
    let run = pacedSession(audio, prompt: options["prompt"], language: languageHint(info))
    if let error = run.error { throw NSError(domain: "engine", code: 1, userInfo: [NSLocalizedDescriptionKey: error]) }
    var lines: [String] = []
    var lastSession = -1
    for p in run.partials {
        if p.session != lastSession {   // session marker, like the recorder's
            lines.append(String(data: try JSONSerialization.data(withJSONObject: ["t": p.t, "session": p.session, "text": ""], options: [.sortedKeys]), encoding: .utf8)!)
            lastSession = p.session
        }
        lines.append(String(data: try JSONSerialization.data(withJSONObject: ["t": p.t, "session": p.session, "text": p.text], options: [.sortedKeys]), encoding: .utf8)!)
    }
    try (lines.joined(separator: "\n") + "\n").write(toFile: option("out"), atomically: true, encoding: .utf8)
    LocalSpeechEngine.shared.unloadModelSynchronously()
}

func perfCommand() throws {
    let audio = try readWav16k(option("audio"))
    let modelPath = option("model")
    let memory = PeakMemory()
    var report: [String: Any] = [
        "model": URL(fileURLWithPath: modelPath).lastPathComponent,
        "modelBytes": (try? FileManager.default.attributesOfItem(atPath: modelPath)[.size] as? NSNumber)?.intValue ?? 0,
        "audioSeconds": Double(audio.count) / 16_000,
    ]

    // 1. Load: first load in this fresh process, then a reload after unloading.
    let baseline = physFootprint()
    let (info, firstLoad) = try loadEngine(modelPath)
    LocalSpeechEngine.shared.unloadModelSynchronously()
    let (_, reload) = try loadEngine(modelPath)
    report["arch"] = info.arch
    report["variant"] = info.variant
    report["engineBackend"] = info.backend
    report["streaming"] = info.supportsStreaming
    report["loadSeconds"] = firstLoad
    report["reloadSeconds"] = reload
    report["loadedMemoryMB"] = Double(physFootprint() - min(baseline, physFootprint())) / 1_048_576

    // 2. Paced session through the app's engine: first partial and partial cadence.
    let paced = pacedSession(audio, prompt: nil, language: languageHint(info))
    let times = paced.partials.map(\.t)
    let intervals = zip(times.dropFirst(), times).map { $0 - $1 }
    report["firstPartialSeconds"] = paced.firstPartial ?? -1
    report["partials"] = paced.partials.count
    report["partialIntervalP50"] = percentile(intervals, 0.5) ?? -1
    report["partialIntervalP95"] = percentile(intervals, 0.95) ?? -1
    report["partialIntervalMax"] = intervals.max() ?? -1
    report["pacedError"] = paced.error ?? ""
    LocalSpeechEngine.shared.unloadModelSynchronously()

    // 3. Direct decode cost, on the requested backend.
    let backend: Backend = ["cpu": .cpu, "metal": .metal][options["backend"] ?? "auto"] ?? .auto
    let model = try Model(path: modelPath, options: ModelOptions(backend: backend))
    let session = try model.session()
    report["backend"] = model.backend
    let runs = Int(options["sweep-runs"] ?? "10") ?? 10
    let language = languageHint(info)
    var sweep: [[String: Any]] = []
    if !info.supportsStreaming {
        // Decode time vs window length: the app re-decodes the whole window
        // (up to 26 s) every 1.5 s, so the 26 s row is the worst case.
        for seconds in [1, 2, 4, 8, 13, 20, 26] {
            let window = Array((0..<seconds * 16_000).map { audio[$0 % audio.count] })
            var samples: [Double] = []
            _ = try session.run(window, options: RunOptions(task: .transcribe, language: language))   // warm-up
            for _ in 0..<runs {
                let start = now()
                _ = try session.run(window, options: RunOptions(task: .transcribe, language: language))
                samples.append(now() - start)
            }
            sweep.append(["windowSeconds": seconds, "decodeP50": percentile(samples, 0.5)!, "decodeP95": percentile(samples, 0.95)!])
        }
        report["decodeAt26sP50"] = sweep.last?["decodeP50"] ?? -1
    } else {
        // Streaming: processing time per 100 ms chunk, i.e. real-time factor.
        let stream = try session.stream(RunOptions(task: .transcribe, language: language), StreamOptions())
        // Bounded at 2 minutes of wall time: a stream that falls behind gets slower per
        // chunk as it grows, and how far it got is itself the result.
        var samples: [Double] = []
        var i = 0
        let loopStart = now()
        while i + 1_600 <= audio.count, now() - loopStart < 120 {
            let start = now()
            _ = try stream.feed(Array(audio[i..<i + 1_600]))
            samples.append((now() - start) / 0.1)
            i += 1_600
        }
        let firstHalf = Array(samples.prefix(samples.count / 2)), secondHalf = Array(samples.suffix(samples.count / 2))
        sweep.append(["chunkSeconds": 0.1, "rtfP50": percentile(samples, 0.5) ?? -1, "rtfP95": percentile(samples, 0.95) ?? -1,
                      "rtfP50FirstHalf": percentile(firstHalf, 0.5) ?? -1, "rtfP50SecondHalf": percentile(secondHalf, 0.5) ?? -1,
                      "audioSecondsFed": Double(i) / 16_000])
        report["streamRtfP95"] = percentile(samples, 0.95) ?? -1
        report["streamAudioSecondsIn2Min"] = Double(i) / 16_000
    }
    report["sweep"] = sweep

    // 4. Sustained load (thermals): the app's worst-case cadence for N minutes.
    let minutes = Double(options["thermal-minutes"] ?? "0") ?? 0
    if minutes > 0 {
        var buckets: [[String: Any]] = []
        let end = now() + minutes * 60
        let window = Array((0..<26 * 16_000).map { audio[$0 % audio.count] })
        let stream = info.supportsStreaming ? try session.stream(RunOptions(task: .transcribe, language: language), StreamOptions()) : nil
        var bucketStart = now(), bucket: [Double] = [], offset = 0
        while now() < end {
            let start = now()
            if let stream {
                _ = try stream.feed(Array((0..<1_600).map { audio[(offset + $0) % audio.count] }))
                offset += 1_600
                bucket.append((now() - start) / 0.1)
                let wait = start + 0.1 - now()
                if wait > 0 { usleep(UInt32(wait * 1e6)) }
            } else {
                _ = try session.run(window, options: RunOptions(task: .transcribe, language: language))
                bucket.append(now() - start)
                let wait = start + 1.5 - now()
                if wait > 0 { usleep(UInt32(wait * 1e6)) }
            }
            if now() - bucketStart >= 30 {
                buckets.append(["minute": (bucketStart - (end - minutes * 60)) / 60, "p50": percentile(bucket, 0.5)!,
                                "thermal": ProcessInfo.processInfo.thermalState.rawValue])
                bucket = []
                bucketStart = now()
            }
        }
        report["thermal"] = buckets
        let early = buckets.filter { ($0["minute"] as! Double) < 5 }.compactMap { $0["p50"] as? Double }
        let late = buckets.filter { ($0["minute"] as! Double) >= minutes - 5 }.compactMap { $0["p50"] as? Double }
        if let e = percentile(early, 0.5), let l = percentile(late, 0.5), e > 0 { report["thermalRatio"] = l / e }
        report["thermalMetric"] = info.supportsStreaming ? "chunk RTF" : "26 s decode seconds"
    }

    memory.stop()
    report["peakMemoryMB"] = Double(memory.peak) / 1_048_576
    try writeJSON(report, to: option("out"))
}

// Like the app: native diagnostics below error level stay out of the output.
Transcribe.setLogHandler { level, message in
    if level == .error { FileHandle.standardError.write("transcribe.cpp: \(message)\n".data(using: .utf8)!) }
}

do {
    switch command {
    case "transcribe": try transcribeCommand()
    case "perf": try perfCommand()
    default:
        FileHandle.standardError.write("usage: engine transcribe|perf --audio <wav> --model <gguf> --out <path>\n".data(using: .utf8)!)
        exit(2)
    }
} catch {
    FileHandle.standardError.write("engine: \(error.localizedDescription)\n".data(using: .utf8)!)
    exit(1)
}
