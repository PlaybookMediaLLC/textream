import Foundation

extension Unicode.Scalar {
    var isPromptCJK: Bool {
        let value = value
        return (value >= 0x4E00 && value <= 0x9FFF)
            || (value >= 0x3400 && value <= 0x4DBF)
            || (value >= 0x20000 && value <= 0x2A6DF)
            || (value >= 0xF900 && value <= 0xFAFF)
            || (value >= 0x3040 && value <= 0x309F)
            || (value >= 0x30A0 && value <= 0x30FF)
    }
}

func splitPromptTextIntoWords(_ text: String) -> [String] {
    let tokens = text.replacingOccurrences(of: "\n", with: " ")
        .split(omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
        .map(String.init)

    var result: [String] = []
    for token in tokens {
        guard token.unicodeScalars.contains(where: \.isPromptCJK) else {
            result.append(token)
            continue
        }

        var buffer = ""
        for character in token {
            if character.unicodeScalars.first?.isPromptCJK == true {
                if !buffer.isEmpty {
                    result.append(buffer)
                    buffer = ""
                }
                result.append(String(character))
            } else {
                buffer.append(character)
            }
        }
        if !buffer.isEmpty {
            result.append(buffer)
        }
    }
    return result
}

enum PromptTextDirection: Equatable {
    case leftToRight
    case rightToLeft

    static func inferred(from text: String) -> PromptTextDirection {
        var insideCue = false
        for scalar in text.unicodeScalars {
            if scalar == "[" {
                insideCue = true
                continue
            }
            if scalar == "]" {
                insideCue = false
                continue
            }
            guard !insideCue, CharacterSet.letters.contains(scalar) else { continue }
            return scalar.isStrongRightToLeft ? .rightToLeft : .leftToRight
        }
        return .leftToRight
    }
}

private extension Unicode.Scalar {
    var isStrongRightToLeft: Bool {
        let value = value
        return (value >= 0x0590 && value <= 0x08FF)
            || (value >= 0xFB1D && value <= 0xFDFF)
            || (value >= 0xFE70 && value <= 0xFEFF)
            || (value >= 0x10800 && value <= 0x10FFF)
            || (value >= 0x1E800 && value <= 0x1EEFF)
    }
}

struct PromptWord: Identifiable, Equatable {
    let id: Int
    let text: String
    let characterRange: Range<Int>
    let isAnnotation: Bool
}

struct PromptScript: Equatable {
    let text: String
    let words: [PromptWord]
    let annotationRanges: [Range<Int>]
    let annotationStyleRanges: [Range<Int>]
    let sentenceStartOffsets: [Int]
    let direction: PromptTextDirection

    init(_ rawText: String) {
        let rawWords = splitPromptTextIntoWords(rawText)
        let collapsed = rawWords.joined(separator: " ")
        let balancedAnnotationRanges = SpeechTextAlignment.annotationRanges(in: collapsed)
        // Split the word ranges at cue boundaries without adding spaces to the displayed text.
        let cueBoundaries = balancedAnnotationRanges.flatMap { [$0.lowerBound, $0.upperBound] }
        var styleRanges = balancedAnnotationRanges
        var boundaryIndex = 0
        var offset = 0
        var builtWords: [PromptWord] = []
        builtWords.reserveCapacity(rawWords.count)

        for word in rawWords {
            let wordEnd = offset + word.count
            var start = word.startIndex
            while offset < wordEnd {
                while boundaryIndex < cueBoundaries.count, cueBoundaries[boundaryIndex] <= offset {
                    boundaryIndex += 1
                }
                let nextBoundary = boundaryIndex < cueBoundaries.count
                    ? cueBoundaries[boundaryIndex] : wordEnd
                let endOffset = min(nextBoundary, wordEnd)
                let end = word.index(start, offsetBy: endOffset - offset)
                let part = String(word[start..<end])
                let isInsideCue = !boundaryIndex.isMultiple(of: 2)
                let hasNoReadableCharacters = !part.contains { $0.isLetter || $0.isNumber }
                let range = offset..<endOffset
                if !isInsideCue, hasNoReadableCharacters {
                    styleRanges.append(range)
                }
                builtWords.append(
                    PromptWord(
                        id: builtWords.count,
                        text: part,
                        characterRange: range,
                        isAnnotation: isInsideCue || hasNoReadableCharacters
                    )
                )
                offset = endOffset
                start = end
            }
            offset = wordEnd + 1
        }

        text = collapsed
        words = builtWords
        annotationRanges = balancedAnnotationRanges
        annotationStyleRanges = styleRanges.sorted { $0.lowerBound < $1.lowerBound }
        sentenceStartOffsets = Self.computeSentenceStartOffsets(
            rawText: rawText,
            words: builtWords
        )
        direction = PromptTextDirection.inferred(from: collapsed)
    }

    var characterCount: Int { text.count }

    func characterOffset(forWordProgress progress: Double) -> Int {
        guard !words.isEmpty else { return 0 }
        let clamped = max(0, min(progress, Double(words.count)))
        let wholeWord = min(Int(clamped), words.count)
        guard wholeWord < words.count else { return characterCount }
        let fraction = clamped - Double(wholeWord)
        let word = words[wholeWord]
        return min(characterCount, word.characterRange.lowerBound + Int(Double(word.text.count) * fraction))
    }

    func wordProgress(forCharacterOffset offset: Int) -> Double {
        let clamped = max(0, min(offset, characterCount))
        for word in words {
            if clamped <= word.characterRange.upperBound {
                let position = max(0, clamped - word.characterRange.lowerBound)
                return Double(word.id) + Double(position) / Double(max(1, word.text.count))
            }
        }
        return Double(words.count)
    }

    func activeWord(atCharacterOffset offset: Int) -> PromptWord? {
        guard let index = words.firstIndex(where: { offset <= $0.characterRange.upperBound }) else {
            return words.last
        }
        if index + 1 < words.count, words[index + 1].characterRange.lowerBound == offset {
            return words[index + 1]
        }
        return words[index]
    }

    /// Start character offset of the sentence containing `characterOffset`.
    func sentenceStartOffset(containing characterOffset: Int) -> Int {
        let clamped = max(0, min(characterOffset, characterCount))
        guard let first = sentenceStartOffsets.first else { return 0 }
        var current = first
        for start in sentenceStartOffsets {
            if start <= clamped {
                current = start
            } else {
                break
            }
        }
        return current
    }

    /// Rewinds to the start of the current sentence if already more than `minProgressIntoSentence`
    /// characters into it; otherwise rewinds to the start of the previous sentence.
    func previousSentenceStartOffset(
        before characterOffset: Int,
        minProgressIntoSentence: Int = 8
    ) -> Int {
        let clamped = max(0, min(characterOffset, characterCount))
        guard !sentenceStartOffsets.isEmpty else { return 0 }

        var currentIndex = 0
        for (idx, start) in sentenceStartOffsets.enumerated() {
            if start <= clamped {
                currentIndex = idx
            } else {
                break
            }
        }

        let currentStart = sentenceStartOffsets[currentIndex]
        if clamped - currentStart >= minProgressIntoSentence {
            return currentStart
        }
        return currentIndex > 0 ? sentenceStartOffsets[currentIndex - 1] : currentStart
    }

    /// Start character offset of the next sentence after `characterOffset`, or `characterCount`.
    func nextSentenceStartOffset(after characterOffset: Int) -> Int {
        let clamped = max(0, min(characterOffset, characterCount))
        return sentenceStartOffsets.first(where: { $0 > clamped }) ?? characterCount
    }

    private static func computeSentenceStartOffsets(
        rawText: String,
        words: [PromptWord]
    ) -> [Int] {
        guard !words.isEmpty else { return [] }

        // Track raw-word indices that begin a new paragraph (separated by a blank line)
        var paragraphStartRawWordIndices = Set<Int>()
        let normalizedRaw = rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let paragraphs = normalizedRaw.components(separatedBy: "\n\n")
        var rawWordCursor = 0
        for paragraph in paragraphs {
            let count = splitPromptTextIntoWords(paragraph).count
            if count > 0 {
                if rawWordCursor > 0 {
                    paragraphStartRawWordIndices.insert(rawWordCursor)
                }
                rawWordCursor += count
            }
        }

        // Map each PromptWord to its enclosing raw-word index (splits happen inside cues without spaces)
        var rawIndexForWord: [Int] = []
        rawIndexForWord.reserveCapacity(words.count)
        var currentRawIndex = 0
        for (idx, word) in words.enumerated() {
            if idx > 0, word.characterRange.lowerBound > words[idx - 1].characterRange.upperBound {
                currentRawIndex += 1
            }
            rawIndexForWord.append(currentRawIndex)
        }

        var starts: [Int] = []
        var expectNewSentence = true
        for (idx, word) in words.enumerated() {
            if paragraphStartRawWordIndices.contains(rawIndexForWord[idx]) {
                expectNewSentence = true
            }
            if word.isAnnotation {
                if Self.endsSentence(word.text) {
                    expectNewSentence = true
                }
                continue
            }
            if expectNewSentence {
                if starts.last != word.characterRange.lowerBound {
                    starts.append(word.characterRange.lowerBound)
                }
                expectNewSentence = false
            }
            if Self.endsSentence(word.text) {
                expectNewSentence = true
            }
        }
        return starts
    }

    private static func endsSentence(_ text: String) -> Bool {
        let closers: Set<Character> = ["\"", "'", "”", "’", ")", "]", "»"]
        var trimmed = text
        while let last = trimmed.last, closers.contains(last) {
            trimmed.removeLast()
        }
        guard let finalChar = trimmed.last else { return false }
        return finalChar == "." || finalChar == "!" || finalChar == "?"
            || finalChar == "。" || finalChar == "！" || finalChar == "？"
    }

    func nsRange(forCharacterRange range: Range<Int>) -> NSRange {
        let lower = text.index(text.startIndex, offsetBy: max(0, min(range.lowerBound, text.count)))
        let upper = text.index(text.startIndex, offsetBy: max(0, min(range.upperBound, text.count)))
        return NSRange(lower..<upper, in: text)
    }

    func nsRange(upToCharacterOffset offset: Int) -> NSRange {
        nsRange(forCharacterRange: 0..<max(0, min(offset, text.count)))
    }
}
