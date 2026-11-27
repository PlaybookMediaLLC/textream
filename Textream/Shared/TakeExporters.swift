//
//  TakeExporters.swift
//  Dante for Creators
//
//  Broadcast-ready caption (.srt, .vtt) and NLE timeline marker (.fcpxml,
//  DaVinci Resolve .edl, Premiere Pro .csv) exporters plus JSON sidecar storage.
//

import Foundation

enum TakeExportFormat: String, CaseIterable, Identifiable, Sendable {
    case srt
    case vtt
    case fcpxml
    case edl
    case premiereCSV

    var id: String { rawValue }

    var label: String {
        switch self {
        case .srt:         return "SubRip Captions (.srt)"
        case .vtt:         return "WebVTT Captions (.vtt)"
        case .fcpxml:      return "Final Cut Pro Markers (.fcpxml)"
        case .edl:         return "DaVinci Resolve Markers (.edl)"
        case .premiereCSV: return "Premiere Pro Markers (.csv)"
        }
    }

    var shortLabel: String {
        switch self {
        case .srt:         return ".SRT"
        case .vtt:         return ".VTT"
        case .fcpxml:      return "FCPXML"
        case .edl:         return "EDL"
        case .premiereCSV: return "CSV"
        }
    }

    var fileExtension: String {
        switch self {
        case .srt:         return "srt"
        case .vtt:         return "vtt"
        case .fcpxml:      return "fcpxml"
        case .edl:         return "edl"
        case .premiereCSV: return "csv"
        }
    }

    func suggestedFilename(baseTitle: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let filtered = baseTitle.unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
        let collapsed = String(filtered)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
        let stem = collapsed.isEmpty ? "dante-take" : String(collapsed.prefix(48))
        return "\(stem).\(fileExtension)"
    }

    func render(record: TakeTranscriptRecord, frameRate: Int = 30) -> String {
        switch self {
        case .srt:
            return CaptionExporter.exportSRT(from: record)
        case .vtt:
            return CaptionExporter.exportVTT(from: record)
        case .fcpxml:
            return NLEMarkerExporter.exportFCPXML(from: record, frameRate: frameRate)
        case .edl:
            return NLEMarkerExporter.exportDaVinciEDL(from: record, frameRate: frameRate)
        case .premiereCSV:
            return NLEMarkerExporter.exportPremiereCSV(from: record, frameRate: frameRate)
        }
    }
}

// MARK: - Caption Exporter (.srt / .vtt)

struct CaptionCue: Equatable, Sendable {
    let index: Int
    let startSeconds: Double
    let endSeconds: Double
    let lines: [String]
}

enum CaptionExporter {
    static func buildCues(
        from record: TakeTranscriptRecord,
        maxCharsPerLine: Int = 42,
        maxLines: Int = 2,
        maxCueDuration: Double = 4.5,
        pauseBreakThreshold: Double = 0.9,
        cleanPassOnly: Bool = true
    ) -> [CaptionCue] {
        let words = record.resolvedWordTimings(cleanPassOnly: cleanPassOnly)
        guard !words.isEmpty else { return [] }

        let maxTotalChars = maxCharsPerLine * maxLines
        var cues: [CaptionCue] = []
        var bucket: [WordTimingSample] = []
        var bucketCharCount = 0

        func flushBucket() {
            guard let first = bucket.first, let last = bucket.last else { return }
            let wrapped = wrapWords(bucket.map(\.text), maxCharsPerLine: maxCharsPerLine, maxLines: maxLines)
            let start = max(0, first.startSeconds)
            let end = max(start + 0.4, last.endSeconds)
            cues.append(CaptionCue(index: cues.count + 1, startSeconds: start, endSeconds: end, lines: wrapped))
            bucket.removeAll(keepingCapacity: true)
            bucketCharCount = 0
        }

        for sample in words {
            if let first = bucket.first, let previous = bucket.last {
                let gap = sample.startSeconds - previous.endSeconds
                let projectedChars = bucketCharCount + (bucket.isEmpty ? 0 : 1) + sample.text.count
                let projectedDuration = sample.endSeconds - first.startSeconds
                let previousEndedSentence = endsSentence(previous.text)

                if gap >= pauseBreakThreshold
                    || projectedChars > maxTotalChars
                    || projectedDuration > maxCueDuration
                    || (previousEndedSentence && bucketCharCount >= maxCharsPerLine / 2) {
                    flushBucket()
                }
            }

            bucketCharCount += (bucket.isEmpty ? 0 : 1) + sample.text.count
            bucket.append(sample)
        }
        flushBucket()

        // Ensure consecutive cues never overlap in time
        var normalized: [CaptionCue] = []
        normalized.reserveCapacity(cues.count)
        for i in 0..<cues.count {
            var cue = cues[i]
            if i + 1 < cues.count, cue.endSeconds > cues[i + 1].startSeconds {
                let adjustedEnd = max(cue.startSeconds + 0.2, cues[i + 1].startSeconds - 0.02)
                cue = CaptionCue(index: cue.index, startSeconds: cue.startSeconds, endSeconds: adjustedEnd, lines: cue.lines)
            }
            normalized.append(cue)
        }
        return normalized
    }

    static func exportSRT(from record: TakeTranscriptRecord, cleanPassOnly: Bool = true) -> String {
        let cues = buildCues(from: record, cleanPassOnly: cleanPassOnly)
        return cues.map { cue in
            """
            \(cue.index)
            \(formatSRTTimestamp(cue.startSeconds)) --> \(formatSRTTimestamp(cue.endSeconds))
            \(cue.lines.joined(separator: "\n"))
            """
        }.joined(separator: "\n\n") + (cues.isEmpty ? "" : "\n")
    }

    static func exportVTT(from record: TakeTranscriptRecord, cleanPassOnly: Bool = true) -> String {
        let cues = buildCues(from: record, cleanPassOnly: cleanPassOnly)
        guard !cues.isEmpty else { return "WEBVTT\n" }
        let body = cues.map { cue in
            """
            \(formatVTTTimestamp(cue.startSeconds)) --> \(formatVTTTimestamp(cue.endSeconds))
            \(cue.lines.joined(separator: "\n"))
            """
        }.joined(separator: "\n\n")
        return "WEBVTT\n\n\(body)\n"
    }

    static func formatSRTTimestamp(_ seconds: Double) -> String {
        formatSubtitleTimestamp(seconds, millisecondSeparator: ",")
    }

    static func formatVTTTimestamp(_ seconds: Double) -> String {
        formatSubtitleTimestamp(seconds, millisecondSeparator: ".")
    }

    private static func formatSubtitleTimestamp(_ seconds: Double, millisecondSeparator: String) -> String {
        let totalMillis = max(0, Int((seconds * 1000.0).rounded()))
        let hours = totalMillis / 3_600_000
        let minutes = (totalMillis % 3_600_000) / 60_000
        let secs = (totalMillis % 60_000) / 1_000
        let millis = totalMillis % 1_000
        return String(format: "%02d:%02d:%02d%@%03d", hours, minutes, secs, millisecondSeparator, millis)
    }

    private static func wrapWords(_ words: [String], maxCharsPerLine: Int, maxLines: Int) -> [String] {
        var lines: [String] = []
        var current = ""
        for word in words {
            if current.isEmpty {
                current = word
            } else if current.count + 1 + word.count <= maxCharsPerLine || lines.count + 1 >= maxLines {
                current += " " + word
            } else {
                lines.append(current)
                current = word
            }
        }
        if !current.isEmpty {
            lines.append(current)
        }
        return lines
    }

    private static func endsSentence(_ text: String) -> Bool {
        guard let last = text.trimmingCharacters(in: CharacterSet(charactersIn: "\"'”’)]")).last else {
            return false
        }
        return last == "." || last == "!" || last == "?" || last == "。" || last == "！" || last == "？"
    }
}

// MARK: - NLE Marker Exporter (Final Cut Pro XML, DaVinci Resolve EDL, Premiere Pro CSV)

enum NLEMarkerExporter {
    static func exportFCPXML(from record: TakeTranscriptRecord, frameRate: Int = 30) -> String {
        let fps = max(24, min(60, frameRate))
        let totalFrames = max(fps, Int((record.durationSeconds * Double(fps)).rounded()))
        let titleEscaped = xmlEscape(record.scriptTitle)

        var markerLines: [String] = []
        for marker in record.markers.sorted(by: { $0.timestampSeconds < $1.timestampSeconds }) {
            let startFrames = max(0, Int((marker.timestampSeconds * Double(fps)).rounded()))
            let valueEscaped = xmlEscape(marker.label)
            let noteEscaped = xmlEscape(marker.kind.displayLabel)
            if marker.kind == .pageBreak || marker.kind == .goodTakeStart {
                markerLines.append(
                    "                    <chapter-marker start=\"\(startFrames)/\(fps)s\" duration=\"1/\(fps)s\" value=\"\(valueEscaped)\" note=\"\(noteEscaped)\"/>"
                )
            } else {
                markerLines.append(
                    "                    <marker start=\"\(startFrames)/\(fps)s\" duration=\"1/\(fps)s\" value=\"\(valueEscaped)\" note=\"\(noteEscaped)\"/>"
                )
            }
        }

        let markersBlock = markerLines.isEmpty ? "" : "\n" + markerLines.joined(separator: "\n")
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE fcpxml>
        <fcpxml version="1.10">
            <resources>
                <format id="r1" name="FFVideoFormat1080p\(fps)" frameDuration="1/\(fps)s" width="1920" height="1080"/>
            </resources>
            <library>
                <event name="Dante for Creators">
                    <project name="\(titleEscaped)">
                        <sequence format="r1" duration="\(totalFrames)/\(fps)s" tcStart="0s" tcFormat="NDF">
                            <spine>
                                <gap name="\(titleEscaped)" offset="0s" duration="\(totalFrames)/\(fps)s" start="0s">\(markersBlock)
                                </gap>
                            </spine>
                        </sequence>
                    </project>
                </event>
            </library>
        </fcpxml>
        """
    }

    static func exportDaVinciEDL(from record: TakeTranscriptRecord, frameRate: Int = 30) -> String {
        let fps = max(24, min(60, frameRate))
        var lines: [String] = [
            "TITLE: \(record.scriptTitle.uppercased())",
            "FCM: NON-DROP FRAME",
            ""
        ]
        let sortedMarkers = record.markers.sorted { $0.timestampSeconds < $1.timestampSeconds }
        for (idx, marker) in sortedMarkers.enumerated() {
            let eventNum = String(format: "%03d", idx + 1)
            let tcIn = formatSMPTE(marker.timestampSeconds, fps: fps)
            let tcOut = formatSMPTE(marker.timestampSeconds + (1.0 / Double(fps)), fps: fps)
            let color: String
            switch marker.kind {
            case .retake:        color = "ResolveColorRed"
            case .goodTakeStart: color = "ResolveColorGreen"
            case .pageBreak:     color = "ResolveColorBlue"
            case .stageCue:      color = "ResolveColorYellow"
            case .manual:        color = "ResolveColorCyan"
            }
            let safeLabel = marker.label.replacingOccurrences(of: "|", with: "-")
            lines.append("\(eventNum)  001      V     C        \(tcIn) \(tcOut) \(tcIn) \(tcOut)")
            lines.append(" |C:\(color) |M:\(safeLabel) |D:1")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    static func exportPremiereCSV(from record: TakeTranscriptRecord, frameRate: Int = 30) -> String {
        let fps = max(24, min(60, frameRate))
        var lines: [String] = ["Marker Name,Description,In,Out,Duration,Marker Type"]
        for marker in record.markers.sorted(by: { $0.timestampSeconds < $1.timestampSeconds }) {
            let tc = formatSMPTE(marker.timestampSeconds, fps: fps)
            let name = csvEscape(marker.label)
            let desc = csvEscape(marker.kind.displayLabel)
            let markerType = marker.kind == .pageBreak ? "Chapter" : "Comment"
            lines.append("\(name),\(desc),\(tc),\(tc),00:00:00:00,\(markerType)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func formatSMPTE(_ seconds: Double, fps: Int) -> String {
        let safeFPS = max(1, fps)
        let totalFrames = max(0, Int((seconds * Double(safeFPS)).rounded()))
        let frames = totalFrames % safeFPS
        let totalSeconds = totalFrames / safeFPS
        let secs = totalSeconds % 60
        let minutes = (totalSeconds / 60) % 60
        let hours = totalSeconds / 3600
        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, secs, frames)
    }

    private static func xmlEscape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func csvEscape(_ text: String) -> String {
        let escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            return "\"\(escaped)\""
        }
        return escaped
    }
}

// MARK: - Sidecar Persistence (Shared by iOS SavedRecordingsStore & Tests)

struct TakeSidecarPersistence: Sendable {
    let directoryURL: URL

    init(directoryURL: URL? = nil) {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directoryURL = base
                .appendingPathComponent("Dante for Creators", isDirectory: true)
                .appendingPathComponent("TakeSidecars", isDirectory: true)
        }
    }

    func fileURL(for key: String) -> URL {
        let safeName = key
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "..", with: "_")
        return directoryURL.appendingPathComponent("\(safeName).json")
    }

    @discardableResult
    func save(_ record: TakeTranscriptRecord, for key: String) -> Bool {
        guard !key.isEmpty else { return false }
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(record)
            try data.write(to: fileURL(for: key), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    func load(for key: String) -> TakeTranscriptRecord? {
        guard !key.isEmpty, let data = try? Data(contentsOf: fileURL(for: key)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(TakeTranscriptRecord.self, from: data)
    }

    func delete(for key: String) {
        guard !key.isEmpty else { return }
        try? FileManager.default.removeItem(at: fileURL(for: key))
    }

    func writeTemporaryExport(
        record: TakeTranscriptRecord,
        format: TakeExportFormat,
        frameRate: Int = 30
    ) -> URL? {
        let filename = format.suggestedFilename(baseTitle: record.scriptTitle)
        let exportDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DanteTakeExports", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
            let destination = exportDir.appendingPathComponent(filename)
            let content = format.render(record: record, frameRate: frameRate)
            try content.write(to: destination, atomically: true, encoding: .utf8)
            return destination
        } catch {
            return nil
        }
    }
}
