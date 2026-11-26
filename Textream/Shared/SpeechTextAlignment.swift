import Foundation

/// `[bracketed cues]` in a script are shown but never spoken. Shared by the macOS and
/// iOS apps so both treat cues identically.
enum SpeechTextAlignment {
    /// Per-word flag: is this word part of a cue?
    static func annotationFlags(for words: [String]) -> [Bool] {
        var closingAtOrAfter = Array(repeating: false, count: words.count)
        var hasClosing = false
        for index in words.indices.reversed() {
            if words[index].contains("]") {
                hasClosing = true
            }
            closingAtOrAfter[index] = hasClosing
        }

        var flags: [Bool] = []
        var isInsideAnnotation = false
        for (index, word) in words.enumerated() {
            let beginsAnnotation = word.hasPrefix("[") && closingAtOrAfter[index]
            flags.append(isInsideAnnotation || beginsAnnotation)
            if beginsAnnotation {
                isInsideAnnotation = true
            }
            if isInsideAnnotation && word.contains("]") {
                isInsideAnnotation = false
            }
        }
        return flags
    }

    static func annotationRanges(in text: String) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var openingIndex: Int?
        for (index, character) in text.enumerated() {
            if character == "[", openingIndex == nil {
                openingIndex = index
            } else if character == "]", let start = openingIndex {
                // Speech ranges intentionally include `[]`. Editor visuals use
                // their own nonempty regex.
                ranges.append(start..<(index + 1))
                openingIndex = nil
            }
        }
        return ranges
    }

    /// Moves `offset` past any cue it sits in or that starts right after it (ignoring
    /// whitespace), so the highlight never stops on something the reader won't say.
    static func advancePastAnnotations(in text: String, ranges: [Range<Int>], from offset: Int) -> Int {
        let characters = Array(text)
        var current = max(0, min(offset, characters.count))
        var skippedAnnotation = false

        while current < characters.count {
            if let range = ranges.first(where: { $0.contains(current) }) {
                current = range.upperBound
                skippedAnnotation = true
                continue
            }
            var next = current
            while next < characters.count && characters[next].isWhitespace { next += 1 }
            if let range = ranges.first(where: { $0.lowerBound == next }) {
                current = range.upperBound
                skippedAnnotation = true
                continue
            }
            return skippedAnnotation ? next : current
        }
        return current
    }
}
