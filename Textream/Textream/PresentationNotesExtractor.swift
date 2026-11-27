//
//  PresentationNotesExtractor.swift
//  Dante for Creators
//

import Compression
import Foundation

enum PresentationNotesExtractor {

    enum ExtractionError: LocalizedError {
        case unsupportedFormat
        case extractionFailed(String)
        case noNotesFound

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat:
                return "Unsupported file format. Please drop a .pptx or .key file."
            case .extractionFailed(let detail):
                return "Failed to extract notes: \(detail)"
            case .noNotesFound:
                return "No presenter notes found in this presentation."
            }
        }
    }

    static func extractNotes(from url: URL) throws -> [String] {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pptx":
            return try extractPPTXNotes(from: url)
        default:
            throw ExtractionError.unsupportedFormat
        }
    }

    // MARK: - PPTX Extraction

    private static let maxArchiveBytes = 256 * 1024 * 1024
    private static let maxNoteEntryBytes = 16 * 1024 * 1024
    private static let maxTotalNotesBytes = 64 * 1024 * 1024

    private static func extractPPTXNotes(from url: URL) throws -> [String] {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        let archiveData: Data
        do {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = values?.fileSize, fileSize > maxArchiveBytes {
                throw ExtractionError.extractionFailed("PPTX file exceeds maximum supported size.")
            }
            archiveData = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch let error as ExtractionError {
            throw error
        } catch {
            throw ExtractionError.extractionFailed("Could not read PPTX file.")
        }

        return try extractPPTXNotes(fromArchiveData: archiveData)
    }

    /// Parses presenter notes directly from PPTX ZIP bytes in memory without
    /// spawning external subprocesses.
    static func extractPPTXNotes(fromArchiveData data: Data) throws -> [String] {
        let entries = try PPTXZipReader.listEntries(in: data)

        let noteEntries = entries
            .filter { entry in
                let normalized = entry.name
                guard normalized.hasPrefix("ppt/notesSlides/") else { return false }
                let filename = (normalized as NSString).lastPathComponent
                return filename.hasPrefix("notesSlide") && filename.hasSuffix(".xml")
            }
            .sorted { lhs, rhs in
                let n1 = extractNumber(from: (lhs.name as NSString).lastPathComponent) ?? 0
                let n2 = extractNumber(from: (rhs.name as NSString).lastPathComponent) ?? 0
                return n1 < n2
            }

        guard !noteEntries.isEmpty else {
            throw ExtractionError.noNotesFound
        }

        var pages: [String] = []
        var totalDecodedBytes = 0

        for entry in noteEntries {
            let xmlData = try PPTXZipReader.extract(
                entry,
                from: data,
                maxUncompressedBytes: maxNoteEntryBytes
            )
            totalDecodedBytes += xmlData.count
            guard totalDecodedBytes <= maxTotalNotesBytes else {
                throw ExtractionError.extractionFailed("Presentation notes exceed safety size limits.")
            }
            let text = parsePPTXNoteXML(data: xmlData)
            pages.append(text)
        }

        // Filter out empty slides and slides that only have the slide number placeholder
        pages = pages.compactMap { page in
            let trimmed = page.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty && Int(trimmed) == nil else { return nil }
            return trimmed
        }

        guard !pages.isEmpty else {
            throw ExtractionError.noNotesFound
        }

        return pages
    }

    private static func extractNumber(from filename: String) -> Int? {
        let digits = filename.filter { $0.isNumber }
        return Int(digits)
    }

    private static func parsePPTXNoteXML(data: Data) -> String {
        let parser = PPTXNoteXMLParser(data: data)
        return parser.parse()
    }
}

// MARK: - In-Process ZIP Reader (Stored & Raw DEFLATE)

enum PPTXZipReader {
    struct Entry: Equatable {
        let name: String
        let compressionMethod: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    private static let eocdSignature: UInt32 = 0x0605_4b50
    private static let centralDirSignature: UInt32 = 0x0201_4b50
    private static let localHeaderSignature: UInt32 = 0x0403_4b50
    private static let zip64ExtraHeaderID: UInt16 = 0x0001
    private static let maxEntries = 20_000

    static func listEntries(in data: Data) throws -> [Entry] {
        guard data.count >= 22 else {
            throw PresentationNotesExtractor.ExtractionError.extractionFailed("Invalid PPTX archive.")
        }

        guard let eocdOffset = findEndOfCentralDirectory(in: data) else {
            throw PresentationNotesExtractor.ExtractionError.extractionFailed("Could not locate ZIP directory in PPTX file.")
        }

        let entryCount = Int(readUInt16(data, at: eocdOffset + 10))
        let centralDirSize = Int(readUInt32(data, at: eocdOffset + 12))
        let centralDirOffset = Int(readUInt32(data, at: eocdOffset + 16))

        guard entryCount <= maxEntries,
              centralDirOffset >= 0,
              centralDirSize >= 0,
              centralDirOffset + centralDirSize <= data.count else {
            throw PresentationNotesExtractor.ExtractionError.extractionFailed("Corrupt ZIP central directory.")
        }

        var entries: [Entry] = []
        entries.reserveCapacity(min(entryCount, 256))

        var cursor = centralDirOffset
        let centralDirEnd = centralDirOffset + centralDirSize

        while cursor + 46 <= centralDirEnd {
            guard readUInt32(data, at: cursor) == centralDirSignature else {
                throw PresentationNotesExtractor.ExtractionError.extractionFailed("Invalid ZIP central directory entry.")
            }

            let compressionMethod = readUInt16(data, at: cursor + 10)
            var compressedSize = UInt64(readUInt32(data, at: cursor + 20))
            var uncompressedSize = UInt64(readUInt32(data, at: cursor + 24))
            let nameLength = Int(readUInt16(data, at: cursor + 28))
            let extraLength = Int(readUInt16(data, at: cursor + 30))
            let commentLength = Int(readUInt16(data, at: cursor + 32))
            var localHeaderOffset = UInt64(readUInt32(data, at: cursor + 42))

            let nameStart = cursor + 46
            let nameEnd = nameStart + nameLength
            let extraEnd = nameEnd + extraLength
            let nextCursor = extraEnd + commentLength

            guard nextCursor <= centralDirEnd else {
                throw PresentationNotesExtractor.ExtractionError.extractionFailed("Truncated ZIP entry header.")
            }

            if compressedSize == 0xFFFF_FFFF || uncompressedSize == 0xFFFF_FFFF || localHeaderOffset == 0xFFFF_FFFF {
                parseZip64Extra(
                    in: data,
                    range: nameEnd..<extraEnd,
                    uncompressedSize: &uncompressedSize,
                    compressedSize: &compressedSize,
                    localHeaderOffset: &localHeaderOffset
                )
            }

            let nameData = data[nameStart..<nameEnd]
            if let rawName = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .isoLatin1),
               let safeName = sanitizedEntryPath(rawName),
               compressedSize <= UInt64(Int.max),
               uncompressedSize <= UInt64(Int.max),
               localHeaderOffset <= UInt64(Int.max) {
                entries.append(Entry(
                    name: safeName,
                    compressionMethod: compressionMethod,
                    compressedSize: Int(compressedSize),
                    uncompressedSize: Int(uncompressedSize),
                    localHeaderOffset: Int(localHeaderOffset)
                ))
            }

            cursor = nextCursor
            if entries.count > maxEntries {
                throw PresentationNotesExtractor.ExtractionError.extractionFailed("Archive contains too many entries.")
            }
        }

        return entries
    }

    static func extract(
        _ entry: Entry,
        from data: Data,
        maxUncompressedBytes: Int
    ) throws -> Data {
        guard entry.uncompressedSize <= maxUncompressedBytes else {
            throw PresentationNotesExtractor.ExtractionError.extractionFailed("Slide note entry exceeds size limit.")
        }

        let localOffset = entry.localHeaderOffset
        guard localOffset >= 0, localOffset + 30 <= data.count else {
            throw PresentationNotesExtractor.ExtractionError.extractionFailed("Invalid ZIP entry offset.")
        }
        guard readUInt32(data, at: localOffset) == localHeaderSignature else {
            throw PresentationNotesExtractor.ExtractionError.extractionFailed("Invalid ZIP local file header.")
        }

        let localNameLength = Int(readUInt16(data, at: localOffset + 26))
        let localExtraLength = Int(readUInt16(data, at: localOffset + 28))
        let payloadStart = localOffset + 30 + localNameLength + localExtraLength
        let payloadEnd = payloadStart + entry.compressedSize

        guard payloadStart >= 0, payloadEnd <= data.count, payloadStart <= payloadEnd else {
            throw PresentationNotesExtractor.ExtractionError.extractionFailed("Truncated ZIP entry payload.")
        }

        let payload = data[payloadStart..<payloadEnd]

        switch entry.compressionMethod {
        case 0:
            guard payload.count <= maxUncompressedBytes else {
                throw PresentationNotesExtractor.ExtractionError.extractionFailed("Slide note entry exceeds size limit.")
            }
            return Data(payload)
        case 8:
            return try inflateRawDeflate(payload, maxOutputBytes: maxUncompressedBytes)
        default:
            throw PresentationNotesExtractor.ExtractionError.extractionFailed(
                "Unsupported ZIP compression method (\(entry.compressionMethod))."
            )
        }
    }

    /// Rejects absolute paths, null bytes, and `..` path traversal segments.
    static func sanitizedEntryPath(_ rawPath: String) -> String? {
        guard !rawPath.isEmpty, !rawPath.contains("\0") else { return nil }
        let normalized = rawPath.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.hasPrefix("/") else { return nil }
        let components = normalized.split(separator: "/", omittingEmptySubsequences: false)
        for component in components {
            if component == ".." {
                return nil
            }
        }
        return normalized
    }

    private static func findEndOfCentralDirectory(in data: Data) -> Int? {
        let minOffset = max(0, data.count - 22 - 65_535)
        var offset = data.count - 22
        while offset >= minOffset {
            if readUInt32(data, at: offset) == eocdSignature {
                let commentLength = Int(readUInt16(data, at: offset + 20))
                if offset + 22 + commentLength == data.count {
                    return offset
                }
            }
            offset -= 1
        }
        return nil
    }

    private static func parseZip64Extra(
        in data: Data,
        range: Range<Int>,
        uncompressedSize: inout UInt64,
        compressedSize: inout UInt64,
        localHeaderOffset: inout UInt64
    ) {
        var cursor = range.lowerBound
        while cursor + 4 <= range.upperBound {
            let headerID = readUInt16(data, at: cursor)
            let fieldSize = Int(readUInt16(data, at: cursor + 2))
            let bodyStart = cursor + 4
            let bodyEnd = bodyStart + fieldSize
            guard bodyEnd <= range.upperBound else { break }

            if headerID == zip64ExtraHeaderID {
                var fieldCursor = bodyStart
                if uncompressedSize == 0xFFFF_FFFF, fieldCursor + 8 <= bodyEnd {
                    uncompressedSize = readUInt64(data, at: fieldCursor)
                    fieldCursor += 8
                }
                if compressedSize == 0xFFFF_FFFF, fieldCursor + 8 <= bodyEnd {
                    compressedSize = readUInt64(data, at: fieldCursor)
                    fieldCursor += 8
                }
                if localHeaderOffset == 0xFFFF_FFFF, fieldCursor + 8 <= bodyEnd {
                    localHeaderOffset = readUInt64(data, at: fieldCursor)
                }
                return
            }
            cursor = bodyEnd
        }
    }

    private static func inflateRawDeflate(_ compressed: Data.SubSequence, maxOutputBytes: Int) throws -> Data {
        guard !compressed.isEmpty else { return Data() }

        let dummy = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        defer { dummy.deallocate() }

        var stream = compression_stream(
            dst_ptr: dummy,
            dst_size: 0,
            src_ptr: dummy,
            src_size: 0,
            state: nil
        )
        let initStatus = compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
        guard initStatus == COMPRESSION_STATUS_OK else {
            throw PresentationNotesExtractor.ExtractionError.extractionFailed("Could not initialize ZIP decompressor.")
        }
        defer { compression_stream_destroy(&stream) }

        let chunkSize = 64 * 1024
        let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
        defer { dstBuffer.deallocate() }

        var output = Data()

        try compressed.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return }
            stream.src_ptr = baseAddress
            stream.src_size = rawBuffer.count

            while true {
                stream.dst_ptr = dstBuffer
                stream.dst_size = chunkSize

                let status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                let produced = chunkSize - stream.dst_size
                if produced > 0 {
                    guard output.count + produced <= maxOutputBytes else {
                        throw PresentationNotesExtractor.ExtractionError.extractionFailed("Decompressed slide note exceeds size limit.")
                    }
                    output.append(dstBuffer, count: produced)
                }

                switch status {
                case COMPRESSION_STATUS_OK:
                    continue
                case COMPRESSION_STATUS_END:
                    return
                default:
                    throw PresentationNotesExtractor.ExtractionError.extractionFailed("Could not decompress PPTX slide notes.")
                }
            }
        }

        return output
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        let base = data.startIndex + offset
        return UInt16(data[base]) | (UInt16(data[base + 1]) << 8)
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        let base = data.startIndex + offset
        return UInt32(data[base])
            | (UInt32(data[base + 1]) << 8)
            | (UInt32(data[base + 2]) << 16)
            | (UInt32(data[base + 3]) << 24)
    }

    private static func readUInt64(_ data: Data, at offset: Int) -> UInt64 {
        UInt64(readUInt32(data, at: offset))
            | (UInt64(readUInt32(data, at: offset + 4)) << 32)
    }
}

// MARK: - PPTX Notes XML Parser

private class PPTXNoteXMLParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var paragraphs: [String] = []
    private var currentParagraph = ""
    private var currentText = ""
    private var insideBody = false
    private var insideTextRun = false
    private var insideParagraph = false
    private var skipPlaceholder = false
    private var currentPlaceholderType: String?

    init(data: Data) {
        self.data = data
    }

    func parse() -> String {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return paragraphs.joined(separator: "\n")
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String]) {
        if elementName.hasSuffix(":sp") || elementName == "sp" {
            skipPlaceholder = false
            currentPlaceholderType = nil
        }

        if elementName.hasSuffix(":ph") || elementName == "ph" {
            let type = attributes["type"] ?? ""
            currentPlaceholderType = type
            if type == "sldNum" || type == "sldImg" || type == "dt" || type == "hdr" || type == "ftr" {
                skipPlaceholder = true
            }
        }

        if elementName.hasSuffix(":txBody") || elementName == "txBody" {
            insideBody = true
        }

        // Start of a paragraph
        if (elementName.hasSuffix(":p") || elementName == "p") && insideBody && !skipPlaceholder {
            insideParagraph = true
            currentParagraph = ""
        }

        if (elementName.hasSuffix(":t") || elementName == "t") && insideParagraph {
            insideTextRun = true
            currentText = ""
        }

        // Handle line breaks within a paragraph
        if (elementName.hasSuffix(":br") || elementName == "br") && insideParagraph {
            currentParagraph += "\n"
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideTextRun {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        if (elementName.hasSuffix(":t") || elementName == "t") && insideTextRun {
            insideTextRun = false
            currentParagraph += currentText
        }

        // End of a paragraph — flush it
        if (elementName.hasSuffix(":p") || elementName == "p") && insideParagraph {
            insideParagraph = false
            paragraphs.append(currentParagraph)
        }

        if elementName.hasSuffix(":txBody") || elementName == "txBody" {
            insideBody = false
        }

        if elementName.hasSuffix(":sp") || elementName == "sp" {
            skipPlaceholder = false
            currentPlaceholderType = nil
        }
    }
}
