//
//  ScriptLibraryStore.swift
//  Dante for Creators
//

import Foundation
import Observation

@Observable
@MainActor
final class ScriptLibraryStore {
    static let shared = ScriptLibraryStore()

    private let persistence: ScriptLibraryPersistence
    private let syncCoordinator: ScriptSyncCoordinator
    private var allScripts: [DanteScript] = []
    private(set) var scripts: [DanteScript] = []
    private(set) var syncStatus: ScriptSyncStatus = .idle(lastSynced: nil)
    var selectedScriptID: UUID
    var searchQuery: String = ""
    @ObservationIgnored private var syncTask: Task<Void, Never>?

    init(
        persistence: ScriptLibraryPersistence = ScriptLibraryPersistence(),
        syncCoordinator: ScriptSyncCoordinator? = nil
    ) {
        self.persistence = persistence
        let coordinator = syncCoordinator ?? ScriptSyncCoordinator.makeDefault()
        self.syncCoordinator = coordinator
        var loaded = persistence.load()
        let activeLoaded = loaded.filter { !$0.isDeleted }
        if activeLoaded.isEmpty {
            let welcome = DanteScript.welcomeScript(forMac: true)
            loaded.append(welcome)
            loaded = ScriptLibraryPersistence.sorted(loaded)
            persistence.save(loaded)
        }
        let visible = loaded.filter { !$0.isDeleted }
        self.allScripts = loaded
        self.scripts = visible
        self.selectedScriptID = visible[0].id
        TextreamService.shared.activeTargetWPM = visible[0].targetWPM
        TextreamService.shared.activeScriptTitle = visible[0].displayTitle

        coordinator.onStatusChange = { [weak self] status in
            self?.syncStatus = status
        }
    }

    var filteredScripts: [DanteScript] {
        ScriptLibraryPersistence.filtered(scripts, query: searchQuery)
    }

    var activeScript: DanteScript? {
        scripts.first { $0.id == selectedScriptID }
    }

    func syncWithCloud() async {
        let merged = await syncCoordinator.synchronize(
            localScripts: allScripts,
            enabled: NotchSettings.shared.iCloudSyncEnabled
        )
        applyMergedScripts(merged)
    }

    private func scheduleSync() {
        syncTask?.cancel()
        syncTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled, let self else { return }
            await self.syncWithCloud()
        }
    }

    private func applyMergedScripts(_ merged: [DanteScript]) {
        var nextAll = ScriptLibraryPersistence.sorted(merged)
        var visible = nextAll.filter { !$0.isDeleted }
        if visible.isEmpty {
            let welcome = DanteScript.welcomeScript(forMac: true)
            nextAll.append(welcome)
            nextAll = ScriptLibraryPersistence.sorted(nextAll)
            visible = nextAll.filter { !$0.isDeleted }
        }
        allScripts = nextAll
        scripts = visible
        if !visible.contains(where: { $0.id == selectedScriptID }), let first = visible.first {
            selectedScriptID = first.id
            TextreamService.shared.activeTargetWPM = first.targetWPM
            TextreamService.shared.activeScriptTitle = first.displayTitle
        }
        persistence.save(allScripts)
    }

    @discardableResult
    func createScript(
        title: String = "Untitled Script",
        pages: [String] = [""],
        presetID: CreatorPresetID? = nil
    ) -> DanteScript {
        let preset = presetID.map { CreatorPreset.preset(for: $0) }
        let script = DanteScript(
            title: title,
            pages: pages,
            presetID: presetID,
            targetWPM: preset?.targetWPM ?? ScriptMetrics.defaultWPM
        )
        allScripts.insert(script, at: 0)
        allScripts = ScriptLibraryPersistence.sorted(allScripts)
        scripts = allScripts.filter { !$0.isDeleted }
        selectedScriptID = script.id
        TextreamService.shared.activeTargetWPM = script.targetWPM
        TextreamService.shared.activeScriptTitle = script.displayTitle
        persistence.save(allScripts)
        scheduleSync()
        return script
    }

    func selectScript(_ script: DanteScript) {
        selectedScriptID = script.id
        TextreamService.shared.activeTargetWPM = script.targetWPM
        TextreamService.shared.activeScriptTitle = script.displayTitle
    }

    func updateActivePages(_ pages: [String]) {
        guard let idx = allScripts.firstIndex(where: { $0.id == selectedScriptID }) else { return }
        let normalized = pages.isEmpty ? [""] : pages
        guard allScripts[idx].pages != normalized else { return }
        allScripts[idx].pages = normalized
        allScripts[idx].updatedAt = Date()
        allScripts = ScriptLibraryPersistence.sorted(allScripts)
        scripts = allScripts.filter { !$0.isDeleted }
        persistence.save(allScripts)
        scheduleSync()
    }

    func updateActiveMetadata(title: String? = nil, targetWPM: Int? = nil, presetID: CreatorPresetID?? = nil) {
        guard let idx = allScripts.firstIndex(where: { $0.id == selectedScriptID }) else { return }
        if let title {
            allScripts[idx].title = title
            TextreamService.shared.activeScriptTitle = allScripts[idx].displayTitle
        }
        if let targetWPM {
            let clamped = ScriptMetrics.clampedWPM(targetWPM)
            allScripts[idx].targetWPM = clamped
            TextreamService.shared.activeTargetWPM = clamped
        }
        if let presetID {
            allScripts[idx].presetID = presetID
        }
        allScripts[idx].updatedAt = Date()
        allScripts = ScriptLibraryPersistence.sorted(allScripts)
        scripts = allScripts.filter { !$0.isDeleted }
        persistence.save(allScripts)
        scheduleSync()
    }

    func renameScript(id: UUID, to newTitle: String) {
        guard let idx = allScripts.firstIndex(where: { $0.id == id }) else { return }
        allScripts[idx].title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if id == selectedScriptID {
            TextreamService.shared.activeScriptTitle = allScripts[idx].displayTitle
        }
        allScripts[idx].updatedAt = Date()
        allScripts = ScriptLibraryPersistence.sorted(allScripts)
        scripts = allScripts.filter { !$0.isDeleted }
        persistence.save(allScripts)
        scheduleSync()
    }

    func togglePin(id: UUID) {
        guard let idx = allScripts.firstIndex(where: { $0.id == id }) else { return }
        allScripts[idx].isPinned.toggle()
        allScripts[idx].updatedAt = Date()
        allScripts = ScriptLibraryPersistence.sorted(allScripts)
        scripts = allScripts.filter { !$0.isDeleted }
        persistence.save(allScripts)
        scheduleSync()
    }

    @discardableResult
    func duplicateScript(id: UUID) -> DanteScript? {
        guard let existing = scripts.first(where: { $0.id == id }) else { return nil }
        let copy = DanteScript(
            title: "\(existing.displayTitle) Copy",
            pages: existing.pages,
            presetID: existing.presetID,
            targetWPM: existing.targetWPM,
            isPinned: false
        )
        allScripts.insert(copy, at: 0)
        allScripts = ScriptLibraryPersistence.sorted(allScripts)
        scripts = allScripts.filter { !$0.isDeleted }
        selectedScriptID = copy.id
        persistence.save(allScripts)
        scheduleSync()
        return copy
    }

    func deleteScript(id: UUID) {
        guard scripts.count > 1 else { return }
        guard let idx = allScripts.firstIndex(where: { $0.id == id }) else { return }
        let now = Date()
        allScripts[idx].deletedAt = now
        allScripts[idx].updatedAt = now
        scripts = allScripts.filter { !$0.isDeleted }
        if selectedScriptID == id, let first = scripts.first {
            selectedScriptID = first.id
            TextreamService.shared.activeTargetWPM = first.targetWPM
            TextreamService.shared.activeScriptTitle = first.displayTitle
        }
        persistence.save(allScripts)
        scheduleSync()
    }
}

extension NotchSettings {
    func apply(preset: CreatorPreset) {
        listeningMode = preset.prefersWordTracking ? .wordTracking : .classic
        scrollSpeed = preset.recommendedScrollWordsPerSecond
        fontSizePreset = preset.prefersLargeFont ? .lg : .sm
        readingPosition = preset.prefersNearCamera ? .nearTop : .centered
        showParagraphDividers = preset.prefersParagraphDividers
        hideFromScreenShare = preset.prefersHideFromScreenShare
        keepScreenAwake = preset.prefersKeepScreenAwake
        autoNextPage = preset.prefersAutoNextPage
        showElapsedTime = true
        cueBrightness = preset.prefersBrightCues ? .bright : .medium
        if preset.id == .keynoteLive {
            overlayMode = .pinned
        }
    }
}
