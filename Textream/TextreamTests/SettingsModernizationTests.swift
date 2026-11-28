//
//  SettingsModernizationTests.swift
//  TextreamTests
//
//  Unit tests for the modernized Settings navigation catalog, live search index,
//  palette tokens, color hex formatting, and comprehensive factory reset.
//

import Foundation
import SwiftUI
import XCTest
@testable import Textream

final class SettingsModernizationTests: XCTestCase {

    // MARK: - Sidebar Grouping & Tab Compatibility

    func testSidebarGroupsExhaustivelyPartitionAllSettingsTabsWithoutDuplicates() {
        let groupedTabs = SettingsSidebarGroup.allCases.flatMap(\.tabs)
        XCTAssertEqual(groupedTabs.count, SettingsTab.allCases.count)
        XCTAssertEqual(Set(groupedTabs), Set(SettingsTab.allCases))
        XCTAssertNil(SettingsSidebarGroup.core.title)
        XCTAssertEqual(SettingsSidebarGroup.voiceAndAI.title, "Voice & AI")
        XCTAssertEqual(SettingsSidebarGroup.studio.title, "Studio")
        XCTAssertEqual(SettingsSidebarGroup.integrations.title, "Integrations")
        XCTAssertEqual(SettingsSidebarGroup.system.title, "System")
    }

    func testLegacySettingsTabRawValuesAndMetadataRemainIntact() {
        let legacyTabs: [SettingsTab] = [
            .appearance, .guidance, .reading, .teleprompter, .external, .browser, .director
        ]
        for tab in legacyTabs {
            XCTAssertFalse(tab.rawValue.isEmpty)
            XCTAssertFalse(tab.label.isEmpty)
            XCTAssertFalse(tab.subtitle.isEmpty)
            XCTAssertFalse(tab.icon.isEmpty)
        }
        XCTAssertEqual(SettingsTab(rawValue: "appearance"), .appearance)
        XCTAssertEqual(SettingsTab(rawValue: "director"), .director)
        XCTAssertEqual(SettingsTab(rawValue: "browser"), .browser)
    }

    func testAllSettingsTabsHaveNonEmptyMetadataAndUniqueIDs() {
        let ids = SettingsTab.allCases.map(\.id)
        XCTAssertEqual(Set(ids).count, SettingsTab.allCases.count)

        for tab in SettingsTab.allCases {
            XCTAssertFalse(tab.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(tab.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(tab.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Live Settings Search Index

    func testSearchIndexReturnsAllItemsForBlankQuery() {
        XCTAssertEqual(SettingsSearchIndex.search("").count, SettingsSearchIndex.allItems.count)
        XCTAssertEqual(SettingsSearchIndex.search("   \n  ").count, SettingsSearchIndex.allItems.count)
        XCTAssertEqual(SettingsSearchIndex.matchingTabs(for: ""), SettingsTab.allCases)
    }

    func testSearchIndexFindsExpectedSettingsAcrossAllCategories() {
        let obsResults = SettingsSearchIndex.search("obs websocket")
        XCTAssertTrue(obsResults.contains(where: { $0.tab == .obs }))

        let dyslexiaResults = SettingsSearchIndex.search("dyslexia")
        XCTAssertTrue(dyslexiaResults.contains(where: { $0.id == "appearance.font" }))

        let mirrorResults = SettingsSearchIndex.search("beamsplitter")
        XCTAssertTrue(mirrorResults.contains(where: { $0.tab == .external }))

        let pedalResults = SettingsSearchIndex.search("foot pedal")
        XCTAssertTrue(pedalResults.contains(where: { $0.tab == .shortcuts }))

        let resetResults = SettingsSearchIndex.search("factory reset")
        XCTAssertTrue(resetResults.contains(where: { $0.id == "about.reset" }))

        let bonjourResults = SettingsSearchIndex.search("bonjour pin")
        XCTAssertTrue(bonjourResults.contains(where: { $0.tab == .director }))

        let iCloudResults = SettingsSearchIndex.search("iCloud")
        XCTAssertTrue(iCloudResults.contains(where: { $0.id == "general.icloud" }))

        let noResults = SettingsSearchIndex.search("nonexistent-xyz-token-12345")
        XCTAssertTrue(noResults.isEmpty)
        XCTAssertTrue(SettingsSearchIndex.matchingTabs(for: "nonexistent-xyz-token-12345").isEmpty)
    }

    func testSearchIndexIDsAreUniqueAndCoverEveryTab() {
        let ids = SettingsSearchIndex.allItems.map(\.id)
        XCTAssertEqual(Set(ids).count, SettingsSearchIndex.allItems.count)

        let indexedTabs = Set(SettingsSearchIndex.allItems.map(\.tab))
        XCTAssertEqual(indexedTabs, Set(SettingsTab.allCases))
    }

    // MARK: - Color Hex & Palette Tokens

    func testFontColorPresetsProvideValidHexStrings() {
        let hexPattern = /^#[0-9A-F]{6}$/
        for preset in FontColorPreset.allCases {
            XCTAssertNotNil(
                preset.hexString.wholeMatch(of: hexPattern),
                "Preset \(preset.rawValue) has invalid hex string \(preset.hexString)"
            )
        }
    }

    func testDantePaletteExposesSettingsSurfaceTokens() {
        let light = DantePalette(colorScheme: .light)
        let dark = DantePalette(colorScheme: .dark)
        XCTAssertNotEqual(light.settingsCanvasBackground, dark.settingsCanvasBackground)
        XCTAssertNotEqual(light.settingsCardBackground, dark.settingsCardBackground)
        XCTAssertNotEqual(light.settingsDivider, dark.settingsDivider)
        XCTAssertNotEqual(light.settingsSelectedSidebarBackground, dark.settingsSelectedSidebarBackground)
    }

    // MARK: - Comprehensive Factory Reset

    func testResetToDefaultsRestoresAllPreferences() {
        let settings = NotchSettings()
        // Save originals so test leaves UserDefaults tidy
        let originalAppearance = settings.appAppearance
        let originalEngine = settings.speechEngine
        let originalModel = settings.localModelFilename
        let originalOBSHost = settings.obsHost
        let originalOBSPort = settings.obsPort
        let originalOBSPassword = settings.obsPassword
        defer {
            settings.resetToDefaults()
            settings.appAppearance = originalAppearance
            settings.speechEngine = originalEngine
            settings.localModelFilename = originalModel
            settings.obsHost = originalOBSHost
            settings.obsPort = originalOBSPort
            settings.obsPassword = originalOBSPassword
        }

        settings.notchWidth = 460
        settings.textAreaHeight = 320
        settings.fontSizePreset = .xl
        settings.fontFamilyPreset = .dyslexia
        settings.fontColorPreset = .orange
        settings.cueColorPreset = .pink
        settings.cueBrightness = .bright
        settings.overlayMode = .floating
        settings.notchDisplayMode = .fixedDisplay
        settings.floatingGlassEffect = true
        settings.glassOpacity = 0.45
        settings.overlayTransparency = true
        settings.overlayTransparencyOpacity = 0.55
        settings.followCursorWhenUndocked = true
        settings.externalDisplayMode = .mirror
        settings.mirrorAxis = .both
        settings.listeningMode = .classic
        settings.speechEngine = .local
        settings.localModelFilename = "custom-model.gguf"
        settings.scrollSpeed = 6.5
        settings.showElapsedTime = false
        settings.hideFromScreenShare = false
        settings.keepScreenAwake = true
        settings.readingPosition = .nearTop
        settings.showParagraphDividers = true
        settings.showLastSpokenWords = false
        settings.selectedMicUID = "fake-mic-uid"
        settings.autoNextPage = true
        settings.autoNextPageDelay = 5
        settings.browserServerPort = 8080
        settings.directorServerPort = 8181
        settings.appAppearance = .dark
        settings.hasDismissedSetupChecklist = true
        settings.smartRetakeEnabled = false
        settings.showPacingCoach = false
        settings.iCloudSyncEnabled = false
        settings.obsHost = "192.168.1.44"
        settings.obsPort = 4466
        settings.obsPassword = "studio-test-secret"
        settings.obsAutoStartTeleprompter = false
        settings.obsAutoStopTeleprompter = false

        settings.resetToDefaults()

        XCTAssertEqual(settings.notchWidth, NotchSettings.defaultWidth)
        XCTAssertEqual(settings.textAreaHeight, NotchSettings.defaultHeight)
        XCTAssertEqual(settings.fontSizePreset, .lg)
        XCTAssertEqual(settings.fontFamilyPreset, .sans)
        XCTAssertEqual(settings.fontColorPreset, .white)
        XCTAssertEqual(settings.cueColorPreset, .white)
        XCTAssertEqual(settings.cueBrightness, .dim)
        XCTAssertEqual(settings.overlayMode, .pinned)
        XCTAssertEqual(settings.notchDisplayMode, .followMouse)
        XCTAssertFalse(settings.floatingGlassEffect)
        XCTAssertEqual(settings.glassOpacity, 0.15, accuracy: 0.001)
        XCTAssertFalse(settings.overlayTransparency)
        XCTAssertEqual(settings.overlayTransparencyOpacity, 0.85, accuracy: 0.001)
        XCTAssertFalse(settings.followCursorWhenUndocked)
        XCTAssertEqual(settings.externalDisplayMode, .off)
        XCTAssertEqual(settings.mirrorAxis, .horizontal)
        XCTAssertEqual(settings.listeningMode, .wordTracking)
        XCTAssertEqual(settings.speechEngine, .apple)
        XCTAssertEqual(settings.localModelFilename, "")
        XCTAssertEqual(settings.scrollSpeed, 3, accuracy: 0.001)
        XCTAssertTrue(settings.showElapsedTime)
        XCTAssertTrue(settings.hideFromScreenShare)
        XCTAssertFalse(settings.keepScreenAwake)
        XCTAssertEqual(settings.readingPosition, .centered)
        XCTAssertFalse(settings.showParagraphDividers)
        XCTAssertTrue(settings.showLastSpokenWords)
        XCTAssertEqual(settings.selectedMicUID, "")
        XCTAssertFalse(settings.autoNextPage)
        XCTAssertEqual(settings.autoNextPageDelay, 3)
        XCTAssertFalse(settings.browserServerEnabled)
        XCTAssertEqual(settings.browserServerPort, 7373)
        XCTAssertFalse(settings.directorModeEnabled)
        XCTAssertEqual(settings.directorServerPort, 7575)
        XCTAssertEqual(settings.appAppearance, .system)
        XCTAssertFalse(settings.hasDismissedSetupChecklist)
        XCTAssertTrue(settings.smartRetakeEnabled)
        XCTAssertTrue(settings.showPacingCoach)
        XCTAssertTrue(settings.iCloudSyncEnabled)
        XCTAssertFalse(settings.obsWebSocketEnabled)
        XCTAssertEqual(settings.obsHost, "127.0.0.1")
        XCTAssertEqual(settings.obsPort, 4455)
        XCTAssertEqual(settings.obsPassword, "")
        XCTAssertTrue(settings.obsAutoStartTeleprompter)
        XCTAssertTrue(settings.obsAutoStopTeleprompter)
    }
}
