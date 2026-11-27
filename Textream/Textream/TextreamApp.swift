//
//  TextreamApp.swift
//  Textream
//
//  Created by Fatih Kadir Akın on 8.02.2026.
//

import SwiftUI
import OSLog
import TranscribeCpp

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let openAbout = Notification.Name("openAbout")
    static let openOnboarding = Notification.Name("openOnboarding")
    static let openQuickComposer = Notification.Name("openQuickComposer")
    static let newScript = Notification.Name("newScript")
    static let startPrompter = Notification.Name("startPrompter")
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let lifecycleLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? DanteAppLinks.bundleIdentifier,
        category: "AppLifecycle"
    )

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        let launchedByURL: Bool
        if let event = NSAppleEventManager.shared().currentAppleEvent {
            launchedByURL = event.eventClass == kInternetEventClass
        } else {
            launchedByURL = false
        }
        if launchedByURL {
            TextreamService.shared.launchedExternally = true
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if BENCHMARK
        Bench.didFinishLaunchingBegan()
        #endif
        NotchSettings.shared.appAppearance.applyToApplication()
        NSApp.servicesProvider = TextreamService.shared
        NSUpdateDynamicServices()
        benchLog("launch.step", ["name": "services"])

        // Route native transcribe.cpp diagnostics to the system log. ggml emits
        // verbose per-kernel detail at info level; keep only warnings/errors.
        let logSubsystem = Bundle.main.bundleIdentifier ?? DanteAppLinks.bundleIdentifier
        Transcribe.setLogHandler { level, message in
            guard level == .warn || level == .error else { return }
            let logger = Logger(subsystem: logSubsystem, category: "LocalSpeech")
            if level == .error {
                logger.error("\(message, privacy: .public)")
            } else {
                logger.warning("\(message, privacy: .public)")
            }
        }

        if TextreamService.shared.launchedExternally {
            TextreamService.shared.hideMainWindow()
        }

        benchLog("launch.step", ["name": "updateCheck"])

        // Start browser server if enabled
        TextreamService.shared.updateBrowserServer()
        benchLog("launch.step", ["name": "browserServer"])

        // Start director server if enabled
        TextreamService.shared.updateDirectorServer()
        benchLog("launch.step", ["name": "directorServer"])

        // Set window delegate to intercept close, disable tabs, and make titlebar seamless
        DispatchQueue.main.async {
            for window in NSApp.windows where !(window is NSPanel) {
                window.delegate = self
                window.tabbingMode = .disallowed
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.styleMask.insert(.fullSizeContentView)
            }
            self.removeUnwantedMenus()
            benchAttachProbe(to: NSApp.windows.first { !($0 is NSPanel) && $0.isVisible }, label: "main") { 0 }
        }
        #if BENCHMARK
        Bench.didFinishLaunchingEnded()
        #endif
    }

    private func removeUnwantedMenus() {
        guard let mainMenu = NSApp.mainMenu else { return }
        // Remove View and Window menus (keep Edit for copy/paste)
        let menusToRemove = ["View", "Window"]
        for title in menusToRemove {
            if let index = mainMenu.items.firstIndex(where: { $0.title == title }) {
                mainMenu.removeItem(at: index)
            }
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if TextreamService.shared.hasUnsavedChanges {
            guard TextreamService.shared.confirmDiscardIfNeeded() else { return false }
        }
        NSApp.terminate(nil)
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard
            TextreamService.shared.overlayController.isShowing,
            let event = NSAppleEventManager.shared().currentAppleEvent,
            event.eventClass == kCoreEventClass,
            event.eventID == kAEQuitApplication,
            event.paramDescriptor(forKeyword: kAEQuitReason) == nil
        else {
            return .terminateNow
        }

        let senderPID = event.attributeDescriptor(forKeyword: keySenderPIDAttr)?.int32Value ?? 0
        let runningApplication = NSRunningApplication(processIdentifier: pid_t(senderPID))
        let senderName = runningApplication?.localizedName ?? "unknown"
        let senderBundleIdentifier = runningApplication?.bundleIdentifier ?? "unknown"

        lifecycleLogger.warning(
            "Blocked external quit while teleprompter is active; senderPID=\(senderPID, privacy: .public) sender=\(senderName, privacy: .public) bundleIdentifier=\(senderBundleIdentifier, privacy: .public)"
        )
        return .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Release the local model while the process is still fully alive: the
        // native Metal backend asserts if its device tears down during static
        // destruction while a model is still loaded (upstream ggml constraint).
        LocalSpeechEngine.shared.unloadModelSynchronously()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if TextreamService.shared.launchedExternally {
            TextreamService.shared.launchedExternally = false
            NSApp.setActivationPolicy(.regular)
        }
        if !flag {
            // Show existing window instead of letting SwiftUI create a duplicate
            for window in NSApp.windows where !(window is NSPanel) {
                window.makeKeyAndOrderFront(nil)
                return false
            }
        }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            let ext = url.pathExtension.lowercased()
            if ext == DanteAppLinks.fileExtension {
                TextreamService.shared.openFileAtURL(url)
                // Show the main window for file opens
                for window in NSApp.windows where !(window is NSPanel) {
                    window.makeKeyAndOrderFront(nil)
                }
                NSApp.activate(ignoringOtherApps: true)
            } else {
                let wasExternal = TextreamService.shared.launchedExternally
                TextreamService.shared.launchedExternally = true
                if !wasExternal {
                    NSApp.setActivationPolicy(.accessory)
                }
                TextreamService.shared.hideMainWindow()
                TextreamService.shared.handleURL(url)
            }
        }
    }
}

@main
struct TextreamApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var settings = NotchSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(settings.appAppearance.colorScheme)
                .onOpenURL { url in
                    if url.pathExtension.lowercased() == DanteAppLinks.fileExtension {
                        TextreamService.shared.openFileAtURL(url)
                    } else {
                        TextreamService.shared.handleURL(url)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1080, height: 700)
        .windowResizability(.contentMinSize)

        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Dante for Creators") {
                    NotificationCenter.default.post(name: .openAbout, object: nil)
                }
            }
            CommandGroup(after: .appSettings) {
                Button("Settings…") {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .newItem) {
                Button("Quick Composer…") {
                    NotificationCenter.default.post(name: .openQuickComposer, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("New Script") {
                    NotificationCenter.default.post(name: .newScript, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Open File or Presentation…") {
                    TextreamService.shared.openFile()
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("Save") {
                    TextreamService.shared.saveFile()
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Save As…") {
                    TextreamService.shared.saveFileAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Menu("Export Last Take") {
                    ForEach(TakeExportFormat.allCases) { format in
                        Button(format.label) {
                            TextreamService.shared.exportLastTake(format: format)
                        }
                    }
                }
                .disabled(TextreamService.shared.lastTakeRecord == nil)

                Divider()

                Button("Start Prompter") {
                    NotificationCenter.default.post(name: .startPrompter, object: nil)
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
            CommandGroup(replacing: .windowArrangement) { }
            CommandGroup(replacing: .help) {
                Button("Creator Setup Guide…") {
                    NotificationCenter.default.post(name: .openOnboarding, object: nil)
                }
                Divider()
                Button("Dante for Creators Support") {
                    NSWorkspace.shared.open(DanteAppLinks.supportURL)
                }
                Button("Privacy Policy") {
                    NSWorkspace.shared.open(DanteAppLinks.privacyURL)
                }
            }
        }
    }
}
