//
//  SettingsModernizationTests.swift
//  TextreamTests
//
//  Unit tests for the modernized Settings navigation catalog, live search index,
//  network validation, palette tokens, color hex formatting, and isolated
//  factory reset behavior.
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
        let presetResults = SettingsSearchIndex.search("creator format")
        XCTAssertTrue(presetResults.contains(where: { $0.id == "general.preset" }))

        let obsResults = SettingsSearchIndex.search("OBS WebSocket")
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

    // MARK: - Network Port & Host Validation

    func testNetworkValidatorChecksPortsCollisionsAndOBSHosts() {
        XCTAssertEqual(SettingsNetworkValidator.parseLANPort("7373"), 7373)
        XCTAssertEqual(SettingsNetworkValidator.parseLANPort("1024"), 1024)
        XCTAssertEqual(SettingsNetworkValidator.parseLANPort("65534"), 65534)
        XCTAssertNil(SettingsNetworkValidator.parseLANPort("1023"))
        XCTAssertNil(SettingsNetworkValidator.parseLANPort("65535"))
        XCTAssertNil(SettingsNetworkValidator.parseLANPort(""))
        XCTAssertNil(SettingsNetworkValidator.parseLANPort("abc"))

        XCTAssertEqual(SettingsNetworkValidator.parseOBSPort("1"), 1)
        XCTAssertEqual(SettingsNetworkValidator.parseOBSPort("4455"), 4455)
        XCTAssertEqual(SettingsNetworkValidator.parseOBSPort("65535"), 65535)
        XCTAssertNil(SettingsNetworkValidator.parseOBSPort("0"))
        XCTAssertNil(SettingsNetworkValidator.parseOBSPort("65536"))

        XCTAssertTrue(SettingsNetworkValidator.lanPortsCollide(7373, 7373))
        XCTAssertTrue(SettingsNetworkValidator.lanPortsCollide(7373, 7374))
        XCTAssertTrue(SettingsNetworkValidator.lanPortsCollide(7374, 7373))
        XCTAssertFalse(SettingsNetworkValidator.lanPortsCollide(7373, 7375))

        XCTAssertEqual(SettingsNetworkValidator.sanitizeOBSHost("  127.0.0.1 "), "127.0.0.1")
        XCTAssertEqual(SettingsNetworkValidator.sanitizeOBSHost("   "), "127.0.0.1")
        XCTAssertEqual(SettingsNetworkValidator.sanitizeOBSHost("studio-mac.local"), "studio-mac.local")
        XCTAssertNil(SettingsNetworkValidator.sanitizeOBSHost("ws://127.0.0.1"))
        XCTAssertNil(SettingsNetworkValidator.sanitizeOBSHost("127.0.0.1/path"))
        XCTAssertNil(SettingsNetworkValidator.sanitizeOBSHost("bad host"))

        XCTAssertTrue(SettingsNetworkValidator.isLoopbackHost("127.0.0.1"))
        XCTAssertTrue(SettingsNetworkValidator.isLoopbackHost("localhost"))
        XCTAssertTrue(SettingsNetworkValidator.isLoopbackHost("::1"))
        XCTAssertFalse(SettingsNetworkValidator.isLoopbackHost("192.168.1.40"))
    }

    // MARK: - Color Hex & Palette Tokens

    func testFontColorPresetsProvideValidHexStrings() {
        let hexPattern = #/^#[0-9A-F]{6}$/#
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

    // MARK: - Isolated Comprehensive Factory Reset & Port Persistence

    func testResetToDefaultsRestoresAllPreferencesInIsolatedSuite() throws {
        let suiteName = "com.dante.tests.settings.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = NotchSettings(defaults: defaults, notifyServices: false)

        settings.notchWidth = 460
        settings.textAreaHeight = 320
        settings.speechLocale = "fr-FR"
        settings.fontSizePreset = .xl
        settings.fontFamilyPreset = .dyslexia
        settings.fontColorPreset = .orange
        settings.cueColorPreset = .pink
        settings.cueBrightness = .bright
        settings.overlayMode = .floating
        settings.notchDisplayMode = .fixedDisplay
        settings.pinnedScreenID = 42
        settings.floatingGlassEffect = true
        settings.glassOpacity = 0.45
        settings.overlayTransparency = true
        settings.overlayTransparencyOpacity = 0.55
        settings.followCursorWhenUndocked = true
        settings.fullscreenScreenID = 99
        settings.externalDisplayMode = .mirror
        settings.externalScreenID = 77
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
        settings.browserServerEnabled = true
        settings.browserServerPort = 8080
        settings.directorModeEnabled = true
        settings.directorServerPort = 8181
        settings.appAppearance = .dark
        settings.hasDismissedSetupChecklist = true
        settings.hasCompletedFirstSession = true
        settings.smartRetakeEnabled = false
        settings.showPacingCoach = false
        settings.iCloudSyncEnabled = false
        settings.obsWebSocketEnabled = true
        settings.obsHost = "192.168.1.44"
        settings.obsPort = 65535
        settings.obsPassword = "studio-test-secret"
        settings.obsAutoStartTeleprompter = false
        settings.obsAutoStopTeleprompter = false

        // Verify max OBS port 65535 round-trips across reload before reset
        let reloadedBeforeReset = NotchSettings(defaults: defaults, notifyServices: false)
        XCTAssertEqual(reloadedBeforeReset.obsPort, 65535)

        settings.resetToDefaults()

        XCTAssertEqual(settings.notchWidth, NotchSettings.defaultWidth)
        XCTAssertEqual(settings.textAreaHeight, NotchSettings.defaultHeight)
        XCTAssertEqual(settings.speechLocale, NotchSettings.defaultLocale)
        XCTAssertEqual(settings.fontSizePreset, .lg)
        XCTAssertEqual(settings.fontFamilyPreset, .sans)
        XCTAssertEqual(settings.fontColorPreset, .white)
        XCTAssertEqual(settings.cueColorPreset, .white)
        XCTAssertEqual(settings.cueBrightness, .dim)
        XCTAssertEqual(settings.overlayMode, .pinned)
        XCTAssertEqual(settings.notchDisplayMode, .followMouse)
        XCTAssertEqual(settings.pinnedScreenID, 0)
        XCTAssertFalse(settings.floatingGlassEffect)
        XCTAssertEqual(settings.glassOpacity, 0.15, accuracy: 0.001)
        XCTAssertFalse(settings.overlayTransparency)
        XCTAssertEqual(settings.overlayTransparencyOpacity, 0.85, accuracy: 0.001)
        XCTAssertFalse(settings.followCursorWhenUndocked)
        XCTAssertEqual(settings.fullscreenScreenID, 0)
        XCTAssertEqual(settings.externalDisplayMode, .off)
        XCTAssertEqual(settings.externalScreenID, 0)
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
        XCTAssertTrue(settings.hasCompletedFirstSession, "Lifetime session milestone should be preserved")
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
