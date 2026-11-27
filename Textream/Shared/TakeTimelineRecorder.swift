//
//  TakeTimelineRecorder.swift
//  Dante for Creators
//
//  Records monotonic word-level timestamps and timeline markers (retakes,
//  page breaks, stage cues, manual markers) during a teleprompter take for
//  broadcast-ready caption (.srt/.vtt) and NLE marker (.fcpxml/.edl/.csv) export.
//

import Foundation

enum TakeMarkerKind: String, Codable, Equatable, Sendable {
    case goodTakeStart
    case retake
    case pageBreak
    case stageCue
    case manual

    var displayLabel: String {
        switch self {
        case .goodTakeStart: return "Good Take"
        case .retake:        return "Retake"
        case .pageBreak:     return "Page Break"
        case .stageCue:      return "Stage Cue"
        case .manual:        return "Marker"
        }
    }
}

struct TakeMarker: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let kind: TakeMarkerKind
    let timestampSeconds: Double
    let label: String
    let wordIndex: Int

    init(
        id: UUID = UUID(),
        kind: TakeMarkerKind,
        timestampSeconds: Double,
        label: String,
        wordIndex: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.timestampSeconds = max(0, timestampSeconds)
        self.label = label
        self.wordIndex = max(0, wordIndex)
    }
}

struct WordTimingSample: Codable, Equatable, Sendable {
    let wordIndex: Int
    let text: String
    let startSeconds: Double
    let endSeconds: Double
    /// Incremented whenever the speaker rewinds/retakes so clean-pass export can keep the latest take per word.
    let passIndex: Int
}

struct TakeTranscriptRecord: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let scriptTitle: String
    let createdAt: Date
    let durationSeconds: Double
    let targetWPM: Int
    let wordTimings: [WordTimingSample]
    let markers: [TakeMarker]

    /// Returns word timings ordered chronologically, keeping only the latest (clean) pass
    /// for each word index when `cleanPassOnly` is true.
    func resolvedWordTimings(cleanPassOnly: Bool = true) -> [WordTimingSample] {
        guard cleanPassOnly else {
            return wordTimings.sorted { $0.startSeconds < $1.startSeconds }
        }
        var latestByWord: [Int: WordTimingSample] = [:]
        for sample in wordTimings {
            if let existing = latestByWord[sample.wordIndex] {
                if sample.passIndex >= existing.passIndex && sample.startSeconds >= existing.startSeconds {
                    latestByWord[sample.wordIndex] = sample
                }
            } else {
                latestByWord[sample.wordIndex] = sample
            }
        }
        return latestByWord.values.sorted {
            if $0.wordIndex != $1.wordIndex {
                return $0.wordIndex < $1.wordIndex
            }
            return $0.startSeconds < $1.startSeconds
        }
    }
}

struct TakeTimelineRecorder: Sendable {
    private var script: PromptScript
    private var spokenWords: [PromptWord]
    private var startedAt: TimeInterval?
    private var lastEventAt: TimeInterval?
    private var lastSpokenWordCursor: Int = 0
    private var currentPassIndex: Int = 0
    private var recordedTimings: [WordTimingSample] = []
    private var recordedMarkers: [TakeMarker] = []

    init(script: PromptScript) {
        self.script = script
        self.spokenWords = script.words.filter { !$0.isAnnotation }
    }

    var hasRecordedContent: Bool {
        !recordedTimings.isEmpty || !recordedMarkers.isEmpty
    }

    mutating func reset(script: PromptScript? = nil) {
        if let script {
            self.script = script
            self.spokenWords = script.words.filter { !$0.isAnnotation }
        }
        startedAt = nil
        lastEventAt = nil
        lastSpokenWordCursor = 0
        currentPassIndex = 0
        recordedTimings.removeAll(keepingCapacity: true)
        recordedMarkers.removeAll(keepingCapacity: true)
    }

    /// Anchors take start (for example, right when camera recording begins).
    mutating func markStart(at timestamp: TimeInterval, label: String = "Take Start") {
        if startedAt == nil {
            startedAt = timestamp
            lastEventAt = timestamp
            recordedMarkers.append(
                TakeMarker(kind: .goodTakeStart, timestampSeconds: 0, label: label, wordIndex: 0)
            )
        }
    }

    mutating func recordProgress(
        characterOffset: Int,
        at timestamp: TimeInterval,
        isRetake: Bool = false
    ) {
        let clampedOffset = max(0, characterOffset)
        let newCursor = spokenWordCount(upTo: clampedOffset)

        if startedAt == nil {
            guard newCursor > 0 else { return }
            startedAt = timestamp
            lastEventAt = timestamp
            recordedMarkers.append(
                TakeMarker(kind: .goodTakeStart, timestampSeconds: 0, label: "Take Start", wordIndex: 0)
            )
        }

        let startOrigin = startedAt ?? timestamp
        let elapsed = max(0, timestamp - startOrigin)
        let prevElapsed = max(0, (lastEventAt ?? timestamp) - startOrigin)

        if isRetake || newCursor < lastSpokenWordCursor {
            currentPassIndex += 1
            let previewWord = newCursor < spokenWords.count ? spokenWords[newCursor].text : ""
            let label = previewWord.isEmpty ? "Retake" : "Retake from \"\(previewWord)\""
            recordedMarkers.append(
                TakeMarker(
                    kind: .retake,
                    timestampSeconds: elapsed,
                    label: label,
                    wordIndex: newCursor
                )
            )
            lastSpokenWordCursor = newCursor
            lastEventAt = timestamp
            return
        }

        guard newCursor > lastSpokenWordCursor else { return }
        let addedCount = newCursor - lastSpokenWordCursor
        let spanStart = max(0, min(prevElapsed, elapsed))
        let rawSpan = max(0.18 * Double(addedCount), elapsed - spanStart)
        // Cap long silence gaps before a burst so the caption cue starts right when speaking resumed.
        let effectiveSpan = min(rawSpan, max(0.35 * Double(addedCount), 4.0))
        let burstStart = max(0, elapsed - effectiveSpan)
        let stepDuration = effectiveSpan / Double(addedCount)

        for offsetIndex in 0..<addedCount {
            let wordIdx = lastSpokenWordCursor + offsetIndex
            guard wordIdx < spokenWords.count else { break }
            let word = spokenWords[wordIdx]
            let wStart = burstStart + Double(offsetIndex) * stepDuration
            let wEnd = max(wStart + 0.08, wStart + stepDuration)
            recordedTimings.append(
                WordTimingSample(
                    wordIndex: wordIdx,
                    text: word.text,
                    startSeconds: wStart,
                    endSeconds: wEnd,
                    passIndex: currentPassIndex
                )
            )
        }

        lastSpokenWordCursor = newCursor
        lastEventAt = timestamp
    }

    mutating func recordPageBreak(pageNumber: Int, at timestamp: TimeInterval) {
        let elapsed = startedAt.map { max(0, timestamp - $0) } ?? 0
        recordedMarkers.append(
            TakeMarker(
                kind: .pageBreak,
                timestampSeconds: elapsed,
                label: "Page \(pageNumber)",
                wordIndex: lastSpokenWordCursor
            )
        )
    }

    mutating func addManualMarker(label: String = "Studio Marker", at timestamp: TimeInterval) {
        let elapsed = startedAt.map { max(0, timestamp - $0) } ?? 0
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        recordedMarkers.append(
            TakeMarker(
                kind: .manual,
                timestampSeconds: elapsed,
                label: cleanLabel.isEmpty ? "Studio Marker" : cleanLabel,
                wordIndex: lastSpokenWordCursor
            )
        )
    }

    func makeRecord(
        at timestamp: TimeInterval,
        scriptTitle: String,
        targetWPM: Int
    ) -> TakeTranscriptRecord {
        let elapsed = startedAt.map { max(0, timestamp - $0) } ?? 0
        let maxEnd = recordedTimings.map(\.endSeconds).max() ?? 0
        let duration = max(elapsed, maxEnd)
        return TakeTranscriptRecord(
            id: UUID(),
            scriptTitle: scriptTitle.isEmpty ? "Untitled Take" : scriptTitle,
            createdAt: Date(),
            durationSeconds: duration,
            targetWPM: ScriptMetrics.clampedWPM(targetWPM),
            wordTimings: recordedTimings,
            markers: recordedMarkers
        )
    }

    private func spokenWordCount(upTo characterOffset: Int) -> Int {
        guard !spokenWords.isEmpty, characterOffset > 0 else { return 0 }
        var low = 0
        var high = spokenWords.count
        while low < high {
            let mid = (low + high) / 2
            if spokenWords[mid].characterRange.upperBound <= characterOffset {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }
}
