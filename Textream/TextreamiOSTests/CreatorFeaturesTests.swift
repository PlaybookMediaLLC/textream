import Foundation
import Testing
@testable import TextreamiOS

struct CreatorFeaturesTests {
    @Test
    func scriptMetricsExcludesStageDirectionsAndEstimatesDuration() {
        let script = "[smile] Welcome to Dante for Creators. [pause] " + Array(repeating: "word", count: 145).joined(separator: " ")
        let metrics = ScriptMetrics.measure(text: script, wordsPerMinute: 150)

        #expect(metrics.spokenWordCount == 150)
        #expect(metrics.estimatedSeconds == 60)
        #expect(metrics.formattedDuration == "1:00")
        #expect(metrics.summaryLabel == "150 words · ~1:00")
    }

    @Test
    func scriptMetricsFormatsShortAndLongDurations() {
        #expect(ScriptMetrics.formattedDuration(seconds: 0) == "0:00")
        #expect(ScriptMetrics.formattedDuration(seconds: 57) == "0:57")
        #expect(ScriptMetrics.formattedDuration(seconds: 3665) == "1:01:05")
    }

    @Test
    func scriptLibraryPersistenceRoundTripsAndSortsPinnedFirst() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DanteLibraryTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let persistence = ScriptLibraryPersistence(fileURL: tempDir.appendingPathComponent("scripts.json"))

        let olderPinned = DanteScript(
            title: "Pinned Intro",
            pages: ["Intro text"],
            presetID: .youtubeStudio,
            targetWPM: 150,
            isPinned: true,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let newerUnpinned = DanteScript(
            title: "Latest Reel",
            pages: ["Short reel script"],
            presetID: .shortsReels,
            targetWPM: 165,
            isPinned: false,
            createdAt: Date(timeIntervalSince1970: 200),
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        #expect(persistence.save([newerUnpinned, olderPinned]))
        let loaded = persistence.load()
        #expect(loaded.count == 2)
        #expect(loaded[0].title == "Pinned Intro")
        #expect(loaded[1].title == "Latest Reel")

        let filtered = ScriptLibraryPersistence.filtered(loaded, query: "reel")
        #expect(filtered.count == 1)
        #expect(filtered[0].title == "Latest Reel")
    }

    @MainActor
    @Test
    func appModelAppliesCreatorPresetsAndManagesScripts() {
        let suiteName = "CreatorFeaturesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let model = AppModel(defaults: defaults)
        #expect(model.scripts.count == 1)

        model.apply(preset: CreatorPreset.preset(for: .shortsReels))
        #expect(model.sessionMode == .record)
        #expect(model.cameraEnabled)
        #expect(model.followMode == .wordTracking)
        #expect(model.readingPosition == .nearCamera)
        #expect(model.activeTargetWPM == 165)
        #expect(model.activePreset?.id == .shortsReels)

        let second = model.createNewScript(title: "Podcast Episode 12", text: "Hello listeners")
        #expect(model.scripts.count == 2)
        #expect(model.selectedScriptID == second.id)
        #expect(model.script == "Hello listeners")

        model.apply(preset: CreatorPreset.preset(for: .podcastInterview))
        #expect(model.sessionMode == .read)
        #expect(model.activeTargetWPM == 140)

        model.deleteScript(scriptID: second.id)
        #expect(model.scripts.count == 1)
    }

    @Test
    func openSourceLicenseCatalogIncludesRequiredMITAndOpenDyslexicAttributions() {
        let entries = OpenSourceLicenseCatalog.entries(includeLocalSpeechModels: false)
        #expect(entries.count == 2)
        #expect(entries[0].id == "textream")
        #expect(entries[0].fullText.contains("Copyright (c) 2026 Fatih Kadir Akin"))
        #expect(entries[0].fullText.contains("MIT License"))
        #expect(entries[1].id == "opendyslexic")
        #expect(entries[1].licenseType.contains("SIL Open Font License"))
    }
}
