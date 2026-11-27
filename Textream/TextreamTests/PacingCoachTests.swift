//
//  PacingCoachTests.swift
//  TextreamTests
//
//  Unit tests for Phase 2: live rolling WPM, target schedule delta,
//  pause exclusion, retake non-inflation, and post-take summary metrics.
//

import XCTest
@testable import Textream

final class PacingCoachTests: XCTestCase {

    func testSteadyPaceMatchesTargetWPMAndReportsOnPace() {
        // 30 spoken words at 150 WPM (2.5 words/sec) -> 12 seconds total
        let words = (1...30).map { "word\($0)" }.joined(separator: " ")
        let script = PromptScript(words)
        var engine = PacingCoachEngine(script: script, targetWPM: 150)

        var lastSnapshot = engine.snapshot(at: 0)
        // Step 5 words every 2.0 seconds -> exactly 150 WPM
        for step in 1...6 {
            let wordIndex = step * 5 - 1
            let offset = script.words[wordIndex].characterRange.upperBound
            lastSnapshot = engine.recordProgress(characterOffset: offset, at: Double(step) * 2.0)
        }

        XCTAssertEqual(lastSnapshot.status, .onPace)
        XCTAssertTrue((135...165).contains(lastSnapshot.rollingWPM), "Unexpected WPM: \(lastSnapshot.rollingWPM)")
        XCTAssertEqual(lastSnapshot.spokenWordsCompleted, 30)
        XCTAssertEqual(lastSnapshot.totalSpokenWords, 30)
        XCTAssertLessThanOrEqual(abs(lastSnapshot.deltaSeconds), 3)
    }

    func testFastAndSlowPaceStatusesAreClassifiedCorrectly() {
        let words = (1...40).map { "token\($0)" }.joined(separator: " ")
        let script = PromptScript(words)

        // Fast speaker: 5 words every 1.0s (~300 WPM vs 150 target)
        var fastEngine = PacingCoachEngine(script: script, targetWPM: 150)
        var fastSnap = fastEngine.snapshot(at: 0)
        for step in 1...6 {
            let offset = script.words[step * 5 - 1].characterRange.upperBound
            fastSnap = fastEngine.recordProgress(characterOffset: offset, at: Double(step) * 1.0)
        }
        XCTAssertEqual(fastSnap.status, .fast)
        XCTAssertGreaterThan(fastSnap.rollingWPM, 180)
        XCTAssertLessThan(fastSnap.deltaSeconds, 0) // ahead of schedule

        // Slow speaker: 5 words every 3.5s (~86 WPM vs 150 target)
        var slowEngine = PacingCoachEngine(script: script, targetWPM: 150)
        var slowSnap = slowEngine.snapshot(at: 0)
        for step in 1...6 {
            let offset = script.words[step * 5 - 1].characterRange.upperBound
            slowSnap = slowEngine.recordProgress(characterOffset: offset, at: Double(step) * 3.5)
        }
        XCTAssertEqual(slowSnap.status, .slow)
        XCTAssertLessThan(slowSnap.rollingWPM, 125)
        XCTAssertGreaterThan(slowSnap.deltaSeconds, 0) // behind schedule
    }

    func testRetakesIncrementCounterAndExcludeSpuriousSpikes() {
        let text = "[intro] One two three four five six seven eight nine ten eleven twelve."
        let script = PromptScript(text)
        var engine = PacingCoachEngine(script: script, targetWPM: 150)

        let spokenWords = script.words.filter { !$0.isAnnotation }
        XCTAssertEqual(engine.totalSpokenWords, 12)

        let offset5 = spokenWords[4].characterRange.upperBound
        let offset10 = spokenWords[9].characterRange.upperBound
        let offset2 = spokenWords[1].characterRange.upperBound

        _ = engine.recordProgress(characterOffset: offset5, at: 2.0)
        _ = engine.recordProgress(characterOffset: offset10, at: 4.0)
        // Rewind / retake back to word 2
        _ = engine.recordProgress(characterOffset: offset2, at: 5.0, isRetake: true)
        // Long pause (8 seconds) then resume
        _ = engine.recordProgress(characterOffset: offset10, at: 13.0)

        let summary = engine.makeSummary(at: 13.0)
        XCTAssertEqual(summary.retakeCount, 1)
        XCTAssertGreaterThanOrEqual(summary.longestPauseSeconds, 8.0)
        XCTAssertTrue(summary.formattedSummaryText.contains("1 retake"))
        XCTAssertTrue(summary.formattedSummaryText.contains("WPM"))
    }
}
