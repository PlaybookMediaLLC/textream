//
//  ScriptSyncEngine.swift
//  Dante for Creators
//
//  Cross-device iCloud (CloudKit private database) script synchronization engine
//  with deterministic last-write-wins merging, runtime entitlement safety for
//  unsigned/Developer ID builds, and a mockable transport for unit tests.
//

import Foundation
#if canImport(CloudKit)
import CloudKit
#endif
#if os(macOS)
import Security
#endif

enum ScriptSyncStatus: Equatable, Sendable {
    case disabled
    case idle(lastSynced: Date?)
    case syncing
    case offline
    case unavailable(String)

    var label: String {
        switch self {
        case .disabled:
            return "iCloud Off"
        case .idle(let date):
            if date != nil {
                return "Synced"
            }
            return "iCloud Ready"
        case .syncing:
            return "Syncing…"
        case .offline:
            return "Offline"
        case .unavailable:
            return "Local Only"
        }
    }

    var systemImage: String {
        switch self {
        case .disabled:    return "icloud.slash"
        case .idle:        return "icloud"
        case .syncing:     return "arrow.triangle.2.circlepath.icloud"
        case .offline:     return "icloud.slash"
        case .unavailable: return "internaldrive"
        }
    }
}

protocol ScriptSyncTransport: Sendable {
    func isAvailable() async -> Bool
    func fetchAllScripts() async throws -> [DanteScript]
    func push(scripts: [DanteScript]) async throws
}

/// Deterministic in-memory transport used by automated unit tests to simulate
/// two-device bidirectional CloudKit sync without requiring an Apple ID.
actor InMemoryScriptSyncTransport: ScriptSyncTransport {
    private var storage: [UUID: DanteScript] = [:]
    private var available: Bool

    init(initialScripts: [DanteScript] = [], available: Bool = true) {
        self.available = available
        for script in initialScripts {
            storage[script.id] = script
        }
    }

    func setAvailable(_ value: Bool) {
        available = value
    }

    func isAvailable() async -> Bool {
        available
    }

    func fetchAllScripts() async throws -> [DanteScript] {
        guard available else {
            throw NSError(domain: "DanteSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sync offline"])
        }
        return Array(storage.values)
    }

    func push(scripts: [DanteScript]) async throws {
        guard available else {
            throw NSError(domain: "DanteSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sync offline"])
        }
        let merged = DanteScript.merge(local: Array(storage.values), remote: scripts)
        storage.removeAll(keepingCapacity: true)
        for script in merged {
            storage[script.id] = script
        }
    }
}

// MARK: - CloudKit Private Database Transport

#if canImport(CloudKit)
actor CloudKitScriptSyncTransport: ScriptSyncTransport {
    static let containerIdentifier = "iCloud.com.playbookinteractivemediallc.app"
    private static let zoneID = CKRecordZone.ID(zoneName: "DanteScriptsZone", ownerName: CKCurrentUserDefaultName)
    private static let recordType = "DanteScriptRecord"

    private var cachedContainer: CKContainer?

    nonisolated static func hasCloudKitEntitlement() -> Bool {
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil || env["DANTE_DISABLE_CLOUDKIT"] == "1" {
            return false
        }
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil),
              let raw = SecTaskCopyValueForEntitlement(
                task,
                "com.apple.developer.icloud-container-identifiers" as CFString,
                nil
              ) as? [String] else {
            return false
        }
        return raw.contains(containerIdentifier)
        #elseif os(iOS)
        return FileManager.default.ubiquityIdentityToken != nil
        #else
        return false
        #endif
    }

    private func containerIfEntitled() -> CKContainer? {
        guard Self.hasCloudKitEntitlement() else { return nil }
        if let cachedContainer { return cachedContainer }
        let container = CKContainer(identifier: Self.containerIdentifier)
        cachedContainer = container
        return container
    }

    func isAvailable() async -> Bool {
        guard let container = containerIfEntitled() else { return false }
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            return false
        }
    }

    func fetchAllScripts() async throws -> [DanteScript] {
        guard let container = containerIfEntitled() else { return [] }
        let db = container.privateCloudDatabase
        try await ensureZoneExists(in: db)

        let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(value: true))
        var scripts: [DanteScript] = []
        var cursor: CKQueryOperation.Cursor?

        let firstPage = try await db.records(matching: query, inZoneWith: Self.zoneID)
        for (_, result) in firstPage.matchResults {
            if case .success(let record) = result, let parsed = Self.script(from: record) {
                scripts.append(parsed)
            }
        }
        cursor = firstPage.queryCursor

        while let activeCursor = cursor {
            let page = try await db.records(continuingMatchFrom: activeCursor)
            for (_, result) in page.matchResults {
                if case .success(let record) = result, let parsed = Self.script(from: record) {
                    scripts.append(parsed)
                }
            }
            cursor = page.queryCursor
        }
        return scripts
    }

    func push(scripts: [DanteScript]) async throws {
        guard let container = containerIfEntitled(), !scripts.isEmpty else { return }
        let db = container.privateCloudDatabase
        try await ensureZoneExists(in: db)

        let records = scripts.map(Self.record(from:))
        _ = try await db.modifyRecords(saving: records, deleting: [], savePolicy: .allKeys)
    }

    private func ensureZoneExists(in db: CKDatabase) async throws {
        let zone = CKRecordZone(zoneID: Self.zoneID)
        _ = try await db.modifyRecordZones(saving: [zone], deleting: [])
    }

    private nonisolated static func record(from script: DanteScript) -> CKRecord {
        let recordID = CKRecord.ID(recordName: script.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record["title"] = script.title as CKRecordValue
        if let pagesData = try? JSONEncoder().encode(script.pages),
           let pagesJSON = String(data: pagesData, encoding: .utf8) {
            record["pagesJSON"] = pagesJSON as CKRecordValue
        }
        record["presetID"] = script.presetID?.rawValue as CKRecordValue?
        record["targetWPM"] = NSNumber(value: script.targetWPM)
        record["isPinned"] = NSNumber(value: script.isPinned ? 1 : 0)
        record["createdAt"] = script.createdAt as CKRecordValue
        record["updatedAt"] = script.updatedAt as CKRecordValue
        record["deletedAt"] = script.deletedAt as CKRecordValue?
        return record
    }

    private nonisolated static func script(from record: CKRecord) -> DanteScript? {
        guard let id = UUID(uuidString: record.recordID.recordName) else { return nil }
        let title = record["title"] as? String ?? ""
        let pages: [String]
        if let pagesJSON = record["pagesJSON"] as? String,
           let data = pagesJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data),
           !decoded.isEmpty {
            pages = decoded
        } else {
            pages = [""]
        }
        let presetID = (record["presetID"] as? String).flatMap(CreatorPresetID.init(rawValue:))
        let targetWPM = (record["targetWPM"] as? NSNumber)?.intValue ?? ScriptMetrics.defaultWPM
        let isPinned = ((record["isPinned"] as? NSNumber)?.intValue ?? 0) != 0
        let createdAt = record["createdAt"] as? Date ?? Date()
        let updatedAt = record["updatedAt"] as? Date ?? createdAt
        let deletedAt = record["deletedAt"] as? Date
        return DanteScript(
            id: id,
            title: title,
            pages: pages,
            presetID: presetID,
            targetWPM: targetWPM,
            isPinned: isPinned,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
    }
}
#endif

// MARK: - Sync Coordinator

@MainActor
final class ScriptSyncCoordinator {
    private let transport: any ScriptSyncTransport
    private(set) var status: ScriptSyncStatus = .idle(lastSynced: nil)
    var onStatusChange: ((ScriptSyncStatus) -> Void)?

    init(transport: any ScriptSyncTransport) {
        self.transport = transport
    }

    static func makeDefault() -> ScriptSyncCoordinator {
        #if canImport(CloudKit)
        return ScriptSyncCoordinator(transport: CloudKitScriptSyncTransport())
        #else
        return ScriptSyncCoordinator(transport: InMemoryScriptSyncTransport(available: false))
        #endif
    }

    func setEnabled(_ enabled: Bool) {
        if !enabled {
            updateStatus(.disabled)
        } else if case .disabled = status {
            updateStatus(.idle(lastSynced: nil))
        }
    }

    /// Pulls remote scripts, merges with `localScripts` using deterministic LWW,
    /// pushes any local updates back to CloudKit, and returns the merged snapshot.
    func synchronize(localScripts: [DanteScript], enabled: Bool) async -> [DanteScript] {
        guard enabled else {
            updateStatus(.disabled)
            return localScripts
        }
        guard await transport.isAvailable() else {
            updateStatus(.unavailable("Sign in to iCloud to sync scripts across Mac, iPhone, and iPad."))
            return localScripts
        }
        updateStatus(.syncing)
        do {
            let remoteScripts = try await transport.fetchAllScripts()
            let merged = DanteScript.merge(local: localScripts, remote: remoteScripts)
            if merged != remoteScripts {
                try await transport.push(scripts: merged)
            }
            updateStatus(.idle(lastSynced: Date()))
            return merged
        } catch {
            updateStatus(.offline)
            return localScripts
        }
    }

    private func updateStatus(_ next: ScriptSyncStatus) {
        status = next
        onStatusChange?(next)
    }
}
