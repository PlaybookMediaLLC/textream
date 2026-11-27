//
//  PacingCoachEngine.swift
//  Dante for Creators
//
//  Real-time speaking pace & take analytics engine shared across macOS and iOS.
//  Tracks rolling WPM (15s sliding window), target schedule delta (+/- seconds),
//  pause hotspots, and post-take summary metrics while ignoring backward retakes.
//

import Foundation

enum PaceStatus: String, Equatable, Sendable {
    case slow
    case onPace
    case fast

    var label: String {
        switch self {
        case .slow: return "Slow"
        case .onPace: return "On pace"
        case .fast: return "Fast"
        }
    }
}

struct PaceSnapshot: Equatable, Sendable {
    let rollingWPM: Int
    let averageWPM: Int
    let targetWPM: Int
    let spokenWordsCompleted: Int
    let totalSpokenWords: Int
    let elapsedSeconds: TimeInterval
    /// Negative means ahead of target schedule (speaking faster); positive means behind.
    let deltaSeconds: Int
    let projectedTotalSeconds: Int
    let status: PaceStatus

    var wpmLabel: String {
        rollingWPM > 0 ? "\(rollingWPM) WPM" : "-- WPM"
    }

    var deltaLabel: String {
        if rollingWPM == 0 {
            return "Ready"
        }
        if abs(deltaSeconds) <= 1 {
            return "On pace"
        }
        return deltaSeconds < 0 ? "\(deltaSeconds)s" : "+\(deltaSeconds)s"
    }

    var compactReadout: String {
        guard rollingWPM > 0 else { return "Target \(targetWPM) WPM" }
        return "\(rollingWPM) WPM · \(deltaLabel)"
    }
}

struct TakeSummary: Equatable, Sendable {
    let durationSeconds: TimeInterval
    let averageWPM: Int
    let targetWPM: Int
    let spokenWordsCompleted: Int
    let totalSpokenWords: Int
    let completionRatio: Double
    let retakeCount: Int
    let longestPauseSeconds: TimeInterval

    var formattedDuration: String {
        ScriptMetrics.formattedDuration(seconds: Int(durationSeconds.rounded()))
    }

    var formattedSummaryText: String {
        let pct = Int((completionRatio * 100).rounded())
        let pauseStr = longestPauseSeconds >= 1.5
            ? String(format: " · Longest pause %.1fs", longestPauseSeconds)
            : ""
        let retakeStr = retakeCount == 1 ? "1 retake" : "\(retakeCount) retakes"
        return "Take Summary: \(formattedDuration) · \(averageWPM) WPM (target \(targetWPM)) · \(spokenWordsCompleted)/\(totalSpokenWords) words (\(pct)%) · \(retakeStr)\(pauseStr)"
    }
}

struct PacingCoachEngine: Sendable {
    private struct WordStep {
        let timestamp: TimeInterval
        let wordsAdded: Int
        let activeInterval: TimeInterval
    }

    private let spokenWordEndOffsets: [Int]
    let targetWPM: Int
    private let windowSeconds: TimeInterval
    private let maxActiveGapSeconds: TimeInterval

    private var startedAt: TimeInterval?
    private var lastEventAt: TimeInterval?
    private var lastCharacterOffset: Int = 0
    private var maxSpokenWordsReached: Int = 0
    private var totalForwardWordsSpoken: Int = 0
    private var totalActiveSpeakingSeconds: TimeInterval = 0
    private var longestPauseSeconds: TimeInterval = 0
    private(set) var retakeCount: Int = 0
    private var recentSteps: [WordStep] = []

    init(
        script: PromptScript,
        targetWPM: Int = ScriptMetrics.defaultWPM,
        windowSeconds: TimeInterval = 15.0,
        maxActiveGapSeconds: TimeInterval = 4.0
    ) {
        self.spokenWordEndOffsets = script.words
            .filter { !$0.isAnnotation }
            .map { $0.characterRange.upperBound }
        self.targetWPM = ScriptMetrics.clampedWPM(targetWPM)
        self.windowSeconds = max(5.0, windowSeconds)
        self.maxActiveGapSeconds = max(1.5, maxActiveGapSeconds)
    }

    var totalSpokenWords: Int {
        spokenWordEndOffsets.count
    }

    mutating func reset(script: PromptScript? = nil, targetWPM: Int? = nil) {
        let nextScript = script
        let nextTarget = targetWPM ?? self.targetWPM
        if let nextScript {
            self = PacingCoachEngine(
                script: nextScript,
                targetWPM: nextTarget,
                windowSeconds: windowSeconds,
                maxActiveGapSeconds: maxActiveGapSeconds
            )
        } else {
            startedAt = nil
            lastEventAt = nil
            lastCharacterOffset = 0
            maxSpokenWordsReached = 0
            totalForwardWordsSpoken = 0
            totalActiveSpeakingSeconds = 0
            longestPauseSeconds = 0
            retakeCount = 0
            recentSteps.removeAll(keepingCapacity: true)
        }
    }

    @discardableResult
    mutating func recordProgress(
        characterOffset: Int,
        at timestamp: TimeInterval,
        isRetake: Bool = false
    ) -> PaceSnapshot {
        let clampedOffset = max(0, characterOffset)
        let currentWordCount = spokenWordsCompleted(at: clampedOffset)

        if startedAt == nil {
            if currentWordCount > 0 {
                startedAt = timestamp
                lastEventAt = timestamp
                lastCharacterOffset = clampedOffset
                maxSpokenWordsReached = currentWordCount
                totalForwardWordsSpoken = currentWordCount
                // Seed initial interval assuming target pace for the first batch so rolling WPM starts smoothly.
                let seedInterval = max(0.5, Double(currentWordCount) / (Double(targetWPM) / 60.0))
                totalActiveSpeakingSeconds = seedInterval
                recentSteps.append(WordStep(timestamp: timestamp, wordsAdded: currentWordCount, activeInterval: seedInterval))
            }
            return snapshot(at: timestamp)
        }

        let previousWords = spokenWordsCompleted(at: lastCharacterOffset)
        let rawDeltaTime = max(0, timestamp - (lastEventAt ?? timestamp))

        if isRetake || clampedOffset < lastCharacterOffset {
            retakeCount += 1
            lastCharacterOffset = clampedOffset
            lastEventAt = timestamp
            pruneWindow(at: timestamp)
            return snapshot(at: timestamp)
        }

        if rawDeltaTime > longestPauseSeconds {
            longestPauseSeconds = rawDeltaTime
        }

        let wordsDelta = currentWordCount - previousWords
        if wordsDelta > 0 {
            let activeDt = rawDeltaTime > maxActiveGapSeconds
                ? min(maxActiveGapSeconds, Double(wordsDelta) / (Double(targetWPM) / 60.0))
                : max(0.05, rawDeltaTime)
            totalForwardWordsSpoken += wordsDelta
            totalActiveSpeakingSeconds += activeDt
            maxSpokenWordsReached = max(maxSpokenWordsReached, currentWordCount)
            recentSteps.append(WordStep(timestamp: timestamp, wordsAdded: wordsDelta, activeInterval: activeDt))
            lastCharacterOffset = clampedOffset
            lastEventAt = timestamp
        } else if clampedOffset > lastCharacterOffset {
            lastCharacterOffset = clampedOffset
        }

        pruneWindow(at: timestamp)
        return snapshot(at: timestamp)
    }

    mutating func recordRetake(at timestamp: TimeInterval) {
        retakeCount += 1
        lastEventAt = timestamp
        pruneWindow(at: timestamp)
    }

    func snapshot(at timestamp: TimeInterval) -> PaceSnapshot {
        let elapsed = startedAt.map { max(0, timestamp - $0) } ?? 0
        let completed = spokenWordsCompleted(at: lastCharacterOffset)

        let windowCutoff = timestamp - windowSeconds
        var windowWords = 0
        var windowSecondsActive: TimeInterval = 0
        for step in recentSteps where step.timestamp >= windowCutoff {
            windowWords += step.wordsAdded
            windowSecondsActive += step.activeInterval
        }

        let averageWPM: Int
        if totalForwardWordsSpoken > 0, totalActiveSpeakingSeconds > 0.25 {
            averageWPM = Self.clampedDisplayWPM(Double(totalForwardWordsSpoken) / (totalActiveSpeakingSeconds / 60.0))
        } else {
            averageWPM = 0
        }

        let rollingWPM: Int
        if windowWords > 0, windowSecondsActive > 0.25 {
            rollingWPM = Self.clampedDisplayWPM(Double(windowWords) / (windowSecondsActive / 60.0))
        } else {
            rollingWPM = averageWPM
        }

        let expectedElapsedForCompleted = Double(completed) / (Double(targetWPM) / 60.0)
        // Positive delta = behind target schedule (took longer than target); negative = ahead of schedule.
        let deltaSeconds = completed > 0 ? Int((elapsed - expectedElapsedForCompleted).rounded()) : 0

        let effectivePace = rollingWPM > 0 ? Double(rollingWPM) : Double(targetWPM)
        let remainingWords = max(0, totalSpokenWords - completed)
        let projectedRemaining = Double(remainingWords) / (effectivePace / 60.0)
        let projectedTotal = Int((elapsed + projectedRemaining).rounded())

        let status: PaceStatus
        if rollingWPM == 0 {
            status = .onPace
        } else {
            let ratio = Double(rollingWPM) / Double(targetWPM)
            if ratio < 0.88 {
                status = .slow
            } else if ratio > 1.12 {
                status = .fast
            } else {
                status = .onPace
            }
        }

        return PaceSnapshot(
            rollingWPM: rollingWPM,
            averageWPM: averageWPM,
            targetWPM: targetWPM,
            spokenWordsCompleted: completed,
            totalSpokenWords: totalSpokenWords,
            elapsedSeconds: elapsed,
            deltaSeconds: deltaSeconds,
            projectedTotalSeconds: projectedTotal,
            status: status
        )
    }

    func makeSummary(at timestamp: TimeInterval) -> TakeSummary {
        let snap = snapshot(at: timestamp)
        let ratio = totalSpokenWords > 0
            ? min(1.0, Double(maxSpokenWordsReached) / Double(totalSpokenWords))
            : 0
        return TakeSummary(
            durationSeconds: snap.elapsedSeconds,
            averageWPM: snap.averageWPM,
            targetWPM: targetWPM,
            spokenWordsCompleted: maxSpokenWordsReached,
            totalSpokenWords: totalSpokenWords,
            completionRatio: ratio,
            retakeCount: retakeCount,
            longestPauseSeconds: longestPauseSeconds
        )
    }

    private func spokenWordsCompleted(at characterOffset: Int) -> Int {
        guard !spokenWordEndOffsets.isEmpty, characterOffset > 0 else { return 0 }
        // Binary search for number of spoken words whose upperBound <= characterOffset
        var low = 0
        var high = spokenWordEndOffsets.count
        while low < high {
            let mid = (low + high) / 2
            if spokenWordEndOffsets[mid] <= characterOffset {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }

    private mutating func pruneWindow(at timestamp: TimeInterval) {
        let cutoff = timestamp - windowSeconds
        if let firstKeep = recentSteps.firstIndex(where: { $0.timestamp >= cutoff }) {
            if firstKeep > 0 {
                recentSteps.removeFirst(firstKeep)
            }
        } else {
            recentSteps.removeAll(keepingCapacity: true)
        }
    }

    private static func clampedDisplayWPM(_ raw: Double) -> Int {
        guard raw.isFinite, raw > 0 else { return 0 }
        return min(360, max(40, Int(raw.rounded())))
    }
}
