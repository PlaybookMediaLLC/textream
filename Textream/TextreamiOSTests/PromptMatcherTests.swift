import Foundation
import Testing
@testable import TextreamiOS

/// Regression tests for the failure modes found by benchmarks/speech-tracking.
struct PromptMatcherTests {
    private let script = PromptScript("""
    Welcome back to the channel. Today we are going to talk about how small teams ship great products. \
    Most teams do not fail because they lack talent. They fail because they try to do everything at once. \
    The second step is to make work visible. Put every project on a single board that the whole team can see. \
    Finally, celebrate progress. Shipping a small feature is still shipping.
    """)

    /// Feeds `words` one at a time as a growing partial transcript, like a recognizer does.
    @discardableResult
    private func speak(_ words: String, into matcher: inout PromptMatcher, after prefix: String = "") -> Int {
        var transcript = prefix
        var offset = matcher.recognizedCharacterCount
        for word in words.split(separator: " ") {
            transcript += (transcript.isEmpty ? "" : " ") + word
            offset = matcher.match(transcript: transcript)
        }
        return offset
    }

    private func offset(after phrase: String) -> Int {
        let range = script.text.range(of: phrase)!
        return script.text.distance(from: script.text.startIndex, to: range.upperBound) + 1
    }

    @Test
    func misheardWordDoesNotDerailTheRestOfTheSession() {
        var matcher = PromptMatcher(source: script)
        let spoken = "welcome the to the channel today we are going to talk about how small teams ship grate products "
            + "most teams do not fail because they lack talent"
        #expect(speak(spoken, into: &matcher) >= offset(after: "lack talent."))
    }

    @Test
    func skippedParagraphIsFoundAgain() {
        var matcher = PromptMatcher(source: script)
        let first = "welcome back to the channel today we are going to talk"
        speak(first, into: &matcher)
        let reached = speak("the second step is to make work visible put every project", into: &matcher, after: first)
        #expect(reached >= offset(after: "Put every project"))
    }

    @Test
    func rereadingAnEarlierLineMovesBack() {
        var matcher = PromptMatcher(source: script)
        let read = "welcome back to the channel today we are going to talk about how small teams ship great products "
            + "most teams do not fail because they lack talent"
        let ahead = speak(read, into: &matcher)
        let back = speak("today we are going to talk about how small", into: &matcher, after: read)
        #expect(back < ahead)
        #expect(back >= offset(after: "about how"))
        #expect(back < offset(after: "great products."))
    }

    @Test
    func adLibDoesNotAdvanceTheHighlight() {
        var matcher = PromptMatcher(source: script)
        let read = "welcome back to the channel"
        let before = speak(read, into: &matcher)
        let after = speak("and honestly i have been doing this for a while now so let me tell you", into: &matcher, after: read)
        #expect(after == before)
    }

    @Test
    func contractionsMatchTheExpandedScript() {
        var matcher = PromptMatcher(source: PromptScript("We do not stop. It is what we are."))
        #expect(speak("we don't stop it's what we're", into: &matcher) == matcher.source.characterCount)
    }

    @Test
    func scaledNumbersMatchSpokenForm() {
        #expect(PromptMatcher.canonicalTokens("saved $4.5M and 30k") == ["saved", "45", "million", "and", "30", "thousand"])
        #expect(PromptMatcher.canonicalTokens("4.5 million") == ["45", "million"])
        #expect(PromptMatcher.canonicalTokens("p99 v2") == ["p99", "v2"])
    }

    @Test
    func recognizerRestartKeepsContext() {
        var matcher = PromptMatcher(source: script)
        speak("welcome back to the channel today we are going", into: &matcher)
        matcher.restartFromCurrentProgress()
        // A fresh session's first words are ambiguous alone ("to"); the carried tail anchors them.
        #expect(speak("to talk about how small teams", into: &matcher) >= offset(after: "small teams"))
    }

    @Test
    func transcriptResetMidSessionDoesNotJumpBackToOldContext() {
        // On-device recognition can drop its transcript after a pause without a new
        // session. Old carried context must not drag the highlight back.
        var matcher = PromptMatcher(source: script)
        let opening = "welcome back to the channel today we are going to talk about how small teams"
        speak(opening, into: &matcher)
        matcher.restartFromCurrentProgress()
        let second = "ship great products most teams do not fail because they lack talent they fail because"
        let reached = speak(second, into: &matcher)
        #expect(reached >= offset(after: "They fail because"))
        let afterReset = speak("they try to do", into: &matcher)   // fresh transcript, same session
        #expect(afterReset >= reached)
    }

    @Test
    func repeatedSentenceDoesNotTeleportToALaterCopy() {
        let refrain = PromptScript("""
        What changed this week? We shipped the new login page and fixed billing. \
        Our customers noticed and support tickets fell by half. \
        Then we asked again. What changed this week? Nothing, and that was the problem.
        """)
        var matcher = PromptMatcher(source: refrain)
        let read = speak("what changed this week we shipped the new login", into: &matcher)
        let reread = speak("what changed this week", into: &matcher, after: "what changed this week we shipped the new login")
        let laterCopy = refrain.text.range(of: "Then we asked").map {
            refrain.text.distance(from: refrain.text.startIndex, to: $0.lowerBound)
        }!
        #expect(read < laterCopy)
        #expect(reread < laterCopy)
    }
}
