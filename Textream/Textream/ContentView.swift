//
//  ContentView.swift
//  Dante for Creators
//

import AppKit
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import Speech
import SwiftUI
import UniformTypeIdentifiers

enum StudioWorkspaceView: String, CaseIterable {
    case editor
    case library
}

private enum LibrarySegment: String, CaseIterable, Identifiable {
    case all
    case pinned
    case templates

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:       return "All scripts"
        case .pinned:    return "Pinned"
        case .templates: return "Templates"
        }
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var service = TextreamService.shared
    @State private var settings = NotchSettings.shared
    @State private var library = ScriptLibraryStore.shared

    @State private var workspaceView: StudioWorkspaceView
    @State private var librarySegment: LibrarySegment = .all
    @State private var presetFilter: CreatorPresetID? = nil
    @State private var isSidebarVisible = true
    @State private var isPinnedSectionExpanded = true
    @State private var isAllSectionExpanded = true
    @State private var isTemplatesSectionExpanded = true
    @State private var hoveredScriptID: UUID? = nil

    @State private var isRunning = false
    @State private var dictation = DictationManager()
    @State private var dictationHighlightRange: NSRange? = nil
    @State private var dictationCaretPosition: Int? = nil
    @State private var editorCaretPosition: Int = 0
    @State private var isDroppingPresentation = false
    @State private var dropError: String?
    @State private var dropAlertTitle: String = "Import Error"
    @State private var showSettings = false
    @State private var showAbout = false
    @State private var showOnboarding = false
    @State private var showQuickComposer: Bool

    init(
        initialWorkspaceView: StudioWorkspaceView = .editor,
        initialShowQuickComposer: Bool = false
    ) {
        _workspaceView = State(initialValue: initialWorkspaceView)
        _showQuickComposer = State(initialValue: initialShowQuickComposer)
    }
    @State private var showWPMPopover = false
    @State private var renamingScriptID: UUID?
    @State private var renameDraft: String = ""
    @State private var languageSuggestion: SpeechLanguageSuggestion?
    @State private var ignoredLanguageIdentifier: String?
    @State private var languageDetectionTask: Task<Void, Never>?
    @FocusState private var isTextFocused: Bool

    @State private var highlightClearTimer: Timer?
    @State private var segmentStart: Int = 0
    @State private var segmentLength: Int = 0
    @State private var segmentNeedsSeparator: Bool = false
    @State private var spokenSkipOffset: Int = 0
    @State private var lastRawSpokenLength: Int = 0
    @State private var isImporting = false

    private var palette: DantePalette {
        DantePalette(colorScheme: colorScheme)
    }

    private var languageLabel: String {
        let locale = settings.speechLocale
        return Locale.current.localizedString(forIdentifier: locale) ?? locale
    }

    private var activeScript: DanteScript? {
        library.activeScript
    }

    private var activeMetrics: ScriptMetrics {
        let wpm = activeScript?.targetWPM ?? ScriptMetrics.defaultWPM
        return ScriptMetrics.measure(pages: service.pages, wordsPerMinute: wpm)
    }

    private var activePreset: CreatorPreset? {
        activeScript?.presetID.map { CreatorPreset.preset(for: $0) }
    }

    private var setupChecklist: CreatorSetupChecklistState {
        let micAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let speechAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
        let guidanceReady = settings.listeningMode == .classic || (micAuthorized && speechAuthorized) || settings.speechEngine == .local
        return CreatorSetupChecklistState.evaluate(
            hasChosenPreset: activePreset != nil,
            hasConfiguredGuidance: guidanceReady,
            hasCustomScript: library.scripts.count > 1 || service.currentFileURL != nil,
            hasRunSession: settings.hasCompletedFirstSession
        )
    }

    private var currentText: Binding<String> {
        Binding(
            get: {
                guard service.currentPageIndex < service.pages.count else { return "" }
                return service.pages[service.currentPageIndex]
            },
            set: { newValue in
                guard service.currentPageIndex < service.pages.count else { return }
                service.pages[service.currentPageIndex] = newValue
                library.updateActivePages(service.pages)
            }
        )
    }

    private var hasAnyContent: Bool {
        service.pages.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var isRecording: Bool {
        dictation.isRecording || dictation.isStarting
    }

    private var displayedLibraryScripts: [DanteScript] {
        var result = library.filteredScripts
        if let presetFilter {
            result = result.filter { $0.presetID == presetFilter }
        }
        return result
    }

    private var pinnedLibraryScripts: [DanteScript] {
        displayedLibraryScripts.filter(\.isPinned)
    }

    private var unpinnedLibraryScripts: [DanteScript] {
        displayedLibraryScripts.filter { !$0.isPinned }
    }

    // MARK: - Body

    var body: some View {
        withLifecycleModifiers(
            withPresentationModifiers(rootLayer)
        )
    }

    private var rootLayer: some View {
        ZStack {
            if settings.directorModeEnabled {
                directorOverlay
            } else {
                studioShell
            }

            if showQuickComposer {
                quickComposerLayer
                    .transition(.opacity)
                    .zIndex(50)
            }
        }
        .background(palette.sidebarBackground)
        .frame(minWidth: 760, minHeight: 500)
    }

    private var quickComposerLayer: some View {
        QuickComposerOverlay(
            settings: settings,
            scripts: library.scripts,
            onCreateScript: handleQuickComposerCreate,
            onSelectScript: { script in
                selectScript(script)
                workspaceView = .editor
            },
            onImportFile: {
                service.openFile()
            },
            onDismiss: dismissQuickComposer
        )
    }

    private func handleQuickComposerCreate(
        title: String,
        text: String,
        preset: CreatorPreset,
        startImmediately: Bool
    ) {
        let created = library.createScript(
            title: title,
            pages: [text],
            presetID: preset.id
        )
        settings.apply(preset: preset)
        loadScriptIntoEditor(created)
        workspaceView = .editor
        if startImmediately && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            DispatchQueue.main.async {
                run()
            }
        }
    }

    private func dismissQuickComposer() {
        withAnimation(.easeOut(duration: 0.16)) {
            showQuickComposer = false
        }
    }

    private func withPresentationModifiers<Content: View>(_ content: Content) -> some View {
        let dropPresented = Binding(
            get: { dropError != nil },
            set: { if !$0 { dropError = nil } }
        )
        let dictationErrorPresented = Binding(
            get: { dictation.error != nil },
            set: { if !$0 { dictation.error = nil } }
        )
        let renamePresented = Binding(
            get: { renamingScriptID != nil },
            set: { if !$0 { renamingScriptID = nil } }
        )

        return content
            .alert(dropAlertTitle, isPresented: dropPresented) {
                Button("OK") { dropError = nil }
            } message: {
                Text(dropError ?? "")
            }
            .alert("Microphone or Speech Unavailable", isPresented: dictationErrorPresented) {
                if dictation.permissionSettingsURL != nil {
                    Button("Open System Settings") {
                        dictation.openPermissionSettings()
                        dictation.error = nil
                    }
                }
                Button("OK", role: .cancel) { dictation.error = nil }
            } message: {
                Text(dictation.error ?? "")
            }
            .alert("Rename Script", isPresented: renamePresented) {
                TextField("Script title", text: $renameDraft)
                Button("Cancel", role: .cancel) { renamingScriptID = nil }
                Button("Rename") {
                    if let id = renamingScriptID {
                        library.renameScript(id: id, to: renameDraft)
                    }
                    renamingScriptID = nil
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(settings: settings)
                    .preferredColorScheme(settings.appAppearance.colorScheme)
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
                    .preferredColorScheme(settings.appAppearance.colorScheme)
            }
            .sheet(isPresented: $showOnboarding) {
                CreatorOnboardingView { preset in
                    applyPreset(preset)
                }
                .preferredColorScheme(settings.appAppearance.colorScheme)
            }
    }

    private func withLifecycleModifiers<Content: View>(_ content: Content) -> some View {
        content
            .onChange(of: showSettings) { _, isShowing in
                if isShowing && isRecording {
                    stopRecording()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .startPrompter)) { _ in
                guard !showSettings, !showOnboarding, !showQuickComposer, !isRunning, !isRecording, hasAnyContent else { return }
                isTextFocused = false
                run()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openQuickComposer)) { _ in
                guard !showSettings, !showOnboarding else { return }
                if isRecording { stopRecording() }
                withAnimation(.easeOut(duration: 0.16)) {
                    showQuickComposer.toggle()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
                showSettings = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .openAbout)) { _ in
                showAbout = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .openOnboarding)) { _ in
                showOnboarding = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .newScript)) { _ in
                createNewScript()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                isRunning = service.overlayController.isShowing
            }
            .onChange(of: service.currentPageText, initial: true) { _, text in
                scheduleLanguageDetection(for: text)
            }
            .onChange(of: service.currentPageIndex) { _, _ in
                if isRecording {
                    stopRecording()
                }
                ignoredLanguageIdentifier = nil
                scheduleLanguageDetection(for: service.currentPageText)
            }
            .onChange(of: settings.speechLocale) { _, _ in
                if isRecording {
                    stopRecording()
                }
                ignoredLanguageIdentifier = nil
                scheduleLanguageDetection(for: service.currentPageText)
            }
            .onDisappear {
                languageDetectionTask?.cancel()
                if isRecording {
                    stopRecording()
                }
            }
            .onAppear(perform: handleOnAppear)
    }

    private func handleOnAppear() {
        if service.currentFileURL == nil,
           service.pages.count == 1 && service.pages[0].isEmpty,
           let active = library.activeScript {
            service.pages = active.pages
            service.savedPages = active.pages
            service.currentPageIndex = 0
        }
        if service.overlayController.isShowing {
            isRunning = true
        }
        if TextreamService.shared.launchedExternally {
            DispatchQueue.main.async {
                for window in NSApp.windows where !(window is NSPanel) {
                    window.orderOut(nil)
                }
            }
        } else {
            isTextFocused = true
            #if !BENCHMARK
            let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            if !isRunningTests && !UserDefaults.standard.bool(forKey: CreatorOnboardingView.completedDefaultsKey) {
                showOnboarding = true
            }
            #endif
        }
    }

    // MARK: - Studio Shell (Sidebar Rail + Top Tab Bar + Canvas)

    private var studioShell: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                studioSidebar
                    .frame(width: 240)
                    .background(palette.sidebarBackground)

                Rectangle()
                    .fill(palette.borderSubtle)
                    .frame(width: 1)
                    .ignoresSafeArea(.container, edges: .top)
            }

            VStack(spacing: 0) {
                studioTopBar
                Rectangle()
                    .fill(palette.borderSubtle)
                    .frame(height: 1)

                Group {
                    switch workspaceView {
                    case .editor:
                        editorCanvas
                    case .library:
                        libraryCanvas
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(palette.canvasBackground)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    // MARK: - Left Navigation Rail (Screenshot 1)

    private var studioSidebar: some View {
        VStack(spacing: 0) {
            // Top bar aligned with traffic lights
            HStack(spacing: 8) {
                Spacer(minLength: 68)

                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        showQuickComposer = true
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Quick Composer & Search (⌘K)")

                Button {
                    createNewScript()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("New Script (⌘N)")
            }
            .padding(.horizontal, 10)
            .frame(height: 40)

            // Brand header row
            HStack(spacing: 8) {
                if let icon = NSImage(named: "AppIcon") {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 22, height: 22)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                Text("Dante Studio")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                DanteKeycapBadge(label: "⌘K", palette: palette)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.16)) {
                    showQuickComposer = true
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Presets section (matching top rail section in Screenshot 1)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Presets")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(palette.textTertiary)
                            Spacer()
                            Menu {
                                ForEach(CreatorPreset.all) { preset in
                                    Button {
                                        applyPreset(preset)
                                    } label: {
                                        Label("\(preset.name) (\(preset.targetWPM) WPM)", systemImage: preset.systemImage)
                                    }
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(palette.textTertiary)
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                            .help("Switch Creator Preset")
                        }
                        .padding(.horizontal, 12)

                        let currentPreset = activePreset ?? CreatorPreset.preset(for: .youtubeStudio)
                        Menu {
                            ForEach(CreatorPreset.all) { preset in
                                Button {
                                    applyPreset(preset)
                                } label: {
                                    Label("\(preset.name) · \(preset.targetWPM) WPM", systemImage: preset.systemImage)
                                }
                            }
                        } label: {
                            HStack(spacing: 9) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(palette.accentSubtle)
                                        .frame(width: 30, height: 30)
                                    Image(systemName: currentPreset.systemImage)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(palette.accent)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(currentPreset.name)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(palette.textPrimary)
                                        .lineLimit(1)
                                    Text("\(currentPreset.targetWPM) WPM · \(settings.listeningMode.label)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(palette.textTertiary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 4)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(palette.borderSubtle, lineWidth: 1)
                            )
                        }
                        .menuStyle(.borderlessButton)
                        .padding(.horizontal, 10)
                    }

                    // Workspace & Scripts section
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Workspace")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(palette.textTertiary)
                            Spacer()
                            Button {
                                createNewScript()
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(palette.textTertiary)
                            }
                            .buttonStyle(.plain)
                            .help("New Script (⌘N)")
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 4)

                        // Library nav item (like "Automations  23  •" in Screenshot 1)
                        Button {
                            workspaceView = .library
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(workspaceView == .library ? palette.textPrimary : palette.textTertiary)
                                    .frame(width: 14)
                                Text("Scripts & Templates")
                                    .font(.system(size: 12, weight: workspaceView == .library ? .semibold : .medium))
                                    .foregroundStyle(workspaceView == .library ? palette.textPrimary : palette.textSecondary)
                                Text("\(library.scripts.count)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(palette.textTertiary)
                                Spacer()
                                if workspaceView == .library {
                                    Circle()
                                        .fill(palette.accent)
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                workspaceView == .library ? palette.surfaceHover : Color.clear,
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)

                        // Active script items
                        ForEach(library.scripts.prefix(8)) { script in
                            let isSelected = workspaceView == .editor && script.id == library.selectedScriptID
                            Button {
                                selectScript(script)
                                workspaceView = .editor
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: script.isPinned ? "pin.fill" : "doc.text")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(isSelected ? palette.accent : palette.textTertiary)
                                        .frame(width: 14)
                                    Text(script.displayTitle)
                                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                        .foregroundStyle(isSelected ? palette.textPrimary : palette.textSecondary)
                                        .lineLimit(1)
                                    Spacer(minLength: 4)
                                    if isSelected {
                                        Circle()
                                            .fill(palette.accent)
                                            .frame(width: 6, height: 6)
                                    } else {
                                        Text(script.metrics.formattedDuration)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(palette.textTertiary)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    isSelected ? palette.surfaceHover : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            .contextMenu { scriptContextMenu(for: script) }
                        }
                    }

                    // Active Script Pages section
                    if workspaceView == .editor && service.pages.count > 1 {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("Pages")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(palette.textTertiary)
                                Text("\(service.pages.count)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(palette.textTertiary)
                                Spacer()
                                Button {
                                    addPage()
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(palette.textTertiary)
                                }
                                .buttonStyle(.plain)
                                .help("Add Page")
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 4)

                            ForEach(Array(service.pages.enumerated()), id: \.offset) { index, page in
                                let isCurrent = service.currentPageIndex == index
                                Button {
                                    if isRecording { stopRecording() }
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        service.currentPageIndex = index
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Text("\(index + 1)")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(isCurrent ? .white : palette.textSecondary)
                                            .frame(width: 18, height: 18)
                                            .background(
                                                service.readPages.contains(index)
                                                    ? palette.statusSuccess.opacity(0.35)
                                                    : (isCurrent ? palette.accent : palette.surfaceHover),
                                                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            )
                                        Text(pagePreview(page))
                                            .font(.system(size: 11))
                                            .foregroundStyle(isCurrent ? palette.textPrimary : palette.textSecondary)
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        isCurrent ? palette.surfaceHover : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 8)
                                .contextMenu {
                                    if service.pages.count > 1 {
                                        Button(role: .destructive) {
                                            removePage(at: index)
                                        } label: {
                                            Label("Delete Page", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
            }

            // Bottom "Finish setting up" checklist card (Screenshot 1 signature)
            if !settings.hasDismissedSetupChecklist && !setupChecklist.isAllComplete {
                setupChecklistCard
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }

            // Bottom utility dock (Screenshot 1 bottom-left footer)
            Rectangle()
                .fill(palette.borderSubtle)
                .frame(height: 1)

            HStack(spacing: 6) {
                Button {
                    showAbout = true
                } label: {
                    Text("D")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                        .frame(width: 24, height: 24)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(palette.borderSubtle, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("About Dante for Creators")

                Spacer()

                // Appearance toggle (System / Dark / Light)
                Menu {
                    ForEach(AppAppearance.allCases) { appearance in
                        Button {
                            settings.appAppearance = appearance
                        } label: {
                            HStack {
                                Label(appearance.label, systemImage: appearance.systemImage)
                                if settings.appAppearance == appearance {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: settings.appAppearance.systemImage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .frame(width: 26, height: 26)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Appearance: \(settings.appAppearance.label) (System / Light / Dark)")

                Button {
                    if isRecording { stopRecording() }
                    service.openFile()
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open Script or Presentation (⌘O)")

                Button {
                    showOnboarding = true
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Creator Setup Guide")

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Settings (⌘,)")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    private var setupChecklistCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Finish setting up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        settings.hasDismissedSetupChecklist = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(palette.textTertiary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(palette.borderSubtle)
                        Capsule()
                            .fill(palette.accent)
                            .frame(width: max(6, geo.size.width * setupChecklist.progress))
                    }
                }
                .frame(height: 3)

                Text(setupChecklist.progressLabel)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(palette.textTertiary)
            }

            VStack(alignment: .leading, spacing: 5) {
                ForEach(setupChecklist.steps) { step in
                    HStack(spacing: 7) {
                        Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 11))
                            .foregroundStyle(step.isCompleted ? palette.accent : palette.textTertiary)
                        Text(step.title)
                            .font(.system(size: 11))
                            .foregroundStyle(step.isCompleted ? palette.textTertiary : palette.textSecondary)
                            .strikethrough(step.isCompleted, color: palette.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Button {
                if hasAnyContent {
                    run()
                } else {
                    showOnboarding = true
                }
            } label: {
                Text(hasAnyContent ? "Start your first session" : "Open Creator Setup")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(palette.surfaceHover, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(palette.borderSubtle, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(11)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - Top Tab & Command Chrome Bar (Screenshot 1)

    private var studioTopBar: some View {
        HStack(spacing: 8) {
            if !isSidebarVisible {
                Spacer().frame(width: 68)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isSidebarVisible.toggle()
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isSidebarVisible ? "Hide Sidebar" : "Show Sidebar")

            // Tab pills (like "Automations" tab in Screenshot 1)
            HStack(spacing: 4) {
                topWorkspaceTab(
                    title: activeScript?.displayTitle ?? "Editor",
                    icon: "doc.text",
                    isSelected: workspaceView == .editor,
                    hasUnsavedDot: service.currentFileURL != nil && service.pages != service.savedPages
                ) {
                    workspaceView = .editor
                }

                topWorkspaceTab(
                    title: "Scripts",
                    icon: "square.grid.2x2",
                    isSelected: workspaceView == .library,
                    hasUnsavedDot: false
                ) {
                    workspaceView = .library
                }

                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        showQuickComposer = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.textTertiary)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Quick Composer (⌘K)")
            }

            Spacer(minLength: 12)

            // Quick Guidance / Engine status pill
            Button {
                showSettings = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: settings.listeningMode.icon)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(palette.accent)
                    Text(settings.listeningMode == .wordTracking
                         ? (settings.speechEngine == .local ? "Local AI" : languageLabel)
                         : settings.listeningMode.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(palette.borderSubtle, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Configure Guidance & Speech Settings")

            // 1-click Light / Dark / System switcher
            Button {
                settings.appAppearance = settings.appAppearance.next()
            } label: {
                Image(systemName: settings.appAppearance.systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(palette.borderSubtle, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help("Switch Appearance (Current: \(settings.appAppearance.label))")

            // Compact Cobalt-Blue Start / Stop CTA
            Button {
                if isRunning {
                    stop()
                } else {
                    run()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(isRunning ? "Stop" : "Start")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(
                    isRunning ? palette.statusDanger : palette.accent,
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled((!isRunning && !hasAnyContent) || isRecording)
            .opacity((!hasAnyContent && !isRunning) || isRecording ? 0.45 : 1)
            .help(isRunning ? "Stop Prompter" : "Start Prompter (⌘↩)")
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(palette.sidebarBackground)
    }

    private func topWorkspaceTab(
        title: String,
        icon: String,
        isSelected: Bool,
        hasUnsavedDot: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? palette.textPrimary : palette.textTertiary)
                if hasUnsavedDot {
                    Circle()
                        .fill(palette.statusWarning)
                        .frame(width: 5, height: 5)
                }
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? palette.textPrimary : palette.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: 150, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                isSelected ? palette.activeTabBackground : Color.clear,
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(isSelected ? palette.borderSubtle : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Library & Templates Canvas (1:1 Screenshot 1 Aesthetic)

    private var libraryCanvas: some View {
        VStack(spacing: 0) {
            // Page Header Row
            HStack {
                Text("Scripts")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                HStack(spacing: 8) {
                    // Inline search input
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundStyle(palette.textTertiary)
                        TextField("Search scripts…", text: $library.searchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(palette.textPrimary)
                            .frame(width: 150)
                        if !library.searchQuery.isEmpty {
                            Button {
                                library.searchQuery = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(palette.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(palette.borderSubtle, lineWidth: 1)
                    )

                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            showQuickComposer = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(palette.textPrimary)
                            .frame(width: 26, height: 26)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(palette.borderSubtle, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("New Script via Quick Composer (⌘K)")
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Segmented Filter Strip (like "My automations | All automations | Scheduled")
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    ForEach(LibrarySegment.allCases) { segment in
                        let isSelected = librarySegment == segment
                        Button {
                            withAnimation(.easeOut(duration: 0.15)) {
                                librarySegment = segment
                            }
                        } label: {
                            Text(segment.label)
                                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                                .foregroundStyle(isSelected ? palette.textPrimary : palette.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    isSelected ? palette.activeTabBackground : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(isSelected ? palette.borderSubtle : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(palette.borderSubtle, lineWidth: 1)
                )

                Spacer()

                // Preset filter menu button (like the funnel icon on Screenshot 1 right)
                Menu {
                    Button {
                        presetFilter = nil
                    } label: {
                        HStack {
                            Text("All Presets")
                            if presetFilter == nil { Image(systemName: "checkmark") }
                        }
                    }
                    Divider()
                    ForEach(CreatorPreset.all) { preset in
                        Button {
                            presetFilter = preset.id
                        } label: {
                            HStack {
                                Label(preset.name, systemImage: preset.systemImage)
                                if presetFilter == preset.id { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    Image(systemName: presetFilter == nil ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(presetFilter == nil ? palette.textSecondary : palette.accent)
                        .frame(width: 28, height: 28)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(palette.borderSubtle, lineWidth: 1)
                        )
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Filter by Creator Preset")
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 10)

            // Active Filter Pills Row (exact Screenshot 1 pill syntax: "Preset | is | YouTube Studio | ×")
            if presetFilter != nil || !library.searchQuery.isEmpty {
                HStack(spacing: 8) {
                    if let presetFilter {
                        let preset = CreatorPreset.preset(for: presetFilter)
                        DanteFilterPill(
                            icon: preset.systemImage,
                            field: "Preset",
                            relation: "is",
                            value: preset.shortName,
                            palette: palette
                        ) {
                            self.presetFilter = nil
                        }
                    }
                    if !library.searchQuery.isEmpty {
                        DanteFilterPill(
                            icon: "magnifyingglass",
                            field: "Query",
                            relation: "contains",
                            value: library.searchQuery,
                            palette: palette
                        ) {
                            library.searchQuery = ""
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
            }

            // Structured Table + Templates Grid
            ScrollView {
                VStack(spacing: 0) {
                    if librarySegment != .templates {
                        if !pinnedLibraryScripts.isEmpty {
                            DanteSectionHeaderBand(
                                title: "Pinned",
                                count: pinnedLibraryScripts.count,
                                isExpanded: isPinnedSectionExpanded,
                                onToggle: { isPinnedSectionExpanded.toggle() },
                                palette: palette
                            )

                            if isPinnedSectionExpanded {
                                ForEach(pinnedLibraryScripts) { script in
                                    libraryScriptRow(script)
                                }
                            }
                        }

                        if librarySegment == .all {
                            DanteSectionHeaderBand(
                                title: "Active Scripts",
                                count: unpinnedLibraryScripts.count,
                                isExpanded: isAllSectionExpanded,
                                onToggle: { isAllSectionExpanded.toggle() },
                                palette: palette
                            )

                            if isAllSectionExpanded {
                                if unpinnedLibraryScripts.isEmpty {
                                    emptyLibraryRow
                                } else {
                                    ForEach(unpinnedLibraryScripts) { script in
                                        libraryScriptRow(script)
                                    }
                                }
                            }
                        } else if pinnedLibraryScripts.isEmpty {
                            emptyLibraryRow
                        }
                    }

                    // Bottom 2-column Templates Grid (exact Screenshot 1 Templates section)
                    DanteSectionHeaderBand(
                        title: "Templates",
                        count: CreatorPreset.all.count,
                        isExpanded: isTemplatesSectionExpanded,
                        onToggle: { isTemplatesSectionExpanded.toggle() },
                        palette: palette
                    )
                    .padding(.top, librarySegment == .templates ? 0 : 8)

                    if isTemplatesSectionExpanded {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ],
                            spacing: 12
                        ) {
                            ForEach(CreatorPreset.all) { preset in
                                templateCard(preset)
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
    }

    private func libraryScriptRow(_ script: DanteScript) -> some View {
        let isHovered = hoveredScriptID == script.id
        let isActive = script.id == library.selectedScriptID
        let preset = script.presetID.map { CreatorPreset.preset(for: $0) }

        return Button {
            selectScript(script)
            workspaceView = .editor
        } label: {
            HStack(spacing: 10) {
                Image(systemName: preset?.systemImage ?? "doc.text")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isActive ? palette.accent : palette.textSecondary)
                    .frame(width: 16)

                Text(script.isPinned ? "PIN" : "DOC")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(isActive ? palette.accent : palette.textTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        isActive ? palette.accentSubtle : palette.surface,
                        in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                    )

                Text(script.displayTitle)
                    .font(.system(size: 13, weight: isActive ? .semibold : .medium))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 16)

                if let preset {
                    Text(preset.name)
                        .font(.system(size: 11))
                        .foregroundStyle(palette.textTertiary)
                        .lineLimit(1)
                }

                Text(script.metrics.summaryLabel)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(palette.textTertiary)
                    .frame(minWidth: 110, alignment: .trailing)

                Text(relativeDateLabel(for: script.updatedAt))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(palette.textTertiary)
                    .frame(width: 44, alignment: .trailing)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(isHovered ? palette.surface : Color.clear)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(palette.borderSubtle.opacity(0.6))
                    .frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredScriptID = hovering ? script.id : (hoveredScriptID == script.id ? nil : hoveredScriptID)
        }
        .contextMenu { scriptContextMenu(for: script) }
    }

    private var emptyLibraryRow: some View {
        HStack {
            Text("No matching scripts. Create a new script or choose a creator template below.")
                .font(.system(size: 12))
                .foregroundStyle(palette.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private func templateCard(_ preset: CreatorPreset) -> some View {
        Button {
            createScriptFromTemplate(preset)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: preset.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.accent)
                    Text(preset.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(palette.textTertiary)
                }

                Text(preset.tagline)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(palette.accent)
                            .frame(width: 5, height: 5)
                        Text(preset.badgeLabel)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(palette.textSecondary)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(palette.canvasBackground, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(palette.borderSubtle, lineWidth: 1)
                    )

                    Spacer()
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 106, alignment: .topLeading)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(palette.borderSubtle, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Studio Editor Canvas

    private var editorCanvas: some View {
        VStack(spacing: 0) {
            editorHeaderBar

            Rectangle()
                .fill(palette.borderSubtle)
                .frame(height: 1)

            if let languageSuggestion {
                languageSuggestionBanner(languageSuggestion)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            ZStack {
                HStack {
                    Spacer(minLength: 0)
                    HighlightingTextEditor(
                        text: currentText,
                        font: .systemFont(ofSize: 15.5, weight: .regular),
                        highlightRange: dictationHighlightRange,
                        caretPosition: $dictationCaretPosition,
                        editorCaretPosition: $editorCaretPosition
                    )
                    .onChange(of: editorCaretPosition) { _, newPos in
                        guard isRecording else { return }
                        let segmentEnd = segmentStart + segmentLength
                        if newPos != segmentEnd {
                            beginNewSegment()
                        }
                    }
                    .frame(maxWidth: 820, maxHeight: .infinity)
                    .padding(.horizontal, 28)
                    Spacer(minLength: 0)
                }

                // Centered dictation waveform pill when recording
                if dictation.isRecording {
                    VStack {
                        Spacer()
                        waveformPill
                            .padding(.bottom, 16)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                }

                // PPTX Drop Zone Overlay
                if isDroppingPresentation {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(palette.accent)
                        Text("Drop PowerPoint (.pptx) file")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.textPrimary)
                        Text("For Keynote or Google Slides,\nexport as PPTX first.")
                            .font(.system(size: 11))
                            .foregroundStyle(palette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(palette.accent, style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .background(palette.accentSubtle.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)))
                    )
                    .padding(14)
                }

                Color.clear
                    .contentShape(Rectangle())
                    .onDrop(of: [.fileURL], isTargeted: $isDroppingPresentation) { providers in
                        guard let provider = providers.first else { return false }
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in
                            guard let url else { return }
                            let ext = url.pathExtension.lowercased()
                            if ext == "key" {
                                DispatchQueue.main.async {
                                    dropAlertTitle = "Conversion Required"
                                    dropError = "Keynote files can't be imported directly. Please export your Keynote presentation as PowerPoint (.pptx) first, then drop the exported file here."
                                }
                                return
                            }
                            guard ext == "pptx" else {
                                DispatchQueue.main.async {
                                    dropAlertTitle = "Import Error"
                                    dropError = "Unsupported file. Drop a PowerPoint (.pptx) file."
                                }
                                return
                            }
                            DispatchQueue.main.async {
                                handlePresentationDrop(url: url)
                            }
                        }
                        return true
                    }
                    .allowsHitTesting(isDroppingPresentation)
            }

            // Bottom studio status & command strip
            Rectangle()
                .fill(palette.borderSubtle)
                .frame(height: 1)

            editorFooterBar
        }
        .animation(.easeInOut(duration: 0.2), value: isRecording)
    }

    private var editorHeaderBar: some View {
        HStack(spacing: 10) {
            // Script title + quick rename
            Button {
                if let script = activeScript {
                    renameDraft = script.displayTitle
                    renamingScriptID = script.id
                }
            } label: {
                HStack(spacing: 6) {
                    Text(service.currentFileURL?.deletingPathExtension().lastPathComponent
                         ?? activeScript?.displayTitle
                         ?? "Untitled Script")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundStyle(palette.textTertiary)
                }
            }
            .buttonStyle(.plain)
            .help("Click to rename script")

            // Compact page pill switcher
            HStack(spacing: 4) {
                ForEach(Array(service.pages.enumerated()), id: \.offset) { index, _ in
                    let isCurrent = service.currentPageIndex == index
                    Button {
                        if isRecording { stopRecording() }
                        service.currentPageIndex = index
                    } label: {
                        Text("P\(index + 1)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(isCurrent ? palette.textPrimary : palette.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                isCurrent ? palette.activeTabBackground : Color.clear,
                                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .strokeBorder(isCurrent ? palette.borderSubtle : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    addPage()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(palette.textTertiary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Add Page")
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(palette.borderSubtle, lineWidth: 1)
            )

            Spacer(minLength: 8)

            // Creator preset pill
            Menu {
                ForEach(CreatorPreset.all) { preset in
                    Button {
                        applyPreset(preset)
                    } label: {
                        Label("\(preset.name) (\(preset.targetWPM) WPM)", systemImage: preset.systemImage)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: activePreset?.systemImage ?? "sparkles")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(palette.accent)
                    Text(activePreset?.shortName ?? "Preset")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(palette.textTertiary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(palette.borderSubtle, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Apply a Creator Format Preset")

            // Target duration pill (e.g., 60s Shorts target)
            if let targetSeconds = activePreset?.targetDurationSeconds,
               activeMetrics.spokenWordCount > 0 {
                let isWithinTarget = activeMetrics.estimatedSeconds <= targetSeconds
                let tint = isWithinTarget ? palette.statusSuccess : palette.statusWarning
                Label(
                    isWithinTarget
                        ? "Fits \(targetSeconds)s"
                        : "+\(activeMetrics.estimatedSeconds - targetSeconds)s over \(targetSeconds)s",
                    systemImage: isWithinTarget ? "checkmark.circle.fill" : "clock.badge.exclamationmark"
                )
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            // WPM / Read-time metrics popover
            Button {
                showWPMPopover.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text(activeMetrics.summaryLabel)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(palette.textSecondary)
                    Text("· \(activeMetrics.targetWPM) WPM")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(palette.textTertiary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(palette.borderSubtle, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showWPMPopover, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Speaking Pace")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("\(activeMetrics.targetWPM) WPM")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(palette.accent)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(activeMetrics.targetWPM) },
                            set: { library.updateActiveMetadata(targetWPM: Int($0.rounded())) }
                        ),
                        in: Double(ScriptMetrics.minWPM)...Double(ScriptMetrics.maxWPM),
                        step: 5
                    )
                    Text("Estimated read time: \(activeMetrics.formattedDuration) for \(activeMetrics.spokenWordCount) spoken words.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(width: 240)
            }
            .help("Adjust target speaking pace (WPM)")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(palette.canvasBackground)
    }

    private var editorFooterBar: some View {
        HStack(spacing: 10) {
            Text("Use [brackets] for stage directions")
                .font(.system(size: 11))
                .foregroundStyle(palette.textTertiary)

            Button {
                withAnimation(.easeOut(duration: 0.16)) {
                    showQuickComposer = true
                }
            } label: {
                HStack(spacing: 4) {
                    DanteKeycapBadge(label: "⌘K", palette: palette)
                    Text("Quick Composer")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.textTertiary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Dictate button
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                HStack(spacing: 6) {
                    if dictation.isStarting {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isRecording ? palette.statusDanger : palette.textSecondary)
                    }
                    Text(isRecording ? "Stop Dictation" : "Dictate")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isRecording ? palette.statusDanger : palette.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    isRecording ? palette.statusDanger.opacity(0.12) : palette.surfaceHover,
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isRecording ? palette.statusDanger.opacity(0.4) : palette.borderSubtle, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isRunning)
            .opacity(isRunning ? 0.45 : 1)

            // Primary Start Prompter CTA
            Button {
                if isRunning {
                    stop()
                } else {
                    run()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(isRunning ? "Stop Prompter" : "Start Prompter")
                        .font(.system(size: 11, weight: .semibold))
                    if !isRunning {
                        Text("⌘↩")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(
                    isRunning ? palette.statusDanger : palette.accent,
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled((!isRunning && !hasAnyContent) || isRecording)
            .opacity((!hasAnyContent && !isRunning) || isRecording ? 0.45 : 1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(palette.surface)
    }

    // MARK: - Context Menu & Helpers

    @ViewBuilder
    private func scriptContextMenu(for script: DanteScript) -> some View {
        Button {
            selectScript(script)
            workspaceView = .editor
        } label: {
            Label("Open in Editor", systemImage: "doc.text")
        }
        Button {
            library.togglePin(id: script.id)
        } label: {
            Label(script.isPinned ? "Unpin" : "Pin Script", systemImage: script.isPinned ? "pin.slash" : "pin")
        }
        Button {
            renameDraft = script.displayTitle
            renamingScriptID = script.id
        } label: {
            Label("Rename…", systemImage: "pencil")
        }
        Button {
            if let copy = library.duplicateScript(id: script.id) {
                loadScriptIntoEditor(copy)
                workspaceView = .editor
            }
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }
        if library.scripts.count > 1 {
            Divider()
            Button(role: .destructive) {
                deleteScript(script)
            } label: {
                Label("Delete Script", systemImage: "trash")
            }
        }
    }

    private func relativeDateLabel(for date: Date) -> String {
        let interval = max(0, Date().timeIntervalSince(date))
        if interval < 60 { return "now" }
        let minutes = Int(interval / 60)
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        return "\(days)d"
    }

    private func pagePreview(_ page: String) -> String {
        let trimmed = page.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Empty" }
        let words = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let preview = words.prefix(5).joined(separator: " ")
        return preview.count > 24 ? String(preview.prefix(24)) + "…" : preview
    }

    private func languageSuggestionBanner(_ suggestion: SpeechLanguageSuggestion) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "character.bubble.fill")
                .foregroundStyle(palette.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("This text looks like \(suggestion.languageName).")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Text("Speech is currently set to \(languageLabel).")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer(minLength: 8)

            Button("Use \(suggestion.languageName)") {
                if isRecording { stopRecording() }
                ignoredLanguageIdentifier = nil
                languageSuggestion = nil
                settings.speechLocale = suggestion.localeIdentifier
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                ignoredLanguageIdentifier = suggestion.detectedLanguageIdentifier
                withAnimation(.easeInOut(duration: 0.2)) {
                    languageSuggestion = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(palette.accent.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    private var waveformPill: some View {
        AudioWaveformView(levels: dictation.audioLevels, color: palette.accent)
            .frame(height: 30)
            .frame(maxWidth: 220)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(palette.elevatedSurface, in: Capsule())
            .overlay(Capsule().strokeBorder(palette.borderStrong, lineWidth: 1))
            .shadow(color: .black.opacity(palette.isDark ? 0.35 : 0.12), radius: 12, y: 4)
    }

    // MARK: - Director Mode Overlay

    private var directorOverlay: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.surface)
                    .frame(width: 64, height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(palette.borderSubtle, lineWidth: 1)
                    )
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(palette.accent)
            }

            VStack(spacing: 4) {
                Text("Director Mode")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Text(service.directorIsReading ? "Reading from director…" : "Waiting for director to send script…")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.textSecondary)
            }

            if let ip = BrowserServer.localIPAddress() {
                let url = "http://\(ip):\(settings.directorServerPort)"

                if let qrImage = generateDirectorQRCode(from: url) {
                    Image(nsImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .padding(10)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                HStack(spacing: 8) {
                    Text(url)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(palette.accent)
                        .textSelection(.enabled)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(palette.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            Button("Open Settings") {
                showSettings = true
            }
            .buttonStyle(.bordered)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.canvasBackground)
    }

    private func generateDirectorQRCode(from string: String) -> NSImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let ciImage = filter.outputImage else { return nil }
        let scale = 10.0
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: scaled.extent.width, height: scaled.extent.height))
    }

    // MARK: - Language Detection & Dictation

    private func scheduleLanguageDetection(for text: String) {
        languageDetectionTask?.cancel()
        languageSuggestion = nil
        let pageIndex = service.currentPageIndex
        let localeIdentifier = settings.speechLocale

        languageDetectionTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 2_500_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled,
                  service.currentPageIndex == pageIndex,
                  service.currentPageText == text,
                  settings.speechLocale == localeIdentifier else { return }

            let suggestion = SpeechLanguageDetector.suggestion(
                for: text,
                currentLocaleIdentifier: localeIdentifier
            )
            guard !Task.isCancelled,
                  suggestion?.detectedLanguageIdentifier != ignoredLanguageIdentifier else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                languageSuggestion = suggestion
            }
        }
    }

    private func beginNewSegment() {
        let pageIndex = service.currentPageIndex
        guard pageIndex < service.pages.count else { return }
        let text = service.pages[pageIndex]
        let caret = min(editorCaretPosition, text.count)

        spokenSkipOffset = lastRawSpokenLength

        let charBefore = caret > 0 ? text[text.index(text.startIndex, offsetBy: caret - 1)] : "\n"
        segmentNeedsSeparator = !(charBefore == " " || charBefore == "\n" || caret == 0)
        segmentStart = caret
        segmentLength = 0
    }

    private func startRecording() {
        lastRawSpokenLength = 0
        spokenSkipOffset = 0
        beginNewSegment()

        dictation.onNewSegment = { [self] in
            lastRawSpokenLength = 0
            spokenSkipOffset = 0
            beginNewSegment()
        }

        dictation.onTextUpdate = { [self] spokenText in
            lastRawSpokenLength = spokenText.count

            let effectiveText: String
            if spokenSkipOffset < spokenText.count {
                effectiveText = String(spokenText.suffix(spokenText.count - spokenSkipOffset))
            } else {
                effectiveText = ""
            }
            guard !effectiveText.isEmpty else { return }

            let pageIndex = service.currentPageIndex
            guard pageIndex < service.pages.count else { return }
            var text = service.pages[pageIndex]

            let safeStart = min(segmentStart, text.count)
            let removeStart = text.index(text.startIndex, offsetBy: safeStart)
            let safeLen = min(segmentLength, text.count - safeStart)
            let removeEnd = text.index(removeStart, offsetBy: safeLen)
            text.removeSubrange(removeStart..<removeEnd)

            let sep = segmentNeedsSeparator ? " " : ""
            let newSegment = sep + effectiveText
            text.insert(contentsOf: newSegment, at: text.index(text.startIndex, offsetBy: min(segmentStart, text.count)))

            let prevLen = segmentLength
            segmentLength = newSegment.count
            service.pages[pageIndex] = text
            library.updateActivePages(service.pages)

            let newChars = segmentLength - prevLen
            if newChars > 0 {
                let highlightStart = segmentStart + prevLen
                dictationHighlightRange = NSRange(location: highlightStart, length: newChars)
            }

            dictationCaretPosition = segmentStart + segmentLength

            highlightClearTimer?.invalidate()
            highlightClearTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                DispatchQueue.main.async {
                    dictationHighlightRange = nil
                }
            }
        }
        dictation.start()
    }

    private func stopRecording() {
        highlightClearTimer?.invalidate()
        highlightClearTimer = nil
        dictationHighlightRange = nil
        dictation.stop()
        dictation.onTextUpdate = nil
        dictation.onNewSegment = nil
    }

    // MARK: - Actions

    private func applyPreset(_ preset: CreatorPreset) {
        settings.apply(preset: preset)
        library.updateActiveMetadata(targetWPM: preset.targetWPM, presetID: .some(preset.id))
    }

    private func createNewScript() {
        if isRecording { stopRecording() }
        let created = library.createScript(
            title: "Untitled Script",
            pages: [""],
            presetID: activePreset?.id
        )
        loadScriptIntoEditor(created)
        workspaceView = .editor
    }

    private func createScriptFromTemplate(_ preset: CreatorPreset) {
        if isRecording { stopRecording() }
        let created = library.createScript(
            title: "\(preset.name) Script",
            pages: preset.starterPages,
            presetID: preset.id
        )
        settings.apply(preset: preset)
        loadScriptIntoEditor(created)
        workspaceView = .editor
    }

    private func addPage() {
        if isRecording { stopRecording() }
        withAnimation(.easeInOut(duration: 0.2)) {
            service.pages.append("")
            service.currentPageIndex = service.pages.count - 1
            library.updateActivePages(service.pages)
        }
    }

    private func selectScript(_ script: DanteScript) {
        guard script.id != library.selectedScriptID else { return }
        if isRecording { stopRecording() }
        library.selectScript(script)
        loadScriptIntoEditor(script)
    }

    private func loadScriptIntoEditor(_ script: DanteScript) {
        service.pages = script.pages
        service.savedPages = script.pages
        service.currentPageIndex = 0
        service.readPages.removeAll()
        service.currentFileURL = nil
    }

    private func deleteScript(_ script: DanteScript) {
        if isRecording { stopRecording() }
        library.deleteScript(id: script.id)
        if let active = library.activeScript {
            loadScriptIntoEditor(active)
        }
    }

    private func removePage(at index: Int) {
        guard service.pages.count > 1 else { return }
        if isRecording { stopRecording() }
        withAnimation(.easeInOut(duration: 0.2)) {
            service.pages.remove(at: index)
            if service.currentPageIndex >= service.pages.count {
                service.currentPageIndex = service.pages.count - 1
            } else if service.currentPageIndex > index {
                service.currentPageIndex -= 1
            }
            library.updateActivePages(service.pages)
        }
    }

    private func run() {
        guard hasAnyContent else { return }
        isTextFocused = false
        settings.hasCompletedFirstSession = true
        service.onOverlayDismissed = { [self] in
            isRunning = false
            service.readPages.removeAll()
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
        service.readPages.removeAll()
        let currentText = service.currentPageText.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentText.isEmpty {
            if let firstNonEmpty = service.pages.firstIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                service.currentPageIndex = firstNonEmpty
            }
        }
        service.readCurrentPage()
        isRunning = true
    }

    private func handlePresentationDrop(url: URL) {
        guard service.confirmDiscardIfNeeded() else { return }
        if isRecording { stopRecording() }
        isImporting = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let notes = try PresentationNotesExtractor.extractNotes(from: url)
                let title = url.deletingPathExtension().lastPathComponent
                DispatchQueue.main.async {
                    let imported = library.createScript(title: title, pages: notes, presetID: .keynoteLive)
                    loadScriptIntoEditor(imported)
                    service.rememberDocumentURL(url)
                    workspaceView = .editor
                    isImporting = false
                }
            } catch {
                DispatchQueue.main.async {
                    dropError = error.localizedDescription
                    isImporting = false
                }
            }
        }
    }

    private func stop() {
        service.overlayController.dismiss()
        service.readPages.removeAll()
        isRunning = false
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var showAcknowledgements = false

    private var palette: DantePalette {
        DantePalette(colorScheme: colorScheme)
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String, !build.isEmpty {
            return "\(short) (\(build))"
        }
        return short
    }

    var body: some View {
        VStack(spacing: 16) {
            if let icon = NSImage(named: "AppIcon") {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            }

            VStack(spacing: 4) {
                Text(DanteAppLinks.appName)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(palette.textPrimary)
                Text("Version \(appVersion)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(palette.textTertiary)
            }

            Text("A studio-grade teleprompter with Smart Follow speech tracking, on-device AI models, and creator workflow presets.")
                .font(.system(size: 13))
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            HStack(spacing: 8) {
                Link(destination: DanteAppLinks.privacyURL) {
                    aboutPillLabel(icon: "hand.raised.fill", title: "Privacy")
                }

                Link(destination: DanteAppLinks.supportURL) {
                    aboutPillLabel(icon: "questionmark.circle.fill", title: "Support")
                }

                Button {
                    showAcknowledgements = true
                } label: {
                    aboutPillLabel(icon: "doc.text.fill", title: "Licenses")
                }
                .buttonStyle(.plain)
            }

            Rectangle().fill(palette.borderSubtle).frame(height: 1)

            VStack(spacing: 4) {
                Text(DanteAppLinks.companyName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                Text(DanteAppLinks.copyrightNotice)
                    .font(.system(size: 10))
                    .foregroundStyle(palette.textTertiary)
            }

            Button("OK") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(.top, 2)
        }
        .padding(24)
        .frame(width: 360)
        .background(palette.elevatedSurface)
        .sheet(isPresented: $showAcknowledgements) {
            OpenSourceLicensesView()
        }
    }

    private func aboutPillLabel(icon: String, title: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
            Text(title)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(palette.textPrimary)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
    }
}

#Preview {
    ContentView()
}
