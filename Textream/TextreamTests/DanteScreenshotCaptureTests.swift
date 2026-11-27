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
