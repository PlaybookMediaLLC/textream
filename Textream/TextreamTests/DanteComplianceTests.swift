//
//  DanteComplianceTests.swift
//  TextreamTests
//

import Compression
import Foundation
import XCTest
@testable import Textream

final class DanteComplianceTests: XCTestCase {

    // MARK: - In-Process PPTX ZIP Extraction & Security

    func testPPTXInProcessExtractionReadsStoredAndDeflatedNotesInSlideOrder() throws {
        let slide2XML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <p:notes xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
          <p:cSld><p:spTree><p:sp><p:txBody><a:p><a:r><a:t>Second slide note</a:t></a:r></a:p></p:txBody></p:sp></p:spTree></p:cSld>
        </p:notes>
        """
        let slide1XML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <p:notes xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
          <p:cSld><p:spTree><p:sp><p:txBody><a:p><a:r><a:t>First slide note</a:t></a:r></a:p></p:txBody></p:sp></p:spTree></p:cSld>
        </p:notes>
        """
        let archive = makeTestZip(entries: [
            ("ppt/notesSlides/notesSlide2.xml", Data(slide2XML.utf8), true),
            ("ppt/notesSlides/notesSlide1.xml", Data(slide1XML.utf8), false)
        ])

        let notes = try PresentationNotesExtractor.extractPPTXNotes(fromArchiveData: archive)
        XCTAssertEqual(notes, ["First slide note", "Second slide note"])
    }

    func testPPTXZipReaderRejectsPathTraversalEntries() {
        XCTAssertNil(PPTXZipReader.sanitizedEntryPath("../evil.xml"))
        XCTAssertNil(PPTXZipReader.sanitizedEntryPath("ppt/../../evil.xml"))
        XCTAssertNil(PPTXZipReader.sanitizedEntryPath("/etc/passwd"))
        XCTAssertEqual(
            PPTXZipReader.sanitizedEntryPath("ppt\\notesSlides\\notesSlide1.xml"),
            "ppt/notesSlides/notesSlide1.xml"
        )
    }

    // MARK: - Model Catalog & Hardware Advisor

    func testSpeechModelCatalogExcludesMoonshineStreamingTiny() {
        let repoIDs = SpeechModelCatalog.models.map(\.repoID)
        XCTAssertFalse(repoIDs.isEmpty)
        XCTAssertFalse(repoIDs.contains("handy-computer/moonshine-streaming-tiny-gguf"))
    }

    func testHardwareAdvisorGatesHeavyModelsOnIntelAndWarnsOnLowRAM() {
        let heavyModelBytes: UInt64 = 750 * 1024 * 1024
        let lightModelBytes: UInt64 = 150 * 1024 * 1024
        let eightGB: UInt64 = 8 * 1024 * 1024 * 1024
        let thirtyTwoGB: UInt64 = 32 * 1024 * 1024 * 1024

        XCTAssertTrue(LocalSpeechHardwareAdvisor.requiresAppleSilicon(for: heavyModelBytes))
        XCTAssertFalse(LocalSpeechHardwareAdvisor.requiresAppleSilicon(for: lightModelBytes))
        XCTAssertNotNil(
            LocalSpeechHardwareAdvisor.hardwareWarning(
                for: heavyModelBytes,
                isAppleSilicon: false,
                physicalMemoryBytes: thirtyTwoGB
            )
        )
        XCTAssertNil(
            LocalSpeechHardwareAdvisor.hardwareWarning(
                for: heavyModelBytes,
                isAppleSilicon: true,
                physicalMemoryBytes: thirtyTwoGB
            )
        )
        XCTAssertNotNil(
            LocalSpeechHardwareAdvisor.memoryWarning(
                for: 3 * 1024 * 1024 * 1024,
                physicalMemoryBytes: eightGB
            )
        )
        XCTAssertEqual(
            LocalSpeechHardwareAdvisor.benchmarkBadge(for: "handy-computer/nemotron-3.5-asr-streaming-0.6b-gguf")?.title,
            "Best Live Streaming"
        )
        XCTAssertEqual(
            LocalSpeechHardwareAdvisor.benchmarkBadge(for: "handy-computer/Qwen3-ASR-1.7B-gguf")?.title,
            "Best for Strong Accents"
        )
        XCTAssertEqual(
            LocalSpeechHardwareAdvisor.benchmarkBadge(for: "handy-computer/canary-180m-flash-gguf")?.title,
            "Fastest Low-Memory"
        )
    }

    // MARK: - Creator Presets, Script Library & Acknowledgements

    func testCreatorPresetsApplyExpectedSettings() {
        let settings = NotchSettings()
        settings.apply(preset: CreatorPreset.preset(for: .keynoteLive))
        XCTAssertEqual(settings.overlayMode, .pinned)
        XCTAssertEqual(settings.listeningMode, .wordTracking)
        XCTAssertTrue(settings.hideFromScreenShare)
        XCTAssertTrue(settings.keepScreenAwake)
        XCTAssertTrue(settings.autoNextPage)
        XCTAssertTrue(settings.showParagraphDividers)
    }

    func testMacOpenSourceLicenseCatalogIncludesAllFourRequiredEntries() {
        let entries = OpenSourceLicenseCatalog.entries(includeLocalSpeechModels: true)
        let ids = entries.map(\.id)
        XCTAssertEqual(ids, ["textream", "opendyslexic", "transcribecpp", "speech-models"])
        XCTAssertTrue(entries[0].fullText.contains("Copyright (c) 2026 Fatih Kadir Akin"))
    }

    func testScriptMetricsCountsSpokenWordsExcludingAnnotations() {
        let metrics = ScriptMetrics.measure(
            pages: ["Hello [smile] world", "One two three [pause]"],
            wordsPerMinute: 120
        )
        XCTAssertEqual(metrics.spokenWordCount, 5)
        XCTAssertEqual(metrics.estimatedSeconds, 3)
    }

    // MARK: - Minimal ZIP Builder Helper

    private func makeTestZip(entries: [(name: String, content: Data, deflate: Bool)]) -> Data {
        var archive = Data()
        var centralDirectory = Data()

        for entry in entries {
            let nameData = Data(entry.name.utf8)
            let method: UInt16 = entry.deflate ? 8 : 0
            let payload = entry.deflate ? rawDeflate(entry.content) : entry.content
            let localOffset = UInt32(archive.count)

            // Local file header
            appendUInt32(&archive, 0x0403_4b50)
            appendUInt16(&archive, 20)
            appendUInt16(&archive, 0)
            appendUInt16(&archive, method)
            appendUInt16(&archive, 0)
            appendUInt16(&archive, 0)
            appendUInt32(&archive, 0) // CRC unused by reader
            appendUInt32(&archive, UInt32(payload.count))
            appendUInt32(&archive, UInt32(entry.content.count))
            appendUInt16(&archive, UInt16(nameData.count))
            appendUInt16(&archive, 0)
            archive.append(nameData)
            archive.append(payload)

            // Central directory header
            appendUInt32(&centralDirectory, 0x0201_4b50)
            appendUInt16(&centralDirectory, 20)
            appendUInt16(&centralDirectory, 20)
            appendUInt16(&centralDirectory, 0)
            appendUInt16(&centralDirectory, method)
            appendUInt16(&centralDirectory, 0)
            appendUInt16(&centralDirectory, 0)
            appendUInt32(&centralDirectory, 0)
            appendUInt32(&centralDirectory, UInt32(payload.count))
            appendUInt32(&centralDirectory, UInt32(entry.content.count))
            appendUInt16(&centralDirectory, UInt16(nameData.count))
            appendUInt16(&centralDirectory, 0)
            appendUInt16(&centralDirectory, 0)
            appendUInt16(&centralDirectory, 0)
            appendUInt16(&centralDirectory, 0)
            appendUInt32(&centralDirectory, 0)
            appendUInt32(&centralDirectory, localOffset)
            centralDirectory.append(nameData)
        }

        let cdOffset = UInt32(archive.count)
        archive.append(centralDirectory)

        // End of central directory
        appendUInt32(&archive, 0x0605_4b50)
        appendUInt16(&archive, 0)
        appendUInt16(&archive, 0)
        appendUInt16(&archive, UInt16(entries.count))
        appendUInt16(&archive, UInt16(entries.count))
        appendUInt32(&archive, UInt32(centralDirectory.count))
        appendUInt32(&archive, cdOffset)
        appendUInt16(&archive, 0)

        return archive
    }

    private func rawDeflate(_ input: Data) -> Data {
        let capacity = max(64, input.count * 2)
        let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        defer { dst.deallocate() }
        let compressedCount = input.withUnsafeBytes { raw -> Int in
            guard let src = raw.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_encode_buffer(dst, capacity, src, input.count, nil, COMPRESSION_ZLIB)
        }
        return Data(bytes: dst, count: compressedCount)
    }

    private func appendUInt16(_ data: inout Data, _ value: UInt16) {
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
    }

    private func appendUInt32(_ data: inout Data, _ value: UInt32) {
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 24) & 0xFF))
    }
}
