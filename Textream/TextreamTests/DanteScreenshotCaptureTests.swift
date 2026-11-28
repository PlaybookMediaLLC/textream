//
//  DanteScreenshotCaptureTests.swift
//  TextreamTests
//
//  Opt-in macOS UI screenshot renderer for visual QA (runs only when
//  DANTE_CAPTURE_SCREENSHOTS=1 is set in the environment).
//

import AppKit
import Foundation
import SwiftUI
import XCTest
@testable import Textream

@MainActor
final class DanteScreenshotCaptureTests: XCTestCase {

    func testCaptureMacOSStudioScreenshots() throws {
        let env = ProcessInfo.processInfo.environment
        let shouldCapture = env["DANTE_CAPTURE_SCREENSHOTS"] ?? env["TEST_RUNNER_DANTE_CAPTURE_SCREENSHOTS"]
        guard shouldCapture == "1" else { return }

        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dante-screenshots", isDirectory: true)
        try? FileManager.default.removeItem(at: outputDir)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        print("DANTE_SCREENSHOT_DIR_OUT=\(outputDir.path)")

        seedDemoWorkspace()

        let captures: [(filename: String, appearance: AppAppearance, scheme: ColorScheme, view: StudioWorkspaceView, composer: Bool)] = [
            ("macos-dark-library.png", .dark, .dark, .library, false),
            ("macos-dark-composer.png", .dark, .dark, .library, true),
            ("macos-dark-editor.png", .dark, .dark, .editor, false),
            ("macos-light-library.png", .light, .light, .library, false),
            ("macos-light-composer.png", .light, .light, .library, true),
            ("macos-light-editor.png", .light, .light, .editor, false)
        ]

        for item in captures {
            NotchSettings.shared.appAppearance = item.appearance
            item.appearance.applyToApplication()

            let rootView = ContentView(
                initialWorkspaceView: item.view,
                initialShowQuickComposer: item.composer
            )
            .preferredColorScheme(item.scheme)
            .frame(width: 1180, height: 740)

            let pngData = try renderPNG(
                view: rootView,
                size: NSSize(width: 1180, height: 740),
                appearanceName: item.scheme == .dark ? .darkAqua : .aqua
            )
            let dest = outputDir.appendingPathComponent(item.filename)
            try pngData.write(to: dest)
            XCTAssertGreaterThan(pngData.count, 10_000, "Screenshot \(item.filename) unexpectedly small")
        }

        try captureOverlayScreenshots(outputDir: outputDir)
    }

    private func captureOverlayScreenshots(outputDir: URL) throws {
        let settings = NotchSettings.shared
        settings.listeningMode = .wordTracking
        settings.showElapsedTime = true
        settings.showLastSpokenWords = true
        settings.showParagraphDividers = true
        settings.overlayTransparency = false
        settings.floatingGlassEffect = false
        settings.fontFamilyPreset = .sans
        settings.fontSizePreset = .lg
        settings.fontColorPreset = .white
        settings.cueColorPreset = .white
        settings.notchWidth = 420
        settings.textAreaHeight = 190

        let scriptText = """
        [hook — eye contact]
        Here is the exact desk setup I use every week to film crisp 4K studio videos in a single take.

        [slow down]
        When your script sits right underneath the camera lens, you never have to look away or lose your rhythm. Every sentence lands naturally.
        """

        let content = OverlayContent()
        let words = splitTextIntoWords(scriptText)
        content.words = words
        content.paragraphBreakBeforeWordIndices = paragraphBreakWordIndices(in: scriptText)
        content.totalCharCount = words.joined(separator: " ").count
        content.pageCount = 3
        content.currentPageIndex = 0
        content.hasNextPage = true
        content.pagePreviews = [
            "Hook — eye contact & desk setup",
            "Lighting chain & camera angle",
            "Outro call-to-action"
        ]

        let recognizer = SpeechRecognizer()
        recognizer.isListening = true
        recognizer.recognizedCharCount = words.prefix(15).reduce(0) { $0 + $1.count + 1 }
        recognizer.lastSpokenText = "studio videos in a single take"
        recognizer.audioLevels = [
            0.18, 0.34, 0.52, 0.78, 0.61, 0.44, 0.85, 0.92, 0.56, 0.38,
            0.70, 0.88, 0.64, 0.49, 0.74, 0.58, 0.42, 0.30, 0.62, 0.48,
            0.35, 0.25, 0.44, 0.55, 0.32, 0.24, 0.38, 0.28, 0.20, 0.16
        ]

        let tracker = NotchFrameTracker()
        tracker.menuBarHeight = 37
        tracker.visibleWidth = settings.notchWidth
        tracker.visibleHeight = 37 + settings.textAreaHeight

        let overlayCaptures: [(filename: String, appearance: AppAppearance, scheme: ColorScheme, mode: OverlayMode)] = [
            ("macos-notch-snapped-dark.png", .dark, .dark, .pinned),
            ("macos-notch-snapped-light.png", .light, .light, .pinned),
            ("macos-floating-dark.png", .dark, .dark, .floating),
            ("macos-floating-light.png", .light, .light, .floating)
        ]

        for item in overlayCaptures {
            settings.appAppearance = item.appearance
            settings.overlayMode = item.mode
            item.appearance.applyToApplication()

            let stageView = makeOverlayStageView(
                mode: item.mode,
                scheme: item.scheme,
                content: content,
                recognizer: recognizer,
                tracker: tracker
            )
            .preferredColorScheme(item.scheme)
            .frame(width: 1180, height: 740)

            let pngData = try renderPNG(
                view: stageView,
                size: NSSize(width: 1180, height: 740),
                appearanceName: item.scheme == .dark ? .darkAqua : .aqua
            )
            let dest = outputDir.appendingPathComponent(item.filename)
            try pngData.write(to: dest)
            XCTAssertGreaterThan(pngData.count, 10_000, "Screenshot \(item.filename) unexpectedly small")
        }

        try captureProStudioFeatureScreenshots(outputDir: outputDir)
    }

    private func captureProStudioFeatureScreenshots(outputDir: URL) throws {
        let settings = NotchSettings.shared
        settings.directorModeEnabled = true
        settings.obsWebSocketEnabled = true
        settings.obsHost = "127.0.0.1"
        settings.obsPort = 4455
        settings.obsAutoStartTeleprompter = true
        settings.obsAutoStopTeleprompter = true
        settings.smartRetakeEnabled = true
        settings.showPacingCoach = true
        settings.iCloudSyncEnabled = true
        if !TextreamService.shared.directorServer.isRunning {
            TextreamService.shared.directorServer.start()
        }

        defer {
            TextreamService.shared.directorServer.stop()
            settings.resetToDefaults()
        }

        let sampleRecord = TakeTranscriptRecord(
            id: UUID(),
            scriptTitle: "How I Shoot 4K Studio Videos in One Take",
            createdAt: Date(),
            durationSeconds: 84,
            targetWPM: 150,
            wordTimings: [
                WordTimingSample(wordIndex: 0, text: "Here", startSeconds: 0.4, endSeconds: 0.8, passIndex: 1),
                WordTimingSample(wordIndex: 1, text: "is", startSeconds: 0.8, endSeconds: 1.0, passIndex: 1),
                WordTimingSample(wordIndex: 2, text: "the", startSeconds: 1.0, endSeconds: 1.2, passIndex: 1),
                WordTimingSample(wordIndex: 3, text: "setup", startSeconds: 1.2, endSeconds: 1.8, passIndex: 1)
            ],
            markers: [
                TakeMarker(kind: .retake, timestampSeconds: 22.5, label: "Smart Retake", wordIndex: 42),
                TakeMarker(kind: .manual, timestampSeconds: 51.0, label: "Studio Marker", wordIndex: 118)
            ]
        )
        let sampleSummary = TakeSummary(
            durationSeconds: 84,
            averageWPM: 152,
            targetWPM: 150,
            spokenWordsCompleted: 212,
            totalSpokenWords: 212,
            completionRatio: 1.0,
            retakeCount: 1,
            longestPauseSeconds: 1.8
        )

        let schemes: [(suffix: String, appearance: AppAppearance, scheme: ColorScheme)] = [
            ("dark", .dark, .dark),
            ("light", .light, .light)
        ]

        for item in schemes {
            settings.appAppearance = item.appearance
            item.appearance.applyToApplication()
            let palette = DantePalette(colorScheme: item.scheme)

            // 1. Modernized Settings Workspace Screenshots (Embedded General + Appearance, Teleprompter, Guidance, Director, OBS, About)
            let embeddedGeneralView = ContentView(
                initialWorkspaceView: .editor,
                initialShowQuickComposer: false,
                initialShowSettings: true,
                initialSettingsTab: .general
            )
            .preferredColorScheme(item.scheme)
            .frame(width: 1180, height: 740)

            let embeddedGeneralPNG = try renderPNG(
                view: embeddedGeneralView,
                size: NSSize(width: 1180, height: 740),
                appearanceName: item.scheme == .dark ? .darkAqua : .aqua
            )
            try embeddedGeneralPNG.write(to: outputDir.appendingPathComponent("macos-settings-general-\(item.suffix).png"))
            XCTAssertGreaterThan(embeddedGeneralPNG.count, 10_000, "Embedded General settings screenshot unexpectedly small")

            let settingsTabs: [(name: String, tab: SettingsTab)] = [
                ("macos-settings-appearance-\(item.suffix).png", .appearance),
                ("macos-settings-teleprompter-\(item.suffix).png", .teleprompter),
                ("macos-settings-guidance-\(item.suffix).png", .guidance),
                ("macos-studio-integrations-\(item.suffix).png", .director),
                ("macos-settings-obs-\(item.suffix).png", .obs),
                ("macos-settings-about-\(item.suffix).png", .about)
            ]
            for tabShot in settingsTabs {
                let settingsView = SettingsView(
                    settings: settings,
                    initialTab: tabShot.tab,
                    isEmbeddedInWindow: true,
                    enableLivePreview: false
                )
                .preferredColorScheme(item.scheme)
                .frame(width: 1180, height: 740)

                let settingsPNG = try renderPNG(
                    view: settingsView,
                    size: NSSize(width: 1180, height: 740),
                    appearanceName: item.scheme == .dark ? .darkAqua : .aqua
                )
                try settingsPNG.write(to: outputDir.appendingPathComponent(tabShot.name))
                XCTAssertGreaterThan(settingsPNG.count, 10_000, "Screenshot \(tabShot.name) unexpectedly small")
            }

            // 2. Post-Take Analytics & Instant .SRT / FCPXML Export Card
            let summaryStage = ZStack {
                palette.canvasBackground.ignoresSafeArea()
                VStack(spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(palette.statusSuccess)
                        Text("Take Complete")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(palette.textPrimary)
                    }

                    Text("How I Shoot 4K Studio Videos in One Take")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(palette.textSecondary)

                    StudioTakeSummaryView(
                        summary: sampleSummary,
                        takeRecord: sampleRecord,
                        palette: palette
                    )
                    .padding(.top, 2)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(width: 440)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(palette.borderStrong, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(item.scheme == .dark ? 0.55 : 0.14), radius: 24, y: 12)
            }
            .preferredColorScheme(item.scheme)
            .frame(width: 560, height: 300)

            let summaryPNG = try renderPNG(
                view: summaryStage,
                size: NSSize(width: 560, height: 300),
                appearanceName: item.scheme == .dark ? .darkAqua : .aqua
            )
            try summaryPNG.write(to: outputDir.appendingPathComponent("macos-take-summary-\(item.suffix).png"))
        }
    }

    @ViewBuilder
    private func makeOverlayStageView(
        mode: OverlayMode,
        scheme: ColorScheme,
        content: OverlayContent,
        recognizer: SpeechRecognizer,
        tracker: NotchFrameTracker
    ) -> some View {
        let palette = DantePalette(colorScheme: scheme)
        let menuBarHeight: CGFloat = 37

        ZStack(alignment: .top) {
            // Subtle studio desktop backdrop with the Dante workspace resting below the menu bar
            palette.sidebarBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Realistic macOS menu bar strip
                HStack(spacing: 14) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Dante for Creators")
                        .font(.system(size: 12.5, weight: .semibold))
                    Text("File")
                    Text("Edit")
                    Text("Teleprompter")
                    Text("View")
                    Spacer()
                    Image(systemName: "mic.fill")
                        .foregroundStyle(palette.accent)
                    Image(systemName: "wifi")
                    Text("Thu 9:41 AM")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.textSecondary)
                .padding(.horizontal, 18)
                .frame(height: menuBarHeight)
                .background(palette.surface.opacity(scheme == .dark ? 0.92 : 0.96))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(palette.borderSubtle)
                        .frame(height: 1)
                }

                // Underlying workspace window gently framed on the desktop
                ContentView(
                    initialWorkspaceView: .editor,
                    initialShowQuickComposer: false
                )
                .frame(width: 1080, height: 635)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(palette.borderStrong, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(scheme == .dark ? 0.45 : 0.12), radius: 24, y: 12)
                .opacity(mode == .pinned ? 0.62 : 0.48)
                .padding(.top, 34)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            if mode == .pinned {
                // Snapped-to-notch teleprompter docked flush to the top edge of the screen
                ZStack(alignment: .top) {
                    NotchOverlayView(
                        content: content,
                        speechRecognizer: recognizer,
                        menuBarHeight: menuBarHeight,
                        frameTracker: tracker,
                        startExpanded: true
                    )
                    .frame(width: 420, height: menuBarHeight + 190)
                    .shadow(color: Color.black.opacity(scheme == .dark ? 0.65 : 0.28), radius: 22, y: 10)

                    // Hardware MacBook camera notch centered at top edge
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 10,
                        bottomTrailingRadius: 10,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                    .fill(Color.black)
                    .frame(width: 176, height: 30)
                    .overlay {
                        Circle()
                            .fill(Color(red: 28 / 255, green: 34 / 255, blue: 46 / 255))
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .fill(Color(red: 69 / 255, green: 106 / 255, blue: 246 / 255).opacity(0.45))
                                    .frame(width: 3, height: 3)
                            )
                    }
                }
            } else {
                // Floating studio teleprompter overlay centered above the workspace
                FloatingOverlayView(
                    content: content,
                    speechRecognizer: recognizer,
                    baseHeight: 235,
                    followingCursor: false,
                    startExpanded: true
                )
                .frame(width: 460, height: 245)
                .shadow(
                    color: Color.black.opacity(scheme == .dark ? 0.60 : 0.18),
                    radius: 28,
                    y: 14
                )
                .padding(.top, 118)
            }
        }
    }

    private func seedDemoWorkspace() {
        let store = ScriptLibraryStore.shared
        let settings = NotchSettings.shared
        settings.hasDismissedSetupChecklist = false
        settings.hasCompletedFirstSession = false
        settings.listeningMode = .wordTracking
        settings.speechEngine = .apple
        settings.overlayMode = .pinned

        let demoSpecs: [(title: String, preset: CreatorPresetID, pinned: Bool, pages: [String])] = [
            (
                "How I Shoot 4K Studio Videos in One Take",
                .youtubeStudio,
                true,
                CreatorPreset.preset(for: .youtubeStudio).starterPages
            ),
            (
                "60s Vertical Studio Lighting Breakdown",
                .shortsReels,
                true,
                CreatorPreset.preset(for: .shortsReels).starterPages
            ),
            (
                "Creator Ops Podcast Ep. 14 — Audio Chain",
                .podcastInterview,
                false,
                CreatorPreset.preset(for: .podcastInterview).starterPages
            ),
            (
                "Q4 Product Launch Keynote",
                .keynoteLive,
                false,
                CreatorPreset.preset(for: .keynoteLive).starterPages
            ),
            (
                "Camera Rig & Teleprompter Glass Setup",
                .youtubeStudio,
                false,
                ["[intro — calm studio tone]\nHere is the exact desk setup I use every week so I can look straight into the 35mm lens while reading complex technical scripts naturally."]
            )
        ]

        var primary: DanteScript?
        for spec in demoSpecs {
            let created = store.createScript(title: spec.title, pages: spec.pages, presetID: spec.preset)
            if spec.pinned {
                store.togglePin(id: created.id)
            }
            if primary == nil {
                primary = created
            }
        }

        if let primary {
            store.selectScript(primary)
            TextreamService.shared.pages = primary.pages
            TextreamService.shared.savedPages = primary.pages
            TextreamService.shared.currentPageIndex = 0
            settings.apply(preset: CreatorPreset.preset(for: .youtubeStudio))
        }
    }

    private func renderPNG<V: View>(
        view: V,
        size: NSSize,
        appearanceName: NSAppearance.Name
    ) throws -> Data {
        let appearance = NSAppearance(named: appearanceName)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.appearance = appearance

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.appearance = appearance
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.contentView = hostingView
        window.layoutIfNeeded()
        hostingView.layoutSubtreeIfNeeded()

        // Allow SwiftUI state, onAppear, and NSTextView highlighting to settle
        RunLoop.main.run(until: Date().addingTimeInterval(0.35))
        hostingView.layoutSubtreeIfNeeded()

        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            throw NSError(domain: "DanteScreenshotCapture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create bitmapImageRep"])
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: rep)

        guard let png = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "DanteScreenshotCapture", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
        }
        window.orderOut(nil)
        return png
    }
}
