//
//  ScriptSyncTests.swift
//  TextreamTests
//
//  Unit tests for Phase 4: last-write-wins script merging, tombstone deletion
//  propagation, backward-compatible JSON decoding, and bidirectional sync via
//  InMemoryScriptSyncTransport.
//

import XCTest
@testable import Textream

final class ScriptSyncTests: XCTestCase {

    func testLastWriteWinsMergeResolvesEditsAndTombstoneDeletions() {
        let baseDate = Date(timeIntervalSince1970: 1_750_000_000)
        let sharedID = UUID()
        let deletedID = UUID()
        let remoteOnlyID = UUID()

        let localOlder = DanteScript(
            id: sharedID,
            title: "Draft v1",
            pages: ["Old copy"],
            updatedAt: baseDate
        )
        let localKept = DanteScript(
            id: deletedID,
            title: "Soon Deleted",
            pages: ["Body"],
            updatedAt: baseDate
        )

        let remoteNewer = DanteScript(
            id: sharedID,
            title: "Draft v2 (Edited on iPhone)",
            pages: ["Updated copy"],
            updatedAt: baseDate.addingTimeInterval(60)
        )
        let remoteDeleted = DanteScript(
            id: deletedID,
            title: "Soon Deleted",
            pages: ["Body"],
            updatedAt: baseDate,
            deletedAt: baseDate.addingTimeInterval(120)
        )
        let remoteOnly = DanteScript(
            id: remoteOnlyID,
            title: "Created on iPad",
            pages: ["Hello from iPad"],
            updatedAt: baseDate.addingTimeInterval(30)
        )

        let merged = DanteScript.merge(
            local: [localOlder, localKept],
            remote: [remoteNewer, remoteDeleted, remoteOnly],
            now: baseDate.addingTimeInterval(300)
        )

        XCTAssertEqual(merged.first(where: { $0.id == sharedID })?.title, "Draft v2 (Edited on iPhone)")
        XCTAssertEqual(merged.first(where: { $0.id == deletedID })?.isDeleted, true)
        XCTAssertNotNil(merged.first(where: { $0.id == remoteOnlyID }))

        // Expired tombstones (> 30 days) are pruned automatically
        let pruned = DanteScript.merge(
            local: merged,
            remote: [],
            now: baseDate.addingTimeInterval(35 * 86_400)
        )
        XCTAssertNil(pruned.first(where: { $0.id == deletedID }))
    }

    func testLegacyScriptJSONDecodesWithoutDeletedAtField() throws {
        let legacyJSON = """
        [
          {
            "id": "11111111-2222-3333-4444-555555555555",
            "title": "Legacy Script",
            "pages": ["Hello world"],
            "targetWPM": 150,
            "isPinned": true,
            "createdAt": "2026-01-01T00:00:00Z",
            "updatedAt": "2026-01-02T00:00:00Z"
          }
        ]
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([DanteScript].self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(decoded.count, 1)
        XCTAssertNil(decoded[0].deletedAt)
        XCTAssertFalse(decoded[0].isDeleted)
    }

    @MainActor
    func testTwoDeviceBidirectionalSynchronization() async {
        let sharedCloud = InMemoryScriptSyncTransport()
        let macSync = ScriptSyncCoordinator(transport: sharedCloud)
        let iosSync = ScriptSyncCoordinator(transport: sharedCloud)

        let macScript = DanteScript(title: "Written on Mac", pages: ["Mac intro"])
        let iosScript = DanteScript(title: "Written on iPhone", pages: ["iPhone hook"])

        let afterMacPush = await macSync.synchronize(localScripts: [macScript], enabled: true)
        XCTAssertEqual(afterMacPush.count, 1)

        let afterIOSMerge = await iosSync.synchronize(localScripts: [iosScript], enabled: true)
        XCTAssertEqual(afterIOSMerge.count, 2)
        XCTAssertTrue(afterIOSMerge.contains { $0.id == macScript.id })
        XCTAssertTrue(afterIOSMerge.contains { $0.id == iosScript.id })

        let afterMacPull = await macSync.synchronize(localScripts: afterMacPush, enabled: true)
        XCTAssertEqual(afterMacPull.count, 2)
        XCTAssertTrue(afterMacPull.contains { $0.id == iosScript.id })

        if case .idle(let syncedDate) = macSync.status {
            XCTAssertNotNil(syncedDate)
        } else {
            XCTFail("Expected idle synced status, got \(macSync.status)")
        }
    }

    @MainActor
    func testOfflineSyncFallsBackGracefullyWithoutDataLoss() async {
        let offlineCloud = InMemoryScriptSyncTransport(available: false)
        let sync = ScriptSyncCoordinator(transport: offlineCloud)
        let local = [DanteScript(title: "Local Draft", pages: ["Safe offline"])]

        let result = await sync.synchronize(localScripts: local, enabled: true)
        XCTAssertEqual(result, local)
        if case .unavailable = sync.status {
            // expected
        } else {
            XCTFail("Expected unavailable status when transport offline")
        }
    }
}
