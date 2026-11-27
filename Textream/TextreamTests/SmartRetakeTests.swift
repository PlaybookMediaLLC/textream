//
//  SmartRetakeTests.swift
//  TextreamTests
//
//  Unit tests for Phase 1: sentence-boundary indexing, manual sentence rewind,
//  and opt-in smart near-sentence retake recovery in PromptMatcher.
//

import XCTest
@testable import Textream

final class SmartRetakeTests: XCTestCase {

    func testSentenceStartOffsetsHandlePunctuationAnnotationsAndParagraphs() {
        let raw = """
        [hook — look at camera]
        First sentence starts here! Second sentence asks a question?

        Third paragraph has no period at the end

        Fourth sentence finishes cleanly.
        """
        let script = PromptScript(raw)

        XCTAssertEqual(script.sentenceStartOffsets.count, 4)

        let firstStart = script.sentenceStartOffsets[0]
        let secondStart = script.sentenceStartOffsets[1]
        let thirdStart = script.sentenceStartOffsets[2]
        let fourthStart = script.sentenceStartOffsets[3]

        XCTAssertTrue(script.text.dropFirst(firstStart).hasPrefix("First"))
        XCTAssertTrue(script.text.dropFirst(secondStart).hasPrefix("Second"))
        XCTAssertTrue(script.text.dropFirst(thirdStart).hasPrefix("Third"))
        XCTAssertTrue(script.text.dropFirst(fourthStart).hasPrefix("Fourth"))

        // Mid-way through second sentence -> rewinds to start of second sentence
        XCTAssertEqual(
            script.previousSentenceStartOffset(before: secondStart + 14),
            secondStart
        )
        // Right at start of second sentence -> rewinds to start of first sentence
        XCTAssertEqual(
            script.previousSentenceStartOffset(before: secondStart + 2),
            firstStart
        )
        // Next sentence lookup
        XCTAssertEqual(script.nextSentenceStartOffset(after: firstStart), secondStart)
        XCTAssertEqual(script.nextSentenceStartOffset(after: fourthStart), script.characterCount)
    }

    func testSentenceStartOffsetsSupportCJKPunctuation() {
        let script = PromptScript("今天我们录制视频。第二句话立刻开始！第三句结束？")
        XCTAssertEqual(script.sentenceStartOffsets.count, 3)
        XCTAssertEqual(script.sentenceStartOffsets[0], 0)
        XCTAssertGreaterThan(script.sentenceStartOffsets[1], script.sentenceStartOffsets[0])
        XCTAssertGreaterThan(script.sentenceStartOffsets[2], script.sentenceStartOffsets[1])
    }

    func testManualRewindSentenceStepsBackCleanly() {
        let text = "Alpha studio lighting sets the mood cleanly. Beta microphone positioning keeps audio crisp. Gamma camera framing locks eye contact."
        let script = PromptScript(text)
        var matcher = PromptMatcher(source: script, smartRetakeEnabled: true)

        // Advance deep into sentence 2
        let sentenceTwoStart = script.sentenceStartOffsets[1]
        _ = matcher.jump(to: sentenceTwoStart + 24)
        XCTAssertGreaterThan(matcher.recognizedCharacterCount, sentenceTwoStart)

        // First rewind goes to start of sentence 2
        let afterFirstRewind = matcher.rewindSentence()
        XCTAssertEqual(afterFirstRewind, sentenceTwoStart)

        // Second rewind (already at start of sentence 2) steps back to sentence 1
        let afterSecondRewind = matcher.rewindSentence()
        XCTAssertEqual(afterSecondRewind, script.sentenceStartOffsets[0])
    }

    func testSmartRetakeDetectsSpokenRestartOfCurrentSentence() {
        let text = """
        Welcome creators to the Dante studio breakdown today.
        Calibrating acoustic panels eliminates room echo before recording your voiceover.
        Exporting clean timelines saves hours during post production.
        """
        let script = PromptScript(text)
        var matcher = PromptMatcher(source: script, smartRetakeEnabled: true)

        // Read forward through sentence 1 and most of sentence 2
        let forwardEvent = matcher.matchWithEvent(
            transcript: "Welcome creators to the Dante studio breakdown today calibrating acoustic panels eliminates room echo before"
        )
        if case .advanced = forwardEvent {
            // expected
        } else if case .jumped = forwardEvent {
            // also acceptable depending on step distance
        } else {
            XCTFail("Expected forward progress, got \(forwardEvent)")
        }
        let peakOffset = matcher.recognizedCharacterCount
        XCTAssertGreaterThan(peakOffset, script.sentenceStartOffsets[1] + 25)

        // Creator stumbles and restarts sentence 2 from the beginning ("calibrating acoustic panels")
        var retakeObserved = false
        let partial1 = matcher.matchWithEvent(transcript: "calibrating acoustic panels")
        if partial1.isRetake { retakeObserved = true }
        let partial2 = matcher.matchWithEvent(transcript: "calibrating acoustic panels eliminates")
        if partial2.isRetake { retakeObserved = true }

        XCTAssertTrue(retakeObserved, "Smart retake should detect restarting the current sentence")
        XCTAssertLessThan(matcher.recognizedCharacterCount, peakOffset)
        XCTAssertGreaterThanOrEqual(matcher.recognizedCharacterCount, script.sentenceStartOffsets[1])
    }

    func testDefaultMatcherPreservesLegacyRetakeThresholdWhenOptOut() {
        let script = PromptScript("One two three four five six seven eight nine ten.")
        let matcher = PromptMatcher(source: script)
        XCTAssertFalse(matcher.smartRetakeEnabled)
    }
}
