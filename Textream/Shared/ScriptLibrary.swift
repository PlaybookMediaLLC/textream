//
//  ScriptLibrary.swift
//  Dante for Creators
//

import Foundation

struct ScriptMetrics: Equatable, Sendable {
    static let defaultWPM = 150
    static let minWPM = 90
    static let maxWPM = 240

    let spokenWordCount: Int
    let characterCount: Int
    let estimatedSeconds: Int
    let targetWPM: Int

    var formattedDuration: String {
        Self.formattedDuration(seconds: estimatedSeconds)
    }

    var summaryLabel: String {
        let wordUnit = spokenWordCount == 1 ? "word" : "words"
        if spokenWordCount == 0 {
            return "0 words"
        }
        return "\(spokenWordCount) \(wordUnit) · ~\(formattedDuration)"
    }

    static func clampedWPM(_ wpm: Int) -> Int {
        min(max(wpm, minWPM), maxWPM)
    }

    static func measure(text: String, wordsPerMinute: Int = defaultWPM) -> ScriptMetrics {
        let safeWPM = clampedWPM(wordsPerMinute)
        let prompt = PromptScript(text)
        let spokenCount = prompt.words.reduce(0) { partial, word in
            partial + (word.isAnnotation ? 0 : 1)
        }
        let seconds: Int
        if spokenCount == 0 {
            seconds = 0
        } else {
            seconds = max(1, Int((Double(spokenCount) / Double(safeWPM) * 60.0).rounded()))
        }
        return ScriptMetrics(
            spokenWordCount: spokenCount,
            characterCount: text.count,
            estimatedSeconds: seconds,
            targetWPM: safeWPM
        )
    }

    static func measure(pages: [String], wordsPerMinute: Int = defaultWPM) -> ScriptMetrics {
        measure(text: pages.joined(separator: "\n\n"), wordsPerMinute: wordsPerMinute)
    }

    static func formattedDuration(seconds: Int) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let remainder = clamped % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%d:%02d", minutes, remainder)
    }
}

struct DanteScript: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var pages: [String]
    var presetID: CreatorPresetID?
    var targetWPM: Int
    var isPinned: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        pages: [String],
        presetID: CreatorPresetID? = nil,
        targetWPM: Int = ScriptMetrics.defaultWPM,
        isPinned: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.pages = pages.isEmpty ? [""] : pages
        self.presetID = presetID
        self.targetWPM = ScriptMetrics.clampedWPM(targetWPM)
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var combinedText: String {
        pages.joined(separator: "\n\n")
    }

    var metrics: ScriptMetrics {
        ScriptMetrics.measure(pages: pages, wordsPerMinute: targetWPM)
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let firstLine = pages
            .lazy
            .flatMap { $0.components(separatedBy: .newlines) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        if let firstLine, !firstLine.isEmpty {
            return firstLine.count > 36 ? String(firstLine.prefix(36)) + "…" : firstLine
        }
        return "Untitled Script"
    }

    var previewSnippet: String {
        let joined = pages.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? ""
        let collapsed = joined
            .replacingOccurrences(of: "\n", with: " ")
            .split(omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
            .prefix(14)
            .joined(separator: " ")
        return collapsed.isEmpty ? "Empty script" : collapsed
    }

    static func welcomeScript(forMac: Bool) -> DanteScript {
        if forMac {
            return DanteScript(
                title: "Welcome to Dante",
                pages: [
                    """
                    Welcome to Dante for Creators! Your studio teleprompter sits right below your camera so you stay connected with your audience. [smile]

                    Smart Follow tracks every word you speak in real time. Pause naturally, ad-lib a quick thought, skip ahead, or re-read a line—Dante finds your place automatically without throwing off your delivery. [pause]

                    Use [brackets] for stage cues like [look at camera] or [pause]. Dante displays them for you while skipping them during voice tracking.

                    Switch between YouTube Studio, Shorts / Reels, Podcast, and Keynote presets anytime, or enable On-Device AI models in Settings for 100% offline speech tracking. [nod]
                    """
                ],
                presetID: .youtubeStudio,
                targetWPM: 150,
                isPinned: true
            )
        } else {
            return DanteScript(
                title: "Welcome to Dante",
                pages: [
                    """
                    Welcome to Dante for Creators. [smile]

                    Read naturally and Smart Follow tracks every word you speak—even if you pause, improvise, or re-read a sentence.

                    In Record mode, your camera stays full screen while this script floats right beside the lens. Your script never appears in the saved video. [pause]
                    """
                ],
                presetID: .shortsReels,
                targetWPM: 165,
                isPinned: true
            )
        }
    }
}

struct ScriptLibraryPersistence: Sendable {
    let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.fileURL = base
                .appendingPathComponent("Dante for Creators", isDirectory: true)
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("scripts.json")
        }
    }

    func load() -> [DanteScript] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let scripts = try? decoder.decode([DanteScript].self, from: data) else {
            return []
        }
        return Self.sorted(scripts)
    }

    @discardableResult
    func save(_ scripts: [DanteScript]) -> Bool {
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(scripts)
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func sorted(_ scripts: [DanteScript]) -> [DanteScript] {
        scripts.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    static func filtered(_ scripts: [DanteScript], query: String) -> [DanteScript] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sorted(scripts) }
        return sorted(scripts).filter { script in
            script.displayTitle.localizedCaseInsensitiveContains(trimmed)
                || script.combinedText.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
