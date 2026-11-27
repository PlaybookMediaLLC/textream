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
    private(set) var scripts: [DanteScript] = []
    var selectedScriptID: UUID
    var searchQuery: String = ""

    init(persistence: ScriptLibraryPersistence = ScriptLibraryPersistence()) {
        self.persistence = persistence
        var loaded = persistence.load()
        if loaded.isEmpty {
            let welcome = DanteScript.welcomeScript(forMac: true)
            loaded = [welcome]
            persistence.save(loaded)
        }
        self.scripts = loaded
        self.selectedScriptID = loaded[0].id
    }

    var filteredScripts: [DanteScript] {
        ScriptLibraryPersistence.filtered(scripts, query: searchQuery)
    }

    var activeScript: DanteScript? {
        scripts.first { $0.id == selectedScriptID }
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
        scripts.insert(script, at: 0)
        scripts = ScriptLibraryPersistence.sorted(scripts)
        selectedScriptID = script.id
        persistence.save(scripts)
        return script
    }

    func selectScript(_ script: DanteScript) {
        selectedScriptID = script.id
    }

    func updateActivePages(_ pages: [String]) {
        guard let idx = scripts.firstIndex(where: { $0.id == selectedScriptID }) else { return }
        let normalized = pages.isEmpty ? [""] : pages
        guard scripts[idx].pages != normalized else { return }
        scripts[idx].pages = normalized
        scripts[idx].updatedAt = Date()
        scripts = ScriptLibraryPersistence.sorted(scripts)
        persistence.save(scripts)
    }

    func updateActiveMetadata(title: String? = nil, targetWPM: Int? = nil, presetID: CreatorPresetID?? = nil) {
        guard let idx = scripts.firstIndex(where: { $0.id == selectedScriptID }) else { return }
        if let title {
            scripts[idx].title = title
        }
        if let targetWPM {
            scripts[idx].targetWPM = ScriptMetrics.clampedWPM(targetWPM)
        }
        if let presetID {
            scripts[idx].presetID = presetID
        }
        scripts[idx].updatedAt = Date()
        scripts = ScriptLibraryPersistence.sorted(scripts)
        persistence.save(scripts)
    }

    func renameScript(id: UUID, to newTitle: String) {
        guard let idx = scripts.firstIndex(where: { $0.id == id }) else { return }
        scripts[idx].title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        scripts[idx].updatedAt = Date()
        scripts = ScriptLibraryPersistence.sorted(scripts)
        persistence.save(scripts)
    }

    func togglePin(id: UUID) {
        guard let idx = scripts.firstIndex(where: { $0.id == id }) else { return }
        scripts[idx].isPinned.toggle()
        scripts = ScriptLibraryPersistence.sorted(scripts)
        persistence.save(scripts)
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
        scripts.insert(copy, at: 0)
        scripts = ScriptLibraryPersistence.sorted(scripts)
        selectedScriptID = copy.id
        persistence.save(scripts)
        return copy
    }

    func deleteScript(id: UUID) {
        guard scripts.count > 1 else { return }
        scripts.removeAll { $0.id == id }
        if selectedScriptID == id, let first = scripts.first {
            selectedScriptID = first.id
        }
        persistence.save(scripts)
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
