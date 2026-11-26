import Foundation

/// Follows a reader through a script from streaming speech-recognition partials.
///
/// Every partial, only the *tail* of the transcript (the last few spoken words) is
/// aligned against the whole script with a word-level local alignment
/// (Smith–Waterman). The best alignment that ends on one of the newest spoken
/// words gives the candidate reading position, biased toward the current one:
///
/// * small forward steps commit as soon as the evidence clears a threshold that
///   grows with distance, so normal reading stays responsive;
/// * large jumps (a skipped paragraph, re-reading an earlier line) need a strong,
///   multi-word match that two consecutive partials agree on.
///
/// Nothing depends on aligning the whole transcript from a fixed start, so one
/// misheard word cannot derail tracking for the rest of a recognition session,
/// and off-script speech (ad-libs, fillers, a TV in the room) rarely clears the
/// commit threshold because common function words carry little weight.
/// Measured by `benchmarks/speech-tracking` (see its PLAN.md).
struct PromptMatcher {
    private(set) var source: PromptScript
    private(set) var recognizedCharacterCount: Int
    private(set) var matchStartOffset: Int

    /// Readable script tokens in reading order. A contraction in the script
    /// ("don't") becomes two tokens that point at the same word.
    private let tokens: [Token]
    private let vocabulary: [String]
    private let vocabularyWeights: [Double]
    /// `pairs[c]` joins the two script tokens ending at column `c` ("to"+"pick"), so one
    /// spoken word can match two script words: recognizers merge and split words all
    /// the time ("topic" / "to pick", "backlog" / "back log").
    private let pairs: [(text: String, count: Int, first: Character?, weight: Double)]
    /// Tokens read so far; the highlight sits at the start of `tokens[position]`.
    private var position: Int
    /// A far jump target waiting for a second agreeing partial.
    private var pendingJump: Int?
    private var similarityCache: [String: [Double]] = [:]
    /// Newest spoken words from before the current transcript began. Recognizers restart
    /// sessions, and on-device recognition also drops its transcript mid-session after a
    /// pause; prepending these keeps alignment context instead of re-acquiring from nothing.
    private var carriedTail: [String] = []
    private var lastTail: [String] = []
    private var lastHeard: [String] = []

    private struct Token { let vocabularyID: Int; let word: Int }
    /// `gain` sums the matches past the current position: the evidence that the reader
    /// actually moved, as opposed to re-confirming what was already read.
    /// `runnerUp` is the best score ending somewhere else in the script; a far jump
    /// needs a clear margin over it, so a repeated sentence can't teleport the reader.
    private struct Candidate { let position: Int; let score: Double; let gain: Double; let matches: Int; var runnerUp = 0.0 }

    // Tuning. Change these only with a benchmark run before and after.
    private static let tailLength = 12
    private static let recentLength = 6
    private static let nearWindow = 25          // tokens ahead treated as "keep reading"
    private static let backwardSlack = 3        // ignore tiny backward corrections (jitter)
    private static let farScore = 2.5
    private static let farMatches = 3
    private static let farUniqueness = 1.0 // score margin over any other location
    private static let nearUniqueness = 0.5
    private static let mismatchPenalty = 0.5
    private static let spokenGapPenalty = 0.35  // filler / inserted / misheard extra word
    private static let scriptGapPenalty = 0.45  // script word skipped or not recognised

    init(source: PromptScript, startingAt offset: Int = 0) {
        self.source = source
        var vocabularyIDs: [String: Int] = [:]
        var vocabulary: [String] = []
        var tokens: [Token] = []
        for word in source.words where !word.isAnnotation {
            for text in Self.canonicalTokens(word.text) {
                let id = vocabularyIDs[text] ?? {
                    vocabulary.append(text)
                    vocabularyIDs[text] = vocabulary.count - 1
                    return vocabulary.count - 1
                }()
                tokens.append(Token(vocabularyID: id, word: word.id))
            }
        }
        self.tokens = tokens
        self.vocabulary = vocabulary
        vocabularyWeights = vocabulary.map(Self.weight)
        let weights = vocabularyWeights
        pairs = tokens.indices.map { index in
            guard index > 0 else { return ("", 0, nil, 0) }
            let text = vocabulary[tokens[index - 1].vocabularyID] + vocabulary[tokens[index].vocabularyID]
            return (text, text.count, text.first,
                    weights[tokens[index - 1].vocabularyID] + weights[tokens[index].vocabularyID])
        }

        let start = SpeechTextAlignment.advancePastAnnotations(
            in: source.text,
            ranges: source.annotationRanges,
            from: offset
        )
        recognizedCharacterCount = start
        matchStartOffset = start
        position = Self.tokenPosition(forCharacterOffset: start, tokens: tokens, script: source)
    }

    mutating func reset(source: PromptScript, startingAt offset: Int = 0) {
        self = PromptMatcher(source: source, startingAt: offset)
    }

    /// Call when the recognizer starts a new session (fresh, empty transcript).
    /// A far jump still waiting for a second partial is committed: a session's last
    /// partial is its final result, so no revision is coming to contradict it.
    @discardableResult
    mutating func restartFromCurrentProgress() -> Int {
        if let pending = pendingJump { commit(pending) }
        matchStartOffset = recognizedCharacterCount
        carriedTail = lastTail
        lastHeard = []
        return recognizedCharacterCount
    }

    @discardableResult
    mutating func jump(to offset: Int) -> Int {
        let clamped = max(0, min(offset, source.characterCount))
        let target = SpeechTextAlignment.advancePastAnnotations(
            in: source.text,
            ranges: source.annotationRanges,
            from: clamped
        )
        recognizedCharacterCount = target
        matchStartOffset = target
        position = Self.tokenPosition(forCharacterOffset: target, tokens: tokens, script: source)
        pendingJump = nil
        carriedTail = []
        lastTail = []
        lastHeard = []
        return target
    }

    @discardableResult
    mutating func match(transcript: String) -> Int {
        let heard = Self.canonicalTokens(transcript)
        guard !heard.isEmpty else { return recognizedCharacterCount }
        // A partial that starts over (different first words and shorter; revisions of
        // the opening words keep or grow their length) is a new utterance: carry the words
        // heard just before it, not the context from when the session began.
        let prefixLength = min(3, heard.count, lastHeard.count)
        if prefixLength > 0, heard.prefix(prefixLength) != lastHeard.prefix(prefixLength),
           heard.count < lastHeard.count {
            carriedTail = lastTail
        }
        lastHeard = heard
        let spoken = Array((carriedTail + heard).suffix(Self.tailLength))
        lastTail = spoken
        guard !tokens.isEmpty,
              let best = bestCandidate(for: Array(spoken.suffix(Self.tailLength))) else {
            return recognizedCharacterCount
        }

        let distance = best.position - position
        if distance <= 0 && distance >= -Self.backwardSlack {
            return recognizedCharacterCount   // nothing new; a pending far jump stays pending
        }

        if distance > 0 && distance <= Self.nearWindow {
            guard best.gain >= Self.requiredGain(forStep: distance),
                  // Beyond a few words, the same phrase elsewhere (a refrain) must not tie.
                  distance <= 4 || best.score - best.runnerUp >= Self.nearUniqueness else {
                return recognizedCharacterCount
            }
            commit(best.position)
        } else {
            let evidence = distance > 0 ? best.gain : best.score
            guard evidence >= Self.farScore, best.matches >= Self.farMatches,
                  best.score - best.runnerUp >= Self.farUniqueness,
                  recentSpeechAgrees(with: best.position, heard: heard) else {
                pendingJump = nil
                return recognizedCharacterCount
            }
            if let pending = pendingJump, abs(pending - best.position) <= 4 {
                commit(best.position)
            } else if evidence >= Self.farScore + 1 {   // overwhelming: don't wait a partial
                commit(best.position)
            } else {
                pendingJump = best.position
            }
        }
        return recognizedCharacterCount
    }

    /// A long tail can stitch together words from several similar sentences (a re-read
    /// in a script with refrains), and carried context is old by definition. Before
    /// jumping far, the newest words of the current transcript alone must point at the
    /// same place, and nowhere else.
    private mutating func recentSpeechAgrees(with target: Int, heard: [String]) -> Bool {
        guard heard.count >= Self.farMatches,
              let recent = bestCandidate(for: Array(heard.suffix(Self.recentLength))) else { return false }
        return abs(recent.position - target) <= 2 && recent.score - recent.runnerUp >= Self.farUniqueness
    }

    // MARK: - Alignment

    private mutating func bestCandidate(for tail: [String]) -> Candidate? {
        let rows = tail.enumerated().map { index, word in
            similarities(for: word, allowPrefix: index == tail.count - 1)
        }
        let n = tokens.count
        var previousScores = [Double](repeating: 0, count: n + 1)
        var previousMatches = [Int](repeating: 0, count: n + 1)
        var previousGains = previousScores
        // Bits for the path's last 3 script steps, 1 = matched (newest in bit 0). Skipping
        // script words clears it; an extra spoken word leaves it unchanged.
        var previousRuns = previousMatches
        var scores = previousScores
        var matches = previousMatches
        var gains = previousScores
        var runs = previousMatches
        var best: Candidate?
        var bestAdjusted = -Double.infinity
        var ends: [(position: Int, score: Double)] = []
        // Only alignments ending on one of the newest words describe where the
        // reader is now; older ends describe where they were.
        let firstEndRow = max(1, tail.count - 2)

        for row in 1...tail.count {
            let similarity = rows[row - 1]
            let word = tail[row - 1]
            let wordCount = word.count
            let wordFirst = word.first
            scores[0] = 0
            matches[0] = 0
            gains[0] = 0
            runs[0] = 0
            for column in 1...n {
                let s = similarity[tokens[column - 1].vocabularyID]
                let isAhead = column > position
                let step = s > 0 ? s : -Self.mismatchPenalty
                let diagonal = previousScores[column - 1] + step
                var score = 0.0
                var matched = 0
                var gain = 0.0
                var run = 0
                if diagonal > score {
                    score = diagonal
                    matched = previousMatches[column - 1] + (s > 0 ? 1 : 0)
                    gain = previousGains[column - 1] + (isAhead && s > 0 ? s : 0)
                    run = ((previousRuns[column - 1] << 1) | (s > 0 ? 1 : 0)) & 0b111
                }
                // One spoken word for two script words ("topic" for "to pick").
                var merged = 0.0
                if column >= 2, wordCount >= 4 {
                    let pair = pairs[column - 1]
                    if pair.first == wordFirst, abs(pair.count - wordCount) <= max(1, pair.count / 4) {
                        merged = Self.similarity(word, pair.text) * pair.weight
                    }
                }
                let viaMerge = merged > 0 ? previousScores[column - 2] + merged : -Double.infinity
                if viaMerge > score {
                    score = viaMerge
                    matched = previousMatches[column - 2] + 2
                    gain = previousGains[column - 2] + (isAhead ? merged : 0)
                    run = ((previousRuns[column - 2] << 2) | 0b11) & 0b111
                }
                let skipSpoken = previousScores[column] - Self.spokenGapPenalty
                if skipSpoken > score {
                    score = skipSpoken
                    matched = previousMatches[column]
                    gain = previousGains[column]
                    run = previousRuns[column]
                }
                let skipScript = scores[column - 1] - Self.scriptGapPenalty
                if skipScript > score {
                    score = skipScript
                    matched = matches[column - 1]
                    gain = gains[column - 1]
                    run = 0
                }
                scores[column] = score
                matches[column] = matched
                gains[column] = gain
                runs[column] = run

                // A function word only says where the reader is when it continues real
                // matches: 2 of the last 3 script steps. Otherwise an ad-lib's stray "the"
                // could pull the highlight ahead ("…surprised [how quickly] the").
                let endWeight = vocabularyWeights[tokens[column - 1].vocabularyID]
                if row >= firstEndRow, (s > 0 && score == diagonal) || score == viaMerge,
                   endWeight >= 1 || run.nonzeroBitCount >= 2 || column - 1 == position {
                    ends.append((column, score))
                    let adjusted = score - Self.locationPenalty(forStep: column - position)
                    if adjusted > bestAdjusted {
                        bestAdjusted = adjusted
                        best = Candidate(position: column, score: score, gain: gain, matches: matched)
                    }
                }
            }
            swap(&scores, &previousScores)
            swap(&matches, &previousMatches)
            swap(&gains, &previousGains)
            swap(&runs, &previousRuns)
        }
        if let position = best?.position {
            best?.runnerUp = ends.lazy.filter { abs($0.position - position) > 8 }.map(\.score).max() ?? 0
        }
        return best
    }

    /// Similarity of one spoken word to every script vocabulary entry (0 = no match).
    private mutating func similarities(for word: String, allowPrefix: Bool) -> [Double] {
        var row: [Double]
        if let cached = similarityCache[word] {
            row = cached
        } else {
            row = vocabulary.indices.map { Self.similarity(word, vocabulary[$0]) * vocabularyWeights[$0] }
            if similarityCache.count > 4096 { similarityCache.removeAll(keepingCapacity: true) }
            similarityCache[word] = row
        }
        // The newest word may still be in progress ("presen…").
        if allowPrefix, word.count >= 3 {
            for index in vocabulary.indices where row[index] == 0 && vocabulary[index].hasPrefix(word) {
                row[index] = 0.5 * vocabularyWeights[index]
            }
        }
        return row
    }

    private static func similarity(_ spoken: String, _ script: String) -> Double {
        if spoken == script { return 1 }
        let shorter = min(spoken.count, script.count)
        let longer = max(spoken.count, script.count)
        guard shorter >= 4, longer - shorter <= max(1, longer / 4) else { return 0 }
        return editDistance(spoken, script) <= max(1, longer / 4) ? 0.7 : 0
    }

    /// One more word (even "the") is enough to move one or two tokens; longer
    /// steps need proportionally more new, in-order matches.
    private static func requiredGain(forStep step: Int) -> Double {
        step <= 2 ? 0.35 : 0.8 + 0.06 * Double(step)
    }

    private static func locationPenalty(forStep step: Int) -> Double {
        if step >= -backwardSlack && step <= nearWindow { return 0 }
        return 1 + min(2, 0.02 * Double(abs(step)))
    }

    private mutating func commit(_ newPosition: Int) {
        position = newPosition
        pendingJump = nil
        let offset = newPosition < tokens.count
            ? source.words[tokens[newPosition].word].characterRange.lowerBound
            : source.characterCount
        recognizedCharacterCount = SpeechTextAlignment.advancePastAnnotations(
            in: source.text,
            ranges: source.annotationRanges,
            from: offset
        )
    }

    private static func tokenPosition(forCharacterOffset offset: Int, tokens: [Token], script: PromptScript) -> Int {
        tokens.firstIndex { script.words[$0.word].characterRange.upperBound > offset } ?? tokens.count
    }

    // MARK: - Normalisation

    private static let stopWords: Set<String> = [
        "a", "an", "the", "and", "or", "but", "of", "to", "in", "on", "at", "for", "with", "by", "from",
        "as", "is", "are", "was", "were", "be", "been", "am", "it", "this", "that", "these", "those",
        "we", "you", "i", "he", "she", "they", "me", "us", "them", "my", "our", "your", "their", "his",
        "her", "its", "so", "if", "not", "no", "do", "does", "did", "will", "would", "can", "could",
        "have", "has", "had", "then", "than", "there", "here", "what", "when", "how", "just", "about",
        "all", "up", "out", "into", "over", "let", "like", "um", "uh",
    ]

    private static func weight(_ token: String) -> Double {
        if stopWords.contains(token) { return 0.35 }
        if token.count == 1, token.unicodeScalars.first?.isPromptCJK == true { return 0.5 }
        return 1 + min(0.5, Double(max(0, token.count - 4)) * 0.1)
    }

    private static let pronounIs: Set<String> = ["it", "that", "there", "here", "what", "who", "he", "she", "where"]

    /// Lowercased tokens with punctuation removed and English contractions expanded,
    /// so "don't" in the script matches "do not" spoken (and vice versa).
    static func canonicalTokens(_ text: String) -> [String] {
        var result: [String] = []
        for raw in splitPromptTextIntoWords(text.lowercased().replacingOccurrences(of: "’", with: "'")) {
            for piece in expandContraction(raw) {
                let cleaned = piece.filter { $0.isLetter || $0.isNumber }
                if !cleaned.isEmpty { result += expandScale(cleaned) }
            }
        }
        return result
    }

    private static let scales = ["k": "thousand", "m": "million", "bn": "billion", "b": "billion"]

    /// "45m" (from "$4.5M") → ["45", "million"], matching how recognizers write it out.
    private static func expandScale(_ token: String) -> [String] {
        guard let digitsEnd = token.firstIndex(where: { !$0.isNumber }), digitsEnd != token.startIndex,
              let scale = scales[String(token[digitsEnd...])] else { return [token] }
        return [String(token[..<digitsEnd]), scale]
    }

    private static func expandContraction(_ word: String) -> [String] {
        let bare = word.filter { $0.isLetter || $0.isNumber || $0 == "'" }
        switch bare {
        case "can't", "cannot": return ["can", "not"]
        case "won't": return ["will", "not"]
        case "let's": return ["let", "us"]
        default: break
        }
        guard bare.contains("'") else { return [word] }
        for (suffix, expansion) in [("n't", "not"), ("'re", "are"), ("'ll", "will"), ("'ve", "have"), ("'m", "am"), ("'d", "would")]
            where bare.hasSuffix(suffix) {
            return [String(bare.dropLast(suffix.count)), expansion]
        }
        if bare.hasSuffix("'s"), pronounIs.contains(String(bare.dropLast(2))) {
            return [String(bare.dropLast(2)), "is"]
        }
        return [word]
    }

    static func editDistance(_ first: String, _ second: String) -> Int {
        let firstCharacters = Array(first)
        let secondCharacters = Array(second)
        guard !firstCharacters.isEmpty else { return secondCharacters.count }
        guard !secondCharacters.isEmpty else { return firstCharacters.count }
        var row = Array(0...secondCharacters.count)
        for firstIndex in 1...firstCharacters.count {
            var previous = row[0]
            row[0] = firstIndex
            for secondIndex in 1...secondCharacters.count {
                let temporary = row[secondIndex]
                row[secondIndex] = firstCharacters[firstIndex - 1] == secondCharacters[secondIndex - 1]
                    ? previous
                    : min(previous, row[secondIndex], row[secondIndex - 1]) + 1
                previous = temporary
            }
        }
        return row[secondCharacters.count]
    }
}
