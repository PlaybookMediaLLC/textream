import Foundation
import Observation
import Speech

@Observable
@MainActor
final class AppModel {
    private enum Key {
        static let script = "ios.script"
        static let scriptLibrary = "ios.scriptLibrary"
        static let selectedScriptID = "ios.selectedScriptID"
        static let hasCompletedOnboarding = "ios.hasCompletedOnboarding"
        static let sessionMode = "ios.sessionMode"
        static let cameraEnabled = "ios.cameraEnabled"
        static let followMode = "ios.followMode"
        static let mirrorEnabled = "ios.mirrorEnabled"
        static let mirrorAxis = "ios.mirrorAxis"
        static let readingPosition = "ios.readingPosition"
        static let scrollSpeed = "ios.scrollSpeed"
        static let fontFamily = "ios.fontFamily"
        static let fontSize = "ios.fontSize"
        static let textColor = "ios.textColor"
        static let cueColor = "ios.cueColor"
        static let cueBrightness = "ios.cueBrightness"
        static let overlayOpacity = "ios.overlayOpacity"
        static let speechLocale = "ios.speechLocale"
        static let appAppearance = "ios.appAppearance"
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let filePersistence: ScriptLibraryPersistence?
    @ObservationIgnored private var isSynchronizingLibrary = false

    private(set) var scripts: [DanteScript]
    var selectedScriptID: UUID

    var script: String {
        didSet {
            defaults.set(script, forKey: Key.script)
            if !isSynchronizingLibrary {
                syncScriptTextToActiveLibraryEntry(script)
            }
        }
    }
    var sessionMode: SessionMode { didSet { defaults.set(sessionMode.rawValue, forKey: Key.sessionMode) } }
    var cameraEnabled: Bool { didSet { defaults.set(cameraEnabled, forKey: Key.cameraEnabled) } }
    var followMode: FollowMode { didSet { defaults.set(followMode.rawValue, forKey: Key.followMode) } }
    var mirrorEnabled: Bool { didSet { defaults.set(mirrorEnabled, forKey: Key.mirrorEnabled) } }
    var mirrorAxis: PromptMirrorAxis { didSet { defaults.set(mirrorAxis.rawValue, forKey: Key.mirrorAxis) } }
    var readingPosition: PromptReadingPosition {
        didSet { defaults.set(readingPosition.rawValue, forKey: Key.readingPosition) }
    }
    var scrollSpeed: Double { didSet { defaults.set(scrollSpeed, forKey: Key.scrollSpeed) } }
    var fontFamily: PromptFontFamily { didSet { defaults.set(fontFamily.rawValue, forKey: Key.fontFamily) } }
    var fontSize: PromptFontSize { didSet { defaults.set(fontSize.rawValue, forKey: Key.fontSize) } }
    var textColor: PromptColorPreset { didSet { defaults.set(textColor.rawValue, forKey: Key.textColor) } }
    var cueColor: PromptColorPreset { didSet { defaults.set(cueColor.rawValue, forKey: Key.cueColor) } }
    var cueBrightness: CueBrightness { didSet { defaults.set(cueBrightness.rawValue, forKey: Key.cueBrightness) } }
    var overlayOpacity: Double { didSet { defaults.set(overlayOpacity, forKey: Key.overlayOpacity) } }
    var speechLocaleIdentifier: String { didSet { defaults.set(speechLocaleIdentifier, forKey: Key.speechLocale) } }
    var appAppearance: AppAppearance {
        didSet { defaults.set(appAppearance.rawValue, forKey: Key.appAppearance) }
    }
    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }
    var isShowingSession = false
    var isShowingSettings = false
    var isShowingLibrary = false
    var isShowingOnboarding = false
    var isShowingQuickComposer = false

    init(
        defaults: UserDefaults = .standard,
        filePersistence: ScriptLibraryPersistence? = nil
    ) {
        self.defaults = defaults
        let resolvedPersistence: ScriptLibraryPersistence? =
            filePersistence ?? (defaults === UserDefaults.standard ? ScriptLibraryPersistence() : nil)
        self.filePersistence = resolvedPersistence

        let loadedScripts = Self.loadInitialScripts(
            defaults: defaults,
            filePersistence: resolvedPersistence
        )
        self.scripts = loadedScripts

        let savedSelection = defaults.string(forKey: Key.selectedScriptID).flatMap(UUID.init(uuidString:))
        let initialSelected = loadedScripts.first(where: { $0.id == savedSelection }) ?? loadedScripts[0]
        self.selectedScriptID = initialSelected.id

        if let explicitSavedScript = defaults.string(forKey: Key.script) {
            script = explicitSavedScript
        } else {
            script = initialSelected.pages.first ?? Self.sampleScript
        }

        let restoredSessionMode = SessionMode(
            rawValue: defaults.string(forKey: Key.sessionMode) ?? ""
        ) ?? .read
        sessionMode = restoredSessionMode
        cameraEnabled = restoredSessionMode == .record
            || (defaults.object(forKey: Key.cameraEnabled) as? Bool ?? false)
        followMode = FollowMode(rawValue: defaults.string(forKey: Key.followMode) ?? "") ?? .wordTracking
        mirrorEnabled = defaults.object(forKey: Key.mirrorEnabled) as? Bool ?? false
        mirrorAxis = PromptMirrorAxis(
            rawValue: defaults.string(forKey: Key.mirrorAxis) ?? ""
        ) ?? .horizontal
        readingPosition = PromptReadingPosition(
            rawValue: defaults.string(forKey: Key.readingPosition) ?? ""
        ) ?? .nearCamera
        let savedSpeed = defaults.double(forKey: Key.scrollSpeed)
        scrollSpeed = savedSpeed > 0 ? savedSpeed : 3
        fontFamily = PromptFontFamily(rawValue: defaults.string(forKey: Key.fontFamily) ?? "") ?? .sans
        fontSize = PromptFontSize(rawValue: defaults.string(forKey: Key.fontSize) ?? "") ?? .lg
        textColor = PromptColorPreset(rawValue: defaults.string(forKey: Key.textColor) ?? "") ?? .white
        cueColor = PromptColorPreset(rawValue: defaults.string(forKey: Key.cueColor) ?? "") ?? .white
        cueBrightness = CueBrightness(rawValue: defaults.string(forKey: Key.cueBrightness) ?? "") ?? .dim
        let savedOpacity = defaults.double(forKey: Key.overlayOpacity)
        overlayOpacity = savedOpacity > 0 ? savedOpacity : 0.52
        appAppearance = AppAppearance(rawValue: defaults.string(forKey: Key.appAppearance) ?? "") ?? .system
        hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
        if let savedLocale = defaults.string(forKey: Key.speechLocale), !savedLocale.isEmpty {
            speechLocaleIdentifier = savedLocale
        } else {
            // Asking Speech for every supported locale can synchronously load
            // linguistic assets. Keep cold launch lightweight; Settings loads
            // the full list only when the user opens it.
            // en-US is guaranteed by Speech on supported iOS devices and is a
            // valid Picker tag until Settings lazily resolves a closer locale.
            speechLocaleIdentifier = "en-US"
            defaults.set(speechLocaleIdentifier, forKey: Key.speechLocale)
        }
    }

    var normalizedScript: PromptScript { PromptScript(script) }
    var canStart: Bool { !normalizedScript.text.isEmpty }

    var activeScript: DanteScript? {
        scripts.first { $0.id == selectedScriptID }
    }

    var activeTargetWPM: Int {
        activeScript?.targetWPM ?? ScriptMetrics.defaultWPM
    }

    var activePreset: CreatorPreset? {
        activeScript?.presetID.map { CreatorPreset.preset(for: $0) }
    }

    var scriptMetrics: ScriptMetrics {
        ScriptMetrics.measure(text: script, wordsPerMinute: activeTargetWPM)
    }

    func startSession() {
        guard canStart else { return }
        isShowingSession = true
    }

    func markOnboardingCompleted() {
        hasCompletedOnboarding = true
    }

    func apply(preset: CreatorPreset) {
        sessionMode = preset.prefersRecordModeOnIOS ? .record : .read
        if sessionMode == .record {
            cameraEnabled = true
        }
        followMode = preset.prefersWordTracking ? .wordTracking : .classic
        readingPosition = preset.prefersNearCamera ? .nearCamera : .center
        fontSize = preset.prefersLargeFont ? .lg : .sm
        cueBrightness = preset.prefersBrightCues ? .bright : .medium
        scrollSpeed = preset.recommendedScrollWordsPerSecond

        if let idx = scripts.firstIndex(where: { $0.id == selectedScriptID }) {
            scripts[idx].presetID = preset.id
            scripts[idx].targetWPM = preset.targetWPM
            scripts[idx].updatedAt = Date()
            persistLibrary()
        }
    }

    // MARK: - Creator Script Library

    @discardableResult
    func createNewScript(title: String = "Untitled Script", text: String = "") -> DanteScript {
        let newEntry = DanteScript(
            title: title,
            pages: [text],
            presetID: activePreset?.id,
            targetWPM: activeTargetWPM
        )
        scripts.insert(newEntry, at: 0)
        scripts = ScriptLibraryPersistence.sorted(scripts)
        selectScript(newEntry)
        persistLibrary()
        return newEntry
    }

    @discardableResult
    func createScriptFromTemplate(_ preset: CreatorPreset) -> DanteScript {
        let combinedText = preset.starterPages.joined(separator: "\n\n")
        let newEntry = DanteScript(
            title: "\(preset.name) Script",
            pages: [combinedText],
            presetID: preset.id,
            targetWPM: preset.targetWPM
        )
        scripts.insert(newEntry, at: 0)
        scripts = ScriptLibraryPersistence.sorted(scripts)
        selectScript(newEntry)
        apply(preset: preset)
        persistLibrary()
        return newEntry
    }

    func selectScript(_ entry: DanteScript) {
        selectedScriptID = entry.id
        defaults.set(entry.id.uuidString, forKey: Key.selectedScriptID)
        isSynchronizingLibrary = true
        script = entry.pages.first ?? ""
        isSynchronizingLibrary = false
    }

    func renameScript(scriptID: UUID, to newTitle: String) {
        guard let idx = scripts.firstIndex(where: { $0.id == scriptID }) else { return }
        scripts[idx].title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        scripts[idx].updatedAt = Date()
        scripts = ScriptLibraryPersistence.sorted(scripts)
        persistLibrary()
    }

    func togglePin(scriptID: UUID) {
        guard let idx = scripts.firstIndex(where: { $0.id == scriptID }) else { return }
        scripts[idx].isPinned.toggle()
        scripts = ScriptLibraryPersistence.sorted(scripts)
        persistLibrary()
    }

    @discardableResult
    func duplicateScript(scriptID: UUID) -> DanteScript? {
        guard let existing = scripts.first(where: { $0.id == scriptID }) else { return nil }
        let copy = DanteScript(
            title: "\(existing.displayTitle) Copy",
            pages: existing.pages,
            presetID: existing.presetID,
            targetWPM: existing.targetWPM,
            isPinned: false
        )
        scripts.insert(copy, at: 0)
        scripts = ScriptLibraryPersistence.sorted(scripts)
        selectScript(copy)
        persistLibrary()
        return copy
    }

    func deleteScript(scriptID: UUID) {
        guard scripts.count > 1 else { return }
        scripts.removeAll { $0.id == scriptID }
        if selectedScriptID == scriptID, let first = scripts.first {
            selectScript(first)
        }
        persistLibrary()
    }

    func setActiveTargetWPM(_ wpm: Int) {
        guard let idx = scripts.firstIndex(where: { $0.id == selectedScriptID }) else { return }
        scripts[idx].targetWPM = ScriptMetrics.clampedWPM(wpm)
        scripts[idx].updatedAt = Date()
        persistLibrary()
    }

    private func syncScriptTextToActiveLibraryEntry(_ newText: String) {
        guard let idx = scripts.firstIndex(where: { $0.id == selectedScriptID }) else { return }
        guard scripts[idx].pages.first != newText else { return }
        scripts[idx].pages = [newText]
        scripts[idx].updatedAt = Date()
        scripts = ScriptLibraryPersistence.sorted(scripts)
        persistLibrary()
    }

    private func persistLibrary() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let encoded = try? encoder.encode(scripts) {
            defaults.set(encoded, forKey: Key.scriptLibrary)
        }
        defaults.set(selectedScriptID.uuidString, forKey: Key.selectedScriptID)
        filePersistence?.save(scripts)
    }

    private static func loadInitialScripts(
        defaults: UserDefaults,
        filePersistence: ScriptLibraryPersistence?
    ) -> [DanteScript] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = defaults.data(forKey: Key.scriptLibrary),
           let decoded = try? decoder.decode([DanteScript].self, from: data),
           !decoded.isEmpty {
            return ScriptLibraryPersistence.sorted(decoded)
        }

        if let fileLoaded = filePersistence?.load(), !fileLoaded.isEmpty {
            return fileLoaded
        }

        if let existingSingleScript = defaults.string(forKey: Key.script) {
            return [
                DanteScript(
                    title: "My Script",
                    pages: [existingSingleScript],
                    presetID: .shortsReels,
                    targetWPM: ScriptMetrics.defaultWPM
                )
            ]
        }

        return [DanteScript.welcomeScript(forMac: false)]
    }

    func configuration() -> PromptSessionConfiguration {
        PromptSessionConfiguration(
            script: script,
            sessionMode: sessionMode,
            cameraEnabled: cameraEnabled,
            followMode: followMode,
            mirrorEnabled: mirrorEnabled,
            mirrorAxis: mirrorAxis,
            readingPosition: readingPosition,
            scrollSpeed: scrollSpeed,
            fontFamily: fontFamily,
            fontSize: fontSize,
            textColor: textColor,
            cueColor: cueColor,
            cueBrightness: cueBrightness,
            overlayOpacity: overlayOpacity,
            speechLocaleIdentifier: speechLocaleIdentifier
        )
    }

    private static let sampleScript = DanteScript.welcomeScript(forMac: false).pages[0]
}
