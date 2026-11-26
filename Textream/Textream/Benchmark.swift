//
//  Benchmark.swift
//  Textream
//
//  Benchmark-only instrumentation (benchmarks/PLAN.md, Phase 0). The full
//  implementation compiles only into the BENCHMARK build made by
//  benchmarks/desktop/run.go; shipping builds keep just the empty shims below,
//  whose arguments are autoclosures and are never evaluated.
//

import AppKit

/// Appends one event to the benchmark log (no-op outside BENCHMARK builds).
@inline(__always)
func benchLog(_ event: String, _ fields: @autoclosure () -> [String: Any] = [:]) {
    #if BENCHMARK
    Bench.log(event, fields())
    #endif
}

/// Marks a recognition-session boundary (task restart, new window): the point
/// where the app's matcher re-anchors, so offline scoring can do the same.
@inline(__always)
func benchNewSession(_ reason: StaticString) {
    #if BENCHMARK
    Bench.newSession(String(describing: reason))
    #endif
}

/// Attaches a vsync probe to a window (first-frame time, frame pacing, and when
/// the highlight actually reaches the screen). Only when -bench-probe is set.
@inline(__always)
func benchAttachProbe(to window: NSWindow?, label: String, chars: @escaping () -> Int) {
    #if BENCHMARK
    Bench.attachProbe(to: window, label: label, chars: chars)
    #endif
}

#if BENCHMARK
import AVFoundation
import Darwin
import OSLog
import QuartzCore

enum Bench {
    // MARK: Arguments (-bench-* launch arguments land in UserDefaults' argument domain)

    private static let defaults = UserDefaults.standard
    static let logPath = defaults.string(forKey: "bench-log")
    static let scriptSpec = defaults.string(forKey: "bench-script")
    static let readAfter = defaults.double(forKey: "bench-read-after")
    static let autoplayWPM = defaults.double(forKey: "bench-autoplay")
    static let quitAfter = defaults.double(forKey: "bench-quit-after")
    /// Quit this many seconds after file-fed audio starts (model load time excluded).
    static let quitAfterAudioStart = defaults.double(forKey: "bench-quit-after-audio-start")
    static let quitAfterLaunch = defaults.bool(forKey: "bench-launch")
    static let probeEnabled = defaults.bool(forKey: "bench-probe") || quitAfterLaunch
    static let sampleInterval = defaults.object(forKey: "bench-sample-interval") != nil
        ? max(0.5, defaults.double(forKey: "bench-sample-interval")) : 5
    static let hideMainWindow = defaults.bool(forKey: "bench-hide-main-window")
    static let stopListeningAfterShow = defaults.bool(forKey: "bench-stop-listening")
    static let microOutput = defaults.string(forKey: "bench-micro")
    static let untilHighlight = defaults.bool(forKey: "bench-until-highlight")
    /// Local models are read from here instead of the user's models folder.
    static let modelsDirectory = defaults.string(forKey: "bench-models-dir")

    // MARK: Log

    private static let queue = DispatchQueue(label: "dev.fka.textream.bench-log")
    private static let handle: FileHandle? = {
        guard let logPath else { return nil }
        FileManager.default.createFile(atPath: logPath, contents: nil)
        return FileHandle(forWritingAtPath: logPath)
    }()
    static let signposter = OSSignposter(subsystem: "dev.fka.textream", category: "Perf")
    private(set) static var session = 0

    static func monoNanos() -> UInt64 { clock_gettime_nsec_np(CLOCK_UPTIME_RAW) }

    static func log(_ event: String, _ fields: [String: Any] = [:]) {
        guard let handle else { return }
        var record = fields
        record["e"] = event
        record["mono"] = monoNanos()
        record["wall"] = Date().timeIntervalSince1970
        signposter.emitEvent("bench", "\(event, privacy: .public)")
        queue.async {
            guard var data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]) else { return }
            data.append(0x0A)
            handle.write(data)
        }
    }

    static func newSession(_ reason: String) {
        session += 1
        log("asr.session", ["session": session, "reason": reason])
    }

    static func flush() { queue.sync {} }

    // MARK: Lifecycle

    /// Called first thing in applicationDidFinishLaunching.
    static func didFinishLaunchingBegan() {
        log("process.start", ["startWall": processStartWall(), "pid": Int(getpid())])
        log("launch.didFinishLaunching")
    }

    /// Called at the end of applicationDidFinishLaunching.
    static func didFinishLaunchingEnded() {
        log("launch.didFinishLaunchingEnd")
        if hideMainWindow { TextreamService.shared.hideMainWindow() }
        startSampler()
        if quitAfter > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + quitAfter) { quit(reason: "quit-after") }
        }
        if let microOutput {
            DispatchQueue.main.async {
                runMicro(to: microOutput)
                quit(reason: "micro")
            }
            return
        }
        if let text = loadScript() {
            DispatchQueue.main.asyncAfter(deadline: .now() + readAfter) {
                log("read.begin", ["words": text.split(whereSeparator: \.isWhitespace).count])
                TextreamService.shared.readText(text)
            }
        }
    }

    static func quit(reason: String) {
        log("sample", resourceSample())
        for probe in probes { log("probe.summary", probe.summary()) }
        log("quit", ["reason": reason])
        flush()
        NSApp.terminate(nil)
    }

    static func processStartWall() -> Double {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return 0 }
        let start = info.kp_proc.p_un.__p_starttime
        return Double(start.tv_sec) + Double(start.tv_usec) / 1_000_000
    }

    // MARK: Script

    /// -bench-script <path> or words:<N>.
    static func loadScript() -> String? {
        guard let scriptSpec else { return nil }
        if scriptSpec.hasPrefix("words:"), let count = Int(scriptSpec.dropFirst(6)) {
            return generatedScript(words: count)
        }
        guard let text = try? String(contentsOfFile: scriptSpec, encoding: .utf8) else {
            log("error", ["message": "cannot read script \(scriptSpec)"])
            return nil
        }
        return text
    }

    /// Deterministic prose-like text: varied word lengths, sentences, paragraphs.
    static func generatedScript(words count: Int) -> String {
        let vocabulary = """
        the a we our team built this product because people needed a simpler way to read their \
        notes while looking at the camera every speaker knows that moment when attention drifts \
        and the next line disappears so we designed tracking that follows your voice word by word \
        presentation interview podcast tutorial keynote rehearsal understanding remarkable \
        straightforward communication international responsibility
        """.split(separator: " ").map(String.init)
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        func next() -> Int {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int(state >> 33)
        }
        var out: [String] = []
        out.reserveCapacity(count)
        var sentence = 0
        for i in 0..<count {
            var word = vocabulary[next() % vocabulary.count]
            if sentence == 0 { word = word.prefix(1).uppercased() + word.dropFirst() }
            sentence += 1
            if sentence >= 8 + next() % 10 || i == count - 1 {
                word += "."
                sentence = 0
                if next() % 6 == 0 { word += "\n\n" }
            }
            out.append(word)
        }
        return out.joined(separator: " ")
    }

    // MARK: Autoplay (rendering load without ASR)

    private static var autoplayTimer: Timer?

    /// Advances the highlight one word at a time at -bench-autoplay words per minute.
    static func startAutoplay(_ recognizer: SpeechRecognizer, collapsedText: String) {
        autoplayTimer?.invalidate()
        var ends: [Int] = []
        var offset = 0
        for word in collapsedText.split(separator: " ", omittingEmptySubsequences: false) {
            offset += word.count
            ends.append(offset)
            offset += 1
        }
        var index = 0
        log("autoplay.start", ["wpm": autoplayWPM, "words": ends.count])
        autoplayTimer = Timer.scheduledTimer(withTimeInterval: 60 / autoplayWPM, repeats: true) { [weak recognizer] timer in
            guard let recognizer, index < ends.count else {
                timer.invalidate()
                log("autoplay.end")
                return
            }
            recognizer.recognizedCharCount = ends[index]
            log("autoplay", ["chars": ends[index]])
            index += 1
        }
        RunLoop.main.add(autoplayTimer!, forMode: .common)
    }

    // MARK: Resource sampling (no sudo: task_info on ourselves)

    private static var samplerTimer: Timer?

    static func startSampler() {
        log("sample", resourceSample())
        samplerTimer = Timer.scheduledTimer(withTimeInterval: sampleInterval, repeats: true) { _ in
            log("sample", resourceSample())
        }
        samplerTimer?.tolerance = sampleInterval * 0.1
    }

    static func resourceSample() -> [String: Any] {
        var sample: [String: Any] = [:]

        var power = task_power_info_v2()
        var powerCount = mach_msg_type_number_t(
            MemoryLayout<task_power_info_v2>.size / MemoryLayout<natural_t>.size
        )
        let powerResult = withUnsafeMutablePointer(to: &power) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(powerCount)) {
                task_info(mach_task_self_, task_flavor_t(TASK_POWER_INFO_V2), $0, &powerCount)
            }
        }
        if powerResult == KERN_SUCCESS {
            // total_user/total_system are Mach absolute-time units.
            var timebase = mach_timebase_info_data_t()
            mach_timebase_info(&timebase)
            let toNs = { (units: UInt64) in units * UInt64(timebase.numer) / UInt64(timebase.denom) }
            sample["cpuUserNs"] = toNs(power.cpu_energy.total_user)
            sample["cpuSystemNs"] = toNs(power.cpu_energy.total_system)
            sample["interruptWakeups"] = power.cpu_energy.task_interrupt_wakeups
            sample["idleWakeups"] = power.cpu_energy.task_platform_idle_wakeups
            #if arch(arm64)
            sample["energyNj"] = power.task_energy
            #endif
        }

        var vm = task_vm_info_data_t()
        var vmCount = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        )
        let vmResult = withUnsafeMutablePointer(to: &vm) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &vmCount)
            }
        }
        if vmResult == KERN_SUCCESS {
            sample["physFootprint"] = vm.phys_footprint
        }
        sample["thermal"] = ProcessInfo.processInfo.thermalState.rawValue
        return sample
    }

    // MARK: Frame probes

    private(set) static var probes: [BenchFrameProbe] = []

    static func attachProbe(to window: NSWindow?, label: String, chars: @escaping () -> Int) {
        guard probeEnabled, let content = window?.contentView else { return }
        let probe = BenchFrameProbe(label: label, chars: chars)
        probe.frame = NSRect(x: 0, y: 0, width: 1, height: 1)
        content.addSubview(probe)
        probes.append(probe)
    }

    // MARK: Micro benchmarks (#4 layout cost, #7 broadcast encode)

    static func runMicro(to path: String) {
        var results: [[String: Any]] = []
        let font = NSFont.systemFont(ofSize: 24)
        for count in [1_000, 10_000, 50_000] {
            let text = generatedScript(words: count)
            let words = splitTextIntoWords(text)
            let total = words.joined(separator: " ").count
            let breaks = paragraphBreakWordIndices(in: text)

            let cold = measure(iterations: 1) {
                WordFlowLayout.benchPerRedrawCost(
                    words: words, highlightedCharCount: 0, font: font,
                    paragraphBreaks: breaks, containerWidth: CGFloat(500 + count % 7)
                )
            }
            results.append(["name": "layout.cold", "words": count, "ns": cold])
            for fraction in [0.1, 0.5, 0.9] {
                let highlighted = Int(Double(total) * fraction)
                let ns = measure(iterations: 30) {
                    WordFlowLayout.benchPerRedrawCost(
                        words: words, highlightedCharCount: highlighted, font: font,
                        paragraphBreaks: breaks, containerWidth: 600
                    )
                }
                results.append(["name": "layout.redraw", "words": count, "at": fraction, "ns": ns])
            }

            let (encodeNs, bytes) = DirectorServer.benchEncodeCost(words: words, totalCharCount: total)
            results.append(["name": "director.encode", "words": count, "ns": encodeNs, "bytes": bytes])
            let (browserNs, browserBytes) = BrowserServer.benchEncodeCost(words: words, totalCharCount: total)
            results.append(["name": "browser.encode", "words": count, "ns": browserNs, "bytes": browserBytes])
        }
        let data = (try? JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])) ?? Data()
        FileManager.default.createFile(atPath: path, contents: data)
        log("micro.done", ["results": results.count])
    }

    /// Median wall time in ns of `iterations` runs (one warm-up run when iterations > 1).
    static func measure(iterations: Int, _ body: () -> Void) -> UInt64 {
        if iterations > 1 { body() }
        var samples: [UInt64] = []
        for _ in 0..<iterations {
            let start = monoNanos()
            body()
            samples.append(monoNanos() - start)
        }
        return samples.sorted()[samples.count / 2]
    }
}

/// A 1×1 view that ticks on every display refresh of its window. It logs the
/// first frame, a "frame" event whenever the highlighted char count shown has
/// changed since the previous refresh, and keeps frame-pacing statistics.
/// A refresh callback that arrives late means the main thread was busy, which
/// is what a user sees as a hitch.
final class BenchFrameProbe: NSView {
    let label: String
    private let chars: () -> Int
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var lastChars = Int.min
    private var frames = 0
    private var hitches = 0
    private var hitchSeconds = 0.0
    private var maxInterval = 0.0
    private var expectedSum = 0.0
    private var firstFrameLogged = false
    private var quitScheduled = false
    private var attachedAt = Bench.monoNanos()
    private var statsStartedAt: UInt64?

    init(label: String, chars: @escaping () -> Int) {
        self.label = label
        self.chars = chars
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else {
            link?.invalidate()
            link = nil
            return
        }
        guard link == nil else { return }
        let link = displayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
        attachedAt = Bench.monoNanos()
    }

    @objc private func tick(_ link: CADisplayLink) {
        if !firstFrameLogged {
            firstFrameLogged = true
            Bench.log("\(label).firstFrame")
        }
        let expected = link.targetTimestamp - link.timestamp
        // Pacing stats skip the first second: window setup is launch cost
        // (measured separately), not a steady-state hitch.
        let settled = Bench.monoNanos() - attachedAt > 1_000_000_000
        if settled, statsStartedAt == nil { statsStartedAt = Bench.monoNanos() }
        if settled, lastTimestamp > 0, expected > 0 {
            let interval = link.timestamp - lastTimestamp
            frames += 1
            expectedSum += expected
            maxInterval = max(maxInterval, interval)
            if interval > expected * 1.5 {
                hitches += 1
                hitchSeconds += interval - expected
            }
        }
        lastTimestamp = link.timestamp
        let current = chars()
        if current != lastChars {
            lastChars = current
            Bench.log("frame", ["probe": label, "chars": current])
        }
        if Bench.quitAfterLaunch, !quitScheduled, launchTargetReached(current) {
            quitScheduled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { Bench.quit(reason: "launch") }
        }
    }

    /// -bench-launch ends the run at the main window's first frame, or with a
    /// script at the overlay's first frame (-bench-until-highlight: at the
    /// first frame showing a highlighted word).
    private func launchTargetReached(_ current: Int) -> Bool {
        if Bench.scriptSpec == nil { return label == "main" }
        guard label == "overlay" else { return false }
        return !Bench.untilHighlight || current > 0
    }

    func summary() -> [String: Any] {
        let seconds = statsStartedAt.map { Double(Bench.monoNanos() - $0) / 1e9 } ?? 0
        return [
            "probe": label,
            "seconds": seconds,
            "frames": frames,
            "hitches": hitches,
            "hitchMsPerS": seconds > 0 ? hitchSeconds * 1000 / seconds : 0,
            "maxFrameMs": maxInterval * 1000,
            "refreshHz": frames > 0 && expectedSum > 0 ? Double(frames) / expectedSum : 0,
        ]
    }
}

/// Plays -bench-audio into the recognition pipeline in place of the microphone.
/// Playback position follows wall time since the first play, so a full engine
/// restart resumes where the "speaker" is rather than starting over.
final class BenchAudioSource {
    static let shared: BenchAudioSource? = {
        guard let path = UserDefaults.standard.string(forKey: "bench-audio") else { return nil }
        do {
            return try BenchAudioSource(url: URL(fileURLWithPath: path))
        } catch {
            Bench.log("error", ["message": "cannot open bench audio: \(error.localizedDescription)"])
            return nil
        }
    }()

    private let file: AVAudioFile
    private let loop = UserDefaults.standard.bool(forKey: "bench-loop-audio")
    private let player = AVAudioPlayerNode()
    private var startedAt: UInt64?
    private var loops = 0
    /// Bumped on every play(): stopping the player fires the old segment's
    /// completion, which must not schedule another loop.
    private var generation = 0

    init(url: URL) throws {
        file = try AVAudioFile(forReading: url)
    }

    /// Attaches the player to a fresh engine and returns it as the tap source.
    func attach(to engine: AVAudioEngine) -> AVAudioNode {
        if let previous = player.engine { previous.detach(player) }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)
        engine.mainMixerNode.outputVolume = 0
        return player
    }

    /// Call after engine.start().
    func play() {
        let total = file.length
        let rate = file.processingFormat.sampleRate
        var startFrame: AVAudioFramePosition = 0
        if let startedAt {
            let elapsed = AVAudioFramePosition(Double(Bench.monoNanos() - startedAt) / 1e9 * rate)
            startFrame = loop ? elapsed % total : elapsed
            guard startFrame < total else { return }
            // Within half a second of the end: start the next loop now rather than
            // replaying a sliver of the old one.
            if loop, total - startFrame < AVAudioFramePosition(rate / 2) { startFrame = 0 }
            Bench.log("audio.resume", ["frame": startFrame])
        } else {
            startedAt = Bench.monoNanos()
            Bench.log("audio.start", ["seconds": Double(total) / rate, "loop": loop])
            if Bench.quitAfterAudioStart > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Bench.quitAfterAudioStart) {
                    Bench.quit(reason: "quit-after-audio-start")
                }
            }
        }
        generation += 1
        let current = generation
        player.stop()
        player.scheduleSegment(
            file, startingFrame: startFrame, frameCount: AVAudioFrameCount(total - startFrame), at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in self?.scheduleNextLoop(current) }
        player.play()
    }

    private func scheduleNextLoop(_ scheduledGeneration: Int) {
        guard loop, scheduledGeneration == generation, player.engine != nil else { return }
        loops += 1
        Bench.log("audio.loop", ["index": loops])
        player.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            self?.scheduleNextLoop(scheduledGeneration)
        }
        // The "speaker" starts the script over: jump to the top, as tapping the first
        // word does (a far jump restarts recognition; playback resumes in place).
        DispatchQueue.main.async {
            TextreamService.shared.overlayController.speechRecognizer.jumpTo(charOffset: 0)
        }
    }
}
#endif
