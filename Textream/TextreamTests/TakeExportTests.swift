//
//  TakeExportTests.swift
//  TextreamTests
//
//  Unit tests for Phase 3: word-level take timeline recording, clean-pass
//  retake deduplication, .srt/.vtt caption formatting, FCPXML/EDL/CSV NLE
//  marker exports, and sidecar JSON persistence.
//

import XCTest
@testable import Textream

final class TakeExportTests: XCTestCase {

    func testTimelineRecorderTracksRetakesAndResolvesCleanFinalPass() {
        let text = "[hook] Welcome back creators. Today we test clean captions."
        let script = PromptScript(text)
        let spoken = script.words.filter { !$0.isAnnotation }
        XCTAssertEqual(spoken.count, 8)

        var recorder = TakeTimelineRecorder(script: script)
        recorder.markStart(at: 10.0)
        // First pass through word 4 ("creators.")
        recorder.recordProgress(characterOffset: spoken[2].characterRange.upperBound, at: 11.5)
        recorder.recordProgress(characterOffset: spoken[4].characterRange.upperBound, at: 12.8)
        // Stumble & retake back to word 3 ("Today")
        recorder.recordProgress(characterOffset: spoken[3].characterRange.lowerBound, at: 13.5, isRetake: true)
        // Clean final pass through end
        recorder.recordProgress(characterOffset: spoken[5].characterRange.upperBound, at: 15.0)
        recorder.recordProgress(characterOffset: spoken[7].characterRange.upperBound, at: 16.5)
        recorder.addManualMarker(label: "B-roll cut", at: 16.0)

        let record = recorder.makeRecord(at: 17.0, scriptTitle: "Studio Demo", targetWPM: 150)

        // Should have Take Start + Retake + Manual Marker
        XCTAssertTrue(record.markers.contains { $0.kind == .goodTakeStart })
        XCTAssertTrue(record.markers.contains { $0.kind == .retake })
        XCTAssertTrue(record.markers.contains { $0.kind == .manual && $0.label == "B-roll cut" })

        // Clean final pass should contain every spoken word once, without duplicating retaken words
        let clean = record.resolvedWordTimings(cleanPassOnly: true)
        XCTAssertEqual(clean.map(\.text), ["Welcome", "back", "creators.", "Today", "we", "test", "clean", "captions."])
        // The retaken word "Today" (index 3) should use the later pass timestamp (> 3.5s)
        XCTAssertGreaterThan(clean[3].startSeconds, 3.0)
    }

    func testSRTAndVTTExportersProduceValidFormattedCaptions() {
        let samples: [WordTimingSample] = [
            WordTimingSample(wordIndex: 0, text: "Hello", startSeconds: 0.5, endSeconds: 0.9, passIndex: 0),
            WordTimingSample(wordIndex: 1, text: "creators.", startSeconds: 0.9, endSeconds: 1.4, passIndex: 0),
            WordTimingSample(wordIndex: 2, text: "Dante", startSeconds: 2.8, endSeconds: 3.2, passIndex: 0),
            WordTimingSample(wordIndex: 3, text: "syncs", startSeconds: 3.2, endSeconds: 3.6, passIndex: 0),
            WordTimingSample(wordIndex: 4, text: "captions!", startSeconds: 3.6, endSeconds: 4.1, passIndex: 0)
        ]
        let record = TakeTranscriptRecord(
            id: UUID(),
            scriptTitle: "Intro Video",
            createdAt: Date(),
            durationSeconds: 4.5,
            targetWPM: 150,
            wordTimings: samples,
            markers: []
        )

        let srt = CaptionExporter.exportSRT(from: record)
        XCTAssertTrue(srt.contains("1\n00:00:00,500 --> 00:00:01,400\nHello creators."))
        XCTAssertTrue(srt.contains("2\n00:00:02,800 --> 00:00:04,100\nDante syncs captions!"))

        let vtt = CaptionExporter.exportVTT(from: record)
        XCTAssertTrue(vtt.hasPrefix("WEBVTT\n\n"))
        XCTAssertTrue(vtt.contains("00:00:00.500 --> 00:00:01.400\nHello creators."))
        XCTAssertTrue(vtt.contains("00:00:02.800 --> 00:00:04.100\nDante syncs captions!"))
    }

    func testNLEMarkerExportersGenerateValidFCPXMLResolveEDLAndPremiereCSV() {
        let record = TakeTranscriptRecord(
            id: UUID(),
            scriptTitle: "Launch & Review <4K>",
            createdAt: Date(),
            durationSeconds: 65.0,
            targetWPM: 150,
            wordTimings: [],
            markers: [
                TakeMarker(kind: .goodTakeStart, timestampSeconds: 0.0, label: "Take Start", wordIndex: 0),
                TakeMarker(kind: .retake, timestampSeconds: 12.5, label: "Retake from \"audio\"", wordIndex: 18),
                TakeMarker(kind: .pageBreak, timestampSeconds: 40.0, label: "Page 2", wordIndex: 60)
            ]
        )

        let fcpxml = NLEMarkerExporter.exportFCPXML(from: record, frameRate: 30)
        XCTAssertTrue(fcpxml.contains("<fcpxml version=\"1.10\">"))
        XCTAssertTrue(fcpxml.contains("Launch &amp; Review &lt;4K&gt;"))
        XCTAssertTrue(fcpxml.contains("<chapter-marker start=\"0/30s\""))
        XCTAssertTrue(fcpxml.contains("<marker start=\"375/30s\""))
        XCTAssertTrue(fcpxml.contains("Retake from &quot;audio&quot;"))

        let edl = NLEMarkerExporter.exportDaVinciEDL(from: record, frameRate: 30)
        XCTAssertTrue(edl.contains("FCM: NON-DROP FRAME"))
        XCTAssertTrue(edl.contains("ResolveColorGreen"))
        XCTAssertTrue(edl.contains("ResolveColorRed"))
        XCTAssertTrue(edl.contains("00:00:12:15"))

        let csv = NLEMarkerExporter.exportPremiereCSV(from: record, frameRate: 30)
        XCTAssertTrue(csv.hasPrefix("Marker Name,Description,In,Out,Duration,Marker Type\n"))
        XCTAssertTrue(csv.contains("00:00:12:15"))
        XCTAssertTrue(csv.contains(",Chapter\n"))
    }

    func testSidecarPersistenceSavesLoadsAndDeletesCleanly() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DanteSidecarTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = TakeSidecarPersistence(directoryURL: tempDir)
        let record = TakeTranscriptRecord(
            id: UUID(),
            scriptTitle: "Sidecar Test",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 12.0,
            targetWPM: 160,
            wordTimings: [
                WordTimingSample(wordIndex: 0, text: "Ready", startSeconds: 0.2, endSeconds: 0.7, passIndex: 0)
            ],
            markers: [
                TakeMarker(kind: .manual, timestampSeconds: 1.0, label: "Clip highlight", wordIndex: 0)
            ]
        )

        let assetKey = "PHAsset/12345:L0/001"
        XCTAssertTrue(store.save(record, for: assetKey))
        let loaded = store.load(for: assetKey)
        XCTAssertEqual(loaded?.scriptTitle, "Sidecar Test")
        XCTAssertEqual(loaded?.wordTimings.count, 1)
        XCTAssertEqual(loaded?.markers.count, 1)

        store.delete(for: assetKey)
        XCTAssertNil(store.load(for: assetKey))
    }
}
