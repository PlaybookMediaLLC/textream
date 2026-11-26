//
//  RedrawAndBroadcastTests.swift
//  TextreamTests
//
//  Correctness of the per-redraw next-word search, and XCTest performance
//  baselines for the per-redraw and per-broadcast-tick work
//  (benchmarks/PLAN.md #4 and #7; the desktop runner's `micro` measures the
//  same paths inside a BENCHMARK build).
//

import AppKit
import XCTest
@testable import Textream

final class RedrawAndBroadcastTests: XCTestCase {
    /// The old linear scan, kept as the reference the binary search must match.
    private func referenceNextWordIndex(_ items: [WordItem], highlighted: Int) -> Int {
        for item in items {
            if item.isAnnotation { continue }
            let litCount = max(0, min(item.word.count, highlighted - item.charOffset))
            let letterCount = max(1, item.word.filter { $0.isLetter || $0.isNumber }.count)
            if litCount < letterCount { return item.id }
        }
        return -1
    }

    private func layout(_ words: [String], highlighted: Int = 0) -> WordFlowLayout {
        WordFlowLayout(
            words: words, highlightedCharCount: highlighted, font: .systemFont(ofSize: 24),
            containerWidth: 600
        )
    }

    func testNextWordIndexMatchesLinearScan() {
        var generator = SystemRandomNumberGenerator()
        let vocabulary = ["the", "a", "Hello,", "world.", "[smile]", "🙂", "don't", "2026", "—", "presentation", "x"]
        for _ in 0..<40 {
            let words = (0..<Int.random(in: 1...60, using: &generator)).map { _ in vocabulary.randomElement(using: &generator)! }
            let items = layout(words).buildItems()
            let total = words.joined(separator: " ").count
            for highlighted in -1...(total + 2) {
                XCTAssertEqual(
                    layout(words, highlighted: highlighted).nextWordIndex(items: items),
                    referenceNextWordIndex(items, highlighted: highlighted),
                    "words \(words), highlighted \(highlighted)"
                )
            }
        }
    }

    func testBroadcastStatesDoNotRepeatTheScript() throws {
        let director = DirectorState(
            highlightedCharCount: 5, totalCharCount: 10, isActive: true, isDone: false, isListening: true,
            fontColor: "#fff", cueColor: "#fff", lastSpokenText: "", audioLevels: []
        )
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(director), as: UTF8.self).contains("\"words\""))

        let browser = BrowserState(
            words: nil, highlightedCharCount: 5, totalCharCount: 10, audioLevels: [], isListening: true, isDone: false,
            fontColor: "#fff", cueColor: "#fff", hasNextPage: false, isActive: true, highlightWords: true, lastSpokenText: ""
        )
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(browser), as: UTF8.self).contains("\"words\""))
    }

    // MARK: - Performance (50k words, highlight near the end: the worst case before the fix)

    private lazy var longScript: [String] = (0..<50_000).map { ["prompter", "reads", "the", "next", "line."][$0 % 5] }

    func testPerRedrawNextWordSearchPerformance() {
        let words = longScript
        let items = layout(words).buildItems()
        let near90 = Int(Double(words.joined(separator: " ").count) * 0.9)
        let view = layout(words, highlighted: near90)
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            for _ in 0..<100 { _ = view.nextWordIndex(items: items) }
        }
    }

    func testBroadcastTickEncodePerformance() {
        let browser = BrowserState(
            words: nil, highlightedCharCount: 1_000, totalCharCount: 300_000, audioLevels: Array(repeating: 0.5, count: 30),
            isListening: true, isDone: false, fontColor: "#fff", cueColor: "#fff", hasNextPage: false, isActive: true,
            highlightWords: true, lastSpokenText: "the prompter reads the next line"
        )
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            for _ in 0..<100 { _ = try? JSONEncoder().encode(browser) }
        }
    }
}
