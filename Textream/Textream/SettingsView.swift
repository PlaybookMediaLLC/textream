//
//  SettingsView.swift
//  Textream
//
//  Created by Fatih Kadir Akın on 8.02.2026.
//

import SwiftUI
import AppKit
import Speech
import Combine

// MARK: - Preview Panel Controller

class NotchPreviewController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<NotchPreviewContent>?
    private var originalFrame: NSRect?
    private var cursorTimer: AnyCancellable?
    private var trackingSettings: NotchSettings?
    private var animationToken: UInt64 = 0

    func updateAppearance(_ appearance: AppAppearance) {
        let nsAppearance = appearance.nsAppearance
        hostingView?.appearance = nsAppearance
        panel?.appearance = nsAppearance
    }

    func show(settings: NotchSettings) {
        // If panel already exists, refresh appearance and re-show it
        if let panel {
            updateAppearance(settings.appAppearance)
            panel.orderFront(nil)
            return
        }

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let menuBarHeight = screenFrame.maxY - visibleFrame.maxY

        let maxWidth = NotchSettings.maxWidth
        let maxHeight = menuBarHeight + NotchSettings.maxHeight + 40

        let xPosition = screenFrame.midX - maxWidth / 2
        let yPosition = screenFrame.maxY - maxHeight

        let content = NotchPreviewContent(settings: settings, menuBarHeight: menuBarHeight)
        let hostingView = NSHostingView(rootView: content)
        hostingView.appearance = settings.appAppearance.nsAppearance
        self.hostingView = hostingView

        let panel = NSPanel(
            contentRect: NSRect(x: xPosition, y: yPosition, width: maxWidth, height: maxHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.appearance = settings.appAppearance.nsAppearance
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.contentView = hostingView
        panel.orderFront(nil)
        self.panel = panel
    }

    func hide() {
        animationToken &+= 1
        stopCursorTracking()
        panel?.orderOut(nil)
    }

    func dismiss() {
        animationToken &+= 1
        stopCursorTracking()
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
        originalFrame = nil
        trackingSettings = nil
    }

    var isAtCursor: Bool { originalFrame != nil }

    func animateToCursor(settings: NotchSettings) {
        guard let panel else { return }
        if originalFrame == nil {
            originalFrame = panel.frame
        }
        trackingSettings = settings
        animationToken &+= 1
        let expectedToken = animationToken

        // Animate to cursor, then start continuous tracking only if not cancelled
        let target = cursorFrame(for: panel, settings: settings)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            guard let self, self.animationToken == expectedToken, self.panel != nil else { return }
            self.startCursorTracking()
        })
    }

    func animateFromCursor() {
        animationToken &+= 1
        stopCursorTracking()
        guard let panel, let originalFrame else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(originalFrame, display: true)
        }
        self.originalFrame = nil
        self.trackingSettings = nil
    }

    private func cursorFrame(for panel: NSPanel, settings: NotchSettings) -> NSRect {
        let mouse = NSEvent.mouseLocation
        let cursorOffset: CGFloat = 8
        let screenEdgeMargin: CGFloat = 5
        let floatingTopPadding: CGFloat = 14
        let floatingVerticalOffset: CGFloat = 60
        let maxWidth = panel.frame.width
        let notchWidth = settings.notchWidth
        let panelHeight = panel.frame.height
        let visibleHeight = floatingTopPadding + settings.textAreaHeight
        let horizontalInset = (maxWidth - notchWidth) / 2

        var visibleLeft = mouse.x + cursorOffset
        var visibleBottom = mouse.y - visibleHeight

        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
            ?? panel.screen
            ?? NSScreen.main {
            let screenFrame = screen.frame
            let minimumVisibleLeft = screenFrame.minX + screenEdgeMargin
            let maximumVisibleLeft = max(
                minimumVisibleLeft,
                screenFrame.maxX - notchWidth - screenEdgeMargin
            )
            visibleLeft = min(max(visibleLeft, minimumVisibleLeft), maximumVisibleLeft)
            visibleBottom = max(visibleBottom, screenFrame.minY + screenEdgeMargin)
        }

        let panelX = visibleLeft - horizontalInset
        let panelY = visibleBottom - (panelHeight - floatingVerticalOffset - visibleHeight)
        return NSRect(x: panelX, y: panelY, width: maxWidth, height: panelHeight)
    }

    private func startCursorTracking() {
        cursorTimer?.cancel()
        cursorTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updatePreviewPosition()
            }
    }

    private func stopCursorTracking() {
        cursorTimer?.cancel()
        cursorTimer = nil
    }

    private func updatePreviewPosition() {
        guard let panel, let settings = trackingSettings else { return }
        let target = cursorFrame(for: panel, settings: settings)
        panel.setFrame(target, display: false)
    }
}

struct NotchPreviewContent: View {
    @Bindable var settings: NotchSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    let menuBarHeight: CGFloat

    private var darkPalette: DantePalette { DantePalette(colorScheme: .dark) }
    private var floatingPalette: DantePalette { DantePalette(colorScheme: colorScheme) }

    private static let previewText = """
    Good morning, and thank you for being here. [smile]

    Today I want to share a simple idea: clear communication begins when we slow down and connect with one person at a time. The words matter, but the space between them matters too. [pause]

    Take a breath, look into the camera, and let each sentence land. [look at camera] When we speak with calm and purpose, even a complex message becomes easier to understand.

    So keep your pace steady, trust the story, and bring the message home. Thank you for listening. [nod]
    """
    private static let previewWords = splitTextIntoWords(previewText)
    private static let paragraphBreaks = paragraphBreakWordIndices(in: previewText)
    private static let wordTrackingAnchorWordIndex = 18
    private static let highlightedCount = previewWords
        .prefix(wordTrackingAnchorWordIndex)
        .reduce(0) { $0 + $1.count + 1 }

    @State private var previewWordProgress = 0.0
    @State private var previewCycle = 0
    private let scrollTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    // Phase 1: corners flatten (0=concave, 1=squared)
    @State private var cornerPhase: CGFloat = 0
    // Phase 2: detach from top (0=stuck to top, 1=moved down + rounded)
    @State private var offsetPhase: CGFloat = 0
    @State private var modeTransitionTask: Task<Void, Never>?

    private var readingPreviewLayoutIdentity: String {
        [
            settings.listeningMode.rawValue,
            settings.fontFamilyPreset.rawValue,
            settings.fontSizePreset.rawValue,
            settings.showParagraphDividers ? "dividers" : "continuous"
        ].joined(separator: "|")
    }

    private var previewHighlightColor: Color {
        if settings.overlayMode == .floating && colorScheme == .light && settings.fontColorPreset == .white {
            return floatingPalette.textPrimary
        }
        return settings.fontColorPreset.color
    }

    private var previewCueColor: Color {
        if settings.overlayMode == .floating && colorScheme == .light && settings.cueColorPreset == .white {
            return floatingPalette.accent
        }
        return settings.cueColorPreset.color
    }

    var body: some View {
        GeometryReader { geo in
            let topPadding = menuBarHeight * (1 - offsetPhase) + 28 * offsetPhase
            let contentHeight = topPadding + settings.textAreaHeight
            let currentWidth = settings.notchWidth
            let yOffset = 60 * offsetPhase
            let isPinned = settings.overlayMode == .pinned
            let activePalette = isPinned ? darkPalette : floatingPalette
            // Match the compact live notch's text viewport. Its bottom controls
            // and resize handle consume 24 + 8 + 2 + 10 points even though the
            // settings preview deliberately leaves that chrome invisible.
            let pinnedBottomChromeHeight: CGFloat = isPinned ? 44 : 0
            let outerHorizontalPadding: CGFloat = isPinned ? 16 : 0
            let textHorizontalPadding: CGFloat = isPinned ? 12 : 16
            let textTopPadding: CGFloat = isPinned ? 6 : 10

            ZStack(alignment: .top) {
                // Shape: concave corners flatten via cornerPhase, then cross-fade to rounded via offsetPhase
                let isTransparent = settings.overlayTransparency && settings.overlayMode == .pinned
                let islandShape = DynamicIslandShape(
                    topInset: 16 * (1 - cornerPhase),
                    bottomRadius: 18
                )
                ZStack {
                    if isTransparent {
                        NotchBlurView()
                            .clipShape(islandShape)
                        islandShape
                            .fill(darkPalette.sidebarBackground.opacity(1.0 - settings.overlayTransparencyOpacity))
                    } else {
                        islandShape
                            .fill(darkPalette.sidebarBackground)
                    }
                    islandShape
                        .stroke(Color.white.opacity(0.11), lineWidth: 1)
                }
                .opacity(Double(1 - offsetPhase))
                .frame(width: currentWidth, height: contentHeight)

                let floatingShape = RoundedRectangle(cornerRadius: 14, style: .continuous)
                ZStack {
                    if settings.floatingGlassEffect {
                        GlassEffectView()
                        floatingShape
                            .fill(
                                (floatingPalette.isDark ? floatingPalette.canvasBackground : Color.white)
                                    .opacity(settings.glassOpacity)
                            )
                    } else {
                        floatingShape
                            .fill(floatingPalette.canvasBackground)
                    }
                }
                .clipShape(floatingShape)
                .overlay(
                    floatingShape
                        .strokeBorder(floatingPalette.borderStrong, lineWidth: 1)
                )
                .opacity(Double(offsetPhase))
                .frame(width: currentWidth, height: contentHeight)

                VStack(spacing: 0) {
                    HStack {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(activePalette.accent)
                                .frame(width: 6, height: 6)
                            Text("LIVE")
                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(activePalette.textSecondary)
                                .tracking(0.6)
                        }
                        .padding(.leading, 12)

                        Spacer()

                        if settings.showElapsedTime {
                            ElapsedTimeView(fontSize: 11, color: activePalette.textSecondary)
                                .padding(.trailing, 12)
                        }
                    }
                    .frame(height: topPadding)

                    SpeechScrollView(
                        words: Self.previewWords,
                        highlightedCharCount: settings.listeningMode == .wordTracking
                            ? Self.highlightedCount
                            : Self.previewWords.count * 5,
                        font: settings.font,
                        highlightColor: previewHighlightColor,
                        cueColor: previewCueColor,
                        cueUnreadOpacity: settings.cueBrightness.unreadOpacity,
                        cueReadOpacity: settings.cueBrightness.readOpacity,
                        smoothScroll: settings.listeningMode != .wordTracking,
                        smoothWordProgress: previewWordProgress,
                        isListening: true,
                        readingPosition: settings.readingPosition,
                        readingPositionTransitionDuration: reduceMotion ? 0 : 0.28,
                        paragraphBreakBeforeWordIndices: settings.showParagraphDividers
                            ? Self.paragraphBreaks
                            : []
                    )
                    .id("\(readingPreviewLayoutIdentity)|\(previewCycle)")
                    .padding(.horizontal, textHorizontalPadding)
                    .padding(.top, textTopPadding)

                    Color.clear
                        .frame(height: pinnedBottomChromeHeight)
                }
                .padding(.horizontal, outerHorizontalPadding)
                .frame(width: currentWidth, height: contentHeight)
            }
            .frame(width: currentWidth, height: contentHeight, alignment: .top)
            .offset(y: yOffset)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .animation(.easeInOut(duration: 0.15), value: settings.notchWidth)
            .animation(.easeInOut(duration: 0.15), value: settings.textAreaHeight)
        }
        .preferredColorScheme(settings.appAppearance.colorScheme)
        .onChange(of: settings.overlayMode) { _, mode in
            modeTransitionTask?.cancel()
            if mode == .floating {
                // Phase 1: flatten corners while at top
                withAnimation(.easeInOut(duration: 0.25)) {
                    cornerPhase = 1
                }
                // Phase 2: move down + round corners
                modeTransitionTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(250))
                    guard !Task.isCancelled, settings.overlayMode == .floating else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        offsetPhase = 1
                    }
                }
            } else {
                // Reverse Phase 1: move back up to top
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    offsetPhase = 0
                }
                // Reverse Phase 2: restore concave corners
                modeTransitionTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled, settings.overlayMode != .floating else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        cornerPhase = 0
                    }
                }
            }
        }
        .onAppear {
            let isFloating = settings.overlayMode == .floating
            cornerPhase = isFloating ? 1 : 0
            offsetPhase = isFloating ? 1 : 0
        }
        .onDisappear {
            modeTransitionTask?.cancel()
            modeTransitionTask = nil
        }
        .onReceive(scrollTimer) { _ in
            guard settings.listeningMode != .wordTracking else { return }
            let wordCount = Double(Self.previewWords.count)
            let nextProgress = previewWordProgress + settings.scrollSpeed * 0.05
            if nextProgress >= wordCount {
                previewWordProgress = 0
                previewCycle &+= 1
            } else {
                previewWordProgress = nextProgress
            }
        }
        .onChange(of: readingPreviewLayoutIdentity) { _, _ in
            previewWordProgress = 0
            previewCycle &+= 1
        }
    }
}

// MARK: - Modal Sheet Presentation Enum

enum SettingsModalSheet: Identifiable {
    case guidanceTest(SpeechEngine)
    case modelManager
    case acknowledgements

    var id: String {
        switch self {
        case .guidanceTest(let engine): return "guidanceTest.\(engine.rawValue)"
        case .modelManager:             return "modelManager"
        case .acknowledgements:         return "acknowledgements"
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    private static var cachedLocales: [LocalizedSpeechLocale] = []
    private static var cachedLocaleIdentifier: String = ""

    @Bindable var settings: NotchSettings
    @ObservedObject var service = TextreamService.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let isEmbeddedInWindow: Bool
    let enableLivePreview: Bool
    let onClose: (() -> Void)?

    @State private var previewController = NotchPreviewController()
    @State private var previewCursorTask: Task<Void, Never>?
    @State var selectedTab: SettingsTab
    @State private var isSidebarVisible = true
    @State private var searchQuery = ""
    @State private var hoveredTab: SettingsTab?
    @State private var hoveredSearchResultID: String?
    @State private var showLivePreview: Bool
    @State private var showWorkspaceMenu = false
    @State private var library = ScriptLibraryStore.shared
    @FocusState private var isSearchFocused: Bool

    @State var showResetConfirmation = false
    @State var activeSheet: SettingsModalSheet?
    @State var availableMics: [AudioInputDevice] = []
    @State var supportedLocales: [LocalizedSpeechLocale] = []
    @State var availableScreens: [NSScreen] = []
    @State var overlayScreens: [NSScreen] = []
    @State var localIP: String = "localhost"
    @State var directorLocalIP: String = "localhost"
    @State var directorPairingCode: String = ""
    @State var browserRestartNonce: Int = 0
    @State var browserPortDraft: String = ""
    @State var directorPortDraft: String = ""
    @State var obsHostDraft: String = ""
    @State var obsPortDraft: String = ""
    @State var modelStore = LocalSpeechModelStore.shared
    @State var modelDownloads = ModelDownloadManager.shared

    init(
        settings: NotchSettings,
        initialTab: SettingsTab = .general,
        isEmbeddedInWindow: Bool = false,
        enableLivePreview: Bool = true,
        onClose: (() -> Void)? = nil
    ) {
        self.settings = settings
        self.isEmbeddedInWindow = isEmbeddedInWindow
        self.enableLivePreview = enableLivePreview
        self.onClose = onClose
        _selectedTab = State(initialValue: initialTab)
        _showLivePreview = State(initialValue: enableLivePreview)
        _browserPortDraft = State(initialValue: String(settings.browserServerPort))
        _directorPortDraft = State(initialValue: String(settings.directorServerPort))
        _obsHostDraft = State(initialValue: settings.obsHost)
        _obsPortDraft = State(initialValue: String(settings.obsPort))
    }

    var palette: DantePalette {
        DantePalette(colorScheme: colorScheme)
    }

    var isPrompterActive: Bool {
        let recognizer = service.overlayController.speechRecognizer
        return service.overlayController.isShowing
            || service.directorIsReading
            || recognizer.isListening
            || recognizer.isStarting
    }

    var appVersionLabel: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String, !build.isEmpty {
            return "\(short) (\(build))"
        }
        return short
    }

    private var appVersionShort: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private var shouldRenderOverlayPreview: Bool {
        enableLivePreview
            && showLivePreview
            && !isRunningTests
            && !isPrompterActive
            && activeSheet == nil
            && !showResetConfirmation
            && settings.overlayMode != .fullscreen
    }

    private var activeCreatorPresetID: CreatorPresetID {
        library.activeScript?.presetID ?? .youtubeStudio
    }

    // MARK: - Body

    var body: some View {
        let currentSearchResults = isSearching ? SettingsSearchIndex.search(searchQuery) : []
        let matchingTabs = isSearching ? Set(currentSearchResults.map(\.tab)) : Set(SettingsTab.allCases)

        HStack(spacing: 0) {
            if isSidebarVisible {
                settingsSidebar(matchingTabs: matchingTabs, firstResult: currentSearchResults.first)
                    .frame(width: 236)
                    .background(palette.sidebarBackground)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            VStack(spacing: 0) {
                settingsTopBar

                // Rounded inner detail canvas framed cleanly inside the workspace shell
                ZStack {
                    detailPane(searchResults: currentSearchResults)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(palette.settingsCanvasBackground)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: isSidebarVisible ? 12 : 0,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                )
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: isSidebarVisible ? 12 : 0,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                    .strokeBorder(palette.borderSubtle, lineWidth: 1)
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.sidebarBackground)
        }
        .background(palette.sidebarBackground)
        .ignoresSafeArea(.container, edges: isEmbeddedInWindow ? .top : [])
        .background {
            // Hidden Cmd+F shortcut to jump straight into Settings search
            Button("") {
                if !isSidebarVisible {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isSidebarVisible = true
                    }
                }
                Task { @MainActor in
                    isSearchFocused = true
                }
            }
            .keyboardShortcut("f", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
        .sheet(item: $activeSheet, onDismiss: {
            modelStore.refresh()
            ensureLocalModelSelection()
            syncPreviewVisibility()
        }) { sheet in
            Group {
                switch sheet {
                case .guidanceTest(let engine):
                    GuidanceTestSheet(engine: engine)
                case .modelManager:
                    ModelManagerSheet(settings: settings)
                case .acknowledgements:
                    OpenSourceLicensesView()
                }
            }
            .preferredColorScheme(settings.appAppearance.colorScheme)
        }
        .alert("Reset All Settings?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    settings.resetToDefaults()
                    syncNetworkDraftsFromSettings()
                    directorPairingCode = ""
                }
            }
        } message: {
            Text("This will restore every appearance, teleprompter, speech, and studio integration preference to its factory default.")
        }
        .task {
            await loadSupportedLocalesIfNeeded()
        }
        .onAppear {
            refreshMicrophones()
            refreshScreens()
            refreshOverlayScreens()
            let detectedIP = BrowserServer.localIPAddress() ?? "localhost"
            localIP = detectedIP
            directorLocalIP = detectedIP
            directorPairingCode = service.directorServer.pairingCode
            syncNetworkDraftsFromSettings()
            modelStore.refresh()
            ensureLocalModelSelection()
            syncPreviewVisibility()
        }
        .onDisappear {
            previewCursorTask?.cancel()
            previewCursorTask = nil
            previewController.dismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            previewCursorTask?.cancel()
            previewController.dismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            syncPreviewVisibility()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            refreshScreens()
            refreshOverlayScreens()
            if shouldRenderOverlayPreview {
                previewController.dismiss()
                syncPreviewVisibility()
            }
        }
        .onChange(of: showLivePreview) { _, _ in
            syncPreviewVisibility()
        }
        .onChange(of: activeSheet?.id) { _, _ in
            syncPreviewVisibility()
        }
        .onChange(of: showResetConfirmation) { _, _ in
            syncPreviewVisibility()
        }
        .onChange(of: service.directorIsReading) { _, _ in
            syncPreviewVisibility()
        }
        .onChange(of: settings.appAppearance) { _, newAppearance in
            previewController.updateAppearance(newAppearance)
        }
        .onChange(of: settings.speechEngine) { _, engine in
            if engine == .local {
                modelStore.refresh()
                ensureLocalModelSelection()
            }
        }
        .onChange(of: settings.directorModeEnabled) { _, enabled in
            directorPairingCode = enabled ? service.directorServer.pairingCode : ""
        }
        .onChange(of: settings.iCloudSyncEnabled) { _, enabled in
            if enabled {
                Task { await library.syncWithCloud() }
            }
        }
        .onChange(of: settings.followCursorWhenUndocked) { _, follow in
            guard shouldRenderOverlayPreview else { return }
            if follow && settings.overlayMode == .floating {
                previewController.animateToCursor(settings: settings)
            } else {
                previewController.animateFromCursor()
            }
        }
        .onChange(of: settings.overlayMode) { _, mode in
            if mode == .fullscreen || !shouldRenderOverlayPreview {
                previewCursorTask?.cancel()
                previewController.dismiss()
            } else {
                previewController.show(settings: settings)
                if mode == .floating && settings.followCursorWhenUndocked {
                    previewController.animateToCursor(settings: settings)
                } else if previewController.isAtCursor {
                    previewController.animateFromCursor()
                }
            }
        }
        .onExitCommand {
            handleEscape()
        }
    }

    // MARK: - Sidebar

    private func settingsSidebar(
        matchingTabs: Set<SettingsTab>,
        firstResult: SettingsSearchItem?
    ) -> some View {
        VStack(spacing: 0) {
            if isEmbeddedInWindow {
                // Keep clear of macOS window traffic lights in hidden-titlebar mode
                Color.clear
                    .frame(height: 36)
            }

            // Back + Collapse Header (`← Settings    [◫]`)
            HStack(spacing: 6) {
                Button {
                    closeSettings()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(palette.textSecondary)
                        Text("Settings")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Back to Studio (Esc)")
                .accessibilityLabel("Back to Studio")

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isSidebarVisible = false
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Hide Settings Sidebar")
                .accessibilityLabel("Hide Settings Sidebar")
            }
            .padding(.horizontal, 10)
            .padding(.top, isEmbeddedInWindow ? 2 : 12)
            .padding(.bottom, 10)

            // Live Search Field (`Q Search settings`)
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(palette.textTertiary)
                    .accessibilityHidden(true)

                TextField("Search settings", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(palette.textPrimary)
                    .focused($isSearchFocused)
                    .accessibilityLabel("Search settings")
                    .onSubmit {
                        if let first = firstResult {
                            withAnimation(.easeInOut(duration: 0.14)) {
                                selectedTab = first.tab
                                searchQuery = ""
                            }
                        }
                    }

                if isSearching {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11.5))
                            .foregroundStyle(palette.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6.5)
            .background(
                palette.elevatedSurface,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSearchFocused ? palette.accent.opacity(0.6) : palette.borderSubtle, lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            // Categorized Navigation List
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(SettingsSidebarGroup.allCases) { group in
                        let visibleTabs = group.tabs.filter { tab in
                            !isSearching || matchingTabs.contains(tab)
                        }
                        if !visibleTabs.isEmpty {
                            if let title = group.title {
                                Text(title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(palette.textTertiary)
                                    .padding(.horizontal, 12)
                                    .padding(.top, 14)
                                    .padding(.bottom, 5)
                            }

                            ForEach(visibleTabs) { tab in
                                sidebarNavRow(for: tab)
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 16)
            }

            // Bottom Brand & Info Footer
            Rectangle()
                .fill(palette.borderSubtle)
                .frame(height: 1)

            Button {
                showWorkspaceMenu.toggle()
            } label: {
                HStack(spacing: 9) {
                    if let icon = NSImage(named: "AppIcon") {
                        Image(nsImage: icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else {
                        Text("D")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(palette.accent, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(DanteAppLinks.appName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)
                        Text("v\(appVersionShort) · Studio")
                            .font(.system(size: 10.5))
                            .foregroundStyle(palette.textTertiary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(palette.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(DanteAppLinks.appName) menu")
            .popover(isPresented: $showWorkspaceMenu, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    workspaceMenuRow(title: "About & Reset", icon: "info.circle") {
                        showWorkspaceMenu = false
                        searchQuery = ""
                        selectedTab = .about
                    }
                    workspaceMenuRow(title: "Open Source Acknowledgements", icon: "doc.text") {
                        showWorkspaceMenu = false
                        activeSheet = .acknowledgements
                    }
                    workspaceMenuRow(title: "Creator Setup Guide", icon: "sparkles") {
                        showWorkspaceMenu = false
                        closeSettings()
                        NotificationCenter.default.post(name: .openOnboarding, object: nil)
                    }
                    Rectangle()
                        .fill(palette.settingsDivider)
                        .frame(height: 1)
                        .padding(.vertical, 4)
                    workspaceMenuRow(title: "Dante Support", icon: "questionmark.circle") {
                        showWorkspaceMenu = false
                        NSWorkspace.shared.open(DanteAppLinks.supportURL)
                    }
                }
                .padding(6)
                .frame(width: 224)
                .background(palette.elevatedSurface)
            }
        }
    }

    private func workspaceMenuRow(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                    .frame(width: 15)
                Text(title)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sidebarNavRow(for tab: SettingsTab) -> some View {
        let isSelected = !isSearching && selectedTab == tab
        let isHovered = hoveredTab == tab
        let indicator = liveIndicator(for: tab)

        return Button {
            withAnimation(.easeInOut(duration: 0.14)) {
                searchQuery = ""
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12.5, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? palette.textPrimary : palette.textSecondary)
                    .frame(width: 16, alignment: .center)

                Text(tab.label)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? palette.textPrimary : palette.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 4)

                if let indicator {
                    Circle()
                        .fill(indicator.color)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6.5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        isSelected
                            ? palette.settingsSelectedSidebarBackground
                            : (isHovered ? palette.surfaceHover.opacity(0.65) : Color.clear)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredTab = hovering ? tab : (hoveredTab == tab ? nil : hoveredTab)
        }
        .accessibilityLabel(tab.label)
        .accessibilityValue(indicator?.accessibilityLabel ?? "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func liveIndicator(for tab: SettingsTab) -> (color: Color, accessibilityLabel: String)? {
        switch tab {
        case .browser where settings.browserServerEnabled:
            return (palette.statusSuccess, "Active")
        case .director where settings.directorModeEnabled:
            return (palette.statusSuccess, "Active")
        case .obs where settings.obsWebSocketEnabled:
            return service.obsClient.state.isConnected
                ? (palette.statusSuccess, "Connected")
                : (palette.statusWarning, "Connecting")
        default:
            return nil
        }
    }

    // MARK: - Top Bar

    private var settingsTopBar: some View {
        HStack(spacing: 10) {
            if !isSidebarVisible {
                if isEmbeddedInWindow {
                    Spacer().frame(width: 66)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isSidebarVisible = true
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Show Settings Sidebar")
                .accessibilityLabel("Show Settings Sidebar")
            }

            // Active page header pill
            HStack(spacing: 6) {
                Image(systemName: isSearching ? "magnifyingglass" : selectedTab.icon)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                Text(isSearching ? "Search: \(searchQuery)" : selectedTab.label)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if isSearching {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(palette.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5.5)
            .background(
                palette.elevatedSurface,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(palette.borderSubtle, lineWidth: 1)
            )

            Spacer()

            if enableLivePreview && settings.overlayMode != .fullscreen {
                Button {
                    showLivePreview.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(showLivePreview ? palette.accent : palette.textTertiary)
                            .frame(width: 6, height: 6)
                        Text(showLivePreview ? "Live Preview" : "Preview Off")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(showLivePreview ? palette.accent : palette.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        showLivePreview ? palette.accentSubtle : palette.elevatedSurface,
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                showLivePreview ? palette.accent.opacity(0.28) : palette.borderSubtle,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .help("Toggle the live floating teleprompter preview")
                .accessibilityLabel("Live overlay preview")
                .accessibilityValue(showLivePreview ? "On" : "Off")
                .accessibilityAddTraits(showLivePreview ? .isSelected : [])
            }

            Button {
                closeSettings()
            } label: {
                Text("Done")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        palette.elevatedSurface,
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(palette.borderSubtle, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help("Return to Studio (Esc)")
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }

    // MARK: - Detail Pane

    private func detailPane(searchResults: [SettingsSearchItem]) -> some View {
        GeometryReader { geo in
            let horizontalPadding: CGFloat = geo.size.width > 760 ? 40 : 24
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    if isSearching {
                        searchResultsView(results: searchResults)
                    } else {
                        activeTabContent
                    }
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 34)
                .padding(.bottom, 52)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    @ViewBuilder
    private var activeTabContent: some View {
        switch selectedTab {
        case .general:      generalTab
        case .appearance:   appearanceTab
        case .teleprompter: teleprompterTab
        case .reading:      readingTab
        case .guidance:     guidanceTab
        case .models:       modelsTab
        case .external:     externalTab
        case .browser:      browserTab
        case .director:     directorTab
        case .obs:          obsTab
        case .shortcuts:    shortcutsTab
        case .about:        aboutTab
        }
    }

    // MARK: - Search Results View

    private func searchResultsView(results: [SettingsSearchItem]) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 12) {
                SettingsPageHeader(
                    title: "Search results",
                    subtitle: results.isEmpty
                        ? "No settings matched \"\(searchQuery)\"."
                        : "\(results.count) \(results.count == 1 ? "setting" : "settings") matching \"\(searchQuery)\".",
                    palette: palette
                )

                SettingsActionButton("Clear search", icon: "xmark", palette: palette) {
                    searchQuery = ""
                }
            }

            if results.isEmpty {
                SettingsCard(palette: palette) {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(palette.textTertiary)
                        Text("No matching settings")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(palette.textPrimary)
                        Text("Try searching for Theme, Font, Notch, Smart Follow, OBS, Mirror, iCloud, or Reset.")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                    .padding(.horizontal, 20)
                }
            } else {
                SettingsCard(palette: palette) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            SettingsRowDivider(palette: palette)
                        }
                        let isHovered = hoveredSearchResultID == item.id
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedTab = item.tab
                                searchQuery = ""
                            }
                        } label: {
                            SettingsRow(
                                title: item.title,
                                subtitle: "\(item.tab.label) · \(item.section) — \(item.subtitle)",
                                icon: item.icon,
                                iconColor: palette.accent,
                                palette: palette
                            ) {
                                HStack(spacing: 4) {
                                    Text(item.tab.label)
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundStyle(palette.textSecondary)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(palette.textTertiary)
                                }
                                .fixedSize()
                            }
                            .background(isHovered ? palette.surfaceHover.opacity(0.65) : Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            hoveredSearchResultID = hovering
                                ? item.id
                                : (hoveredSearchResultID == item.id ? nil : hoveredSearchResultID)
                        }
                    }
                }
            }
        }
    }

    // MARK: - General Page

    private var generalTab: some View {
        let presetBinding = Binding<CreatorPresetID>(
            get: { activeCreatorPresetID },
            set: { newID in
                let preset = CreatorPreset.preset(for: newID)
                settings.apply(preset: preset)
                library.updateActiveMetadata(targetWPM: preset.targetWPM, presetID: .some(preset.id))
            }
        )
        let checklistVisibleBinding = Binding<Bool>(
            get: { !settings.hasDismissedSetupChecklist },
            set: { settings.hasDismissedSetupChecklist = !$0 }
        )

        return VStack(alignment: .leading, spacing: 26) {
            SettingsPageHeader(
                title: SettingsTab.general.label,
                subtitle: SettingsTab.general.subtitle,
                palette: palette
            )

            SettingsSection(title: "Studio workflow", palette: palette) {
                SettingsRow(
                    title: "Creator format preset",
                    subtitle: "Quickly tune overlay position, pacing, and display behavior for your recording format.",
                    palette: palette
                ) {
                    SettingsMenuPicker(
                        options: CreatorPresetID.allCases,
                        selection: presetBinding,
                        minWidth: 168,
                        accessibilityTitle: "Creator format preset",
                        palette: palette,
                        iconForOption: { CreatorPreset.preset(for: $0).systemImage },
                        labelForOption: { CreatorPreset.preset(for: $0).name }
                    )
                }

                SettingsRowDivider(palette: palette)

                SettingsRow(
                    title: "iCloud Script Sync",
                    subtitle: "Automatically sync scripts and pages across Mac, iPhone, and iPad via iCloud.",
                    palette: palette
                ) {
                    HStack(spacing: 10) {
                        if settings.iCloudSyncEnabled {
                            Button {
                                Task { await library.syncWithCloud() }
                            } label: {
                                SettingsStatusPill(
                                    label: library.syncStatus.label,
                                    color: iCloudStatusColor(library.syncStatus),
                                    palette: palette
                                )
                            }
                            .buttonStyle(.plain)
                            .help("Sync with iCloud now")
                            .accessibilityLabel("iCloud Sync status: \(library.syncStatus.label)")
                        }
                        Toggle("", isOn: $settings.iCloudSyncEnabled)
                            .labelsHidden()
                            .toggleStyle(SettingsSwitchToggleStyle(palette: palette))
                            .accessibilityLabel("iCloud Script Sync")
                    }
                }

                SettingsRowDivider(palette: palette)

                SettingsToggleRow(
                    title: "Keep screen awake",
                    subtitle: "Prevent display and system sleep while the teleprompter is active.",
                    isOn: $settings.keepScreenAwake,
                    palette: palette
                )

                SettingsRowDivider(palette: palette)

                SettingsToggleRow(
                    title: "Show setup checklist",
                    subtitle: "Display onboarding progress steps at the bottom of the studio sidebar.",
                    isOn: checklistVisibleBinding,
                    palette: palette
                )
            }

            SettingsSection(title: "Live session", palette: palette) {
                SettingsToggleRow(
                    title: "Smart Retake recovery",
                    subtitle: "Automatically rewind when you restart a sentence mid-take, or press ← to rewind manually.",
                    isOn: $settings.smartRetakeEnabled,
                    palette: palette
                )

                SettingsRowDivider(palette: palette)

                SettingsToggleRow(
                    title: "Live pacing coach",
                    subtitle: "Show real-time WPM and schedule delta against your script's target pace.",
                    isOn: $settings.showPacingCoach,
                    palette: palette
                )

                SettingsRowDivider(palette: palette)

                SettingsToggleRow(
                    title: "Hide from screen sharing",
                    subtitle: "Keep the teleprompter invisible during video calls and desktop recordings.",
                    isOn: $settings.hideFromScreenShare,
                    palette: palette
                )

                SettingsRowDivider(palette: palette)

                SettingsToggleRow(
                    title: "Show elapsed time",
                    subtitle: "Display a running session timer inside the teleprompter header.",
                    isOn: $settings.showElapsedTime,
                    palette: palette
                )
            }
        }
    }

    // MARK: - Appearance Page

    private var appearanceTab: some View {
        VStack(alignment: .leading, spacing: 26) {
            SettingsPageHeader(
                title: SettingsTab.appearance.label,
                subtitle: SettingsTab.appearance.subtitle,
                palette: palette
            )

            SettingsSection(palette: palette) {
                SettingsRow(
                    title: "Mode",
                    subtitle: "Follow macOS System appearance, or lock Dante to Light or Dark.",
                    palette: palette
                ) {
                    SettingsVisualModePicker(selection: $settings.appAppearance, palette: palette)
                }

                if enableLivePreview && settings.overlayMode != .fullscreen {
                    SettingsRowDivider(palette: palette)

                    SettingsToggleRow(
                        title: "Live overlay preview",
                        subtitle: "Keep a live teleprompter preview visible on screen while customizing settings.",
                        isOn: $showLivePreview,
                        palette: palette
                    )
                }
            }

            SettingsSection(
                title: "Typography",
                subtitle: "Choose the teleprompter font family and point size for comfortable lens reading.",
                palette: palette
            ) {
                SettingsFontCardGrid(
                    selection: $settings.fontFamilyPreset,
                    highlightColor: settings.fontColorPreset.color,
                    palette: palette
                )

                SettingsRowDivider(palette: palette)

                SettingsRow(
                    title: "Text size",
                    subtitle: "Currently \(Int(settings.fontSizePreset.pointSize))pt inside the live teleprompter.",
                    palette: palette
                ) {
                    SettingsSegmentedPill(
                        options: FontSizePreset.allCases,
                        selection: $settings.fontSizePreset,
                        palette: palette,
                        labelForOption: \.label
                    )
                }

                SettingsRowDivider(palette: palette)

                SettingsInlinePrompterPreview(
                    fontFamily: settings.fontFamilyPreset,
                    fontSize: settings.fontSizePreset,
                    highlightColor: settings.fontColorPreset,
                    cueColor: settings.cueColorPreset,
                    cueBrightness: settings.cueBrightness,
                    palette: palette
                )
                .padding(14)
            }

            SettingsSection(
                title: "Colors",
                subtitle: "Customize spoken highlight ink and [bracketed] stage direction visibility.",
                palette: palette
            ) {
                SettingsColorSwatchRow(
                    title: "Highlight color",
                    subtitle: "Active ink color for tracked and highlighted script words.",
                    selection: $settings.fontColorPreset,
                    palette: palette
                )

                SettingsRowDivider(palette: palette)

                SettingsColorSwatchRow(
                    title: "Stage cue color",
                    subtitle: "Accent color for [bracketed] delivery cues and stage directions.",
                    selection: $settings.cueColorPreset,
                    palette: palette
                )

                SettingsRowDivider(palette: palette)

                SettingsRow(
                    title: "Cue brightness",
                    subtitle: "Balance stage cues so they guide delivery without distracting from spoken lines.",
                    palette: palette
                ) {
                    SettingsSegmentedPill(
                        options: CueBrightness.allCases,
                        selection: $settings.cueBrightness,
                        palette: palette,
                        labelForOption: \.label
                    )
                }
            }
        }
    }

    // MARK: - Teleprompter Page

    private var teleprompterTab: some View {
        let widthBinding = Binding<Double>(
            get: { Double(settings.notchWidth) },
            set: { settings.notchWidth = CGFloat($0) }
        )
        let heightBinding = Binding<Double>(
            get: { Double(settings.textAreaHeight) },
            set: { settings.textAreaHeight = CGFloat($0) }
        )

        return VStack(alignment: .leading, spacing: 26) {
            SettingsPageHeader(
                title: SettingsTab.teleprompter.label,
                subtitle: SettingsTab.teleprompter.subtitle,
                palette: palette
            )

            SettingsSection(title: "Overlay mode", palette: palette) {
                SettingsRow(
                    title: "Presentation style",
                    subtitle: settings.overlayMode.description,
                    icon: settings.overlayMode.icon,
                    iconColor: palette.accent,
                    palette: palette
                ) {
                    SettingsMenuPicker(
                        options: OverlayMode.allCases,
                        selection: $settings.overlayMode,
                        minWidth: 164,
                        accessibilityTitle: "Presentation style",
                        palette: palette,
                        iconForOption: \.icon,
                        labelForOption: \.label
                    )
                }

                if settings.overlayMode == .pinned {
                    SettingsRowDivider(palette: palette)

                    SettingsRow(
                        title: "Display placement",
                        subtitle: settings.notchDisplayMode.description,
                        icon: "display",
                        palette: palette
                    ) {
                        SettingsSegmentedPill(
                            options: NotchDisplayMode.allCases,
                            selection: $settings.notchDisplayMode,
                            palette: palette,
                            labelForOption: \.label
                        )
                    }

                    SettingsRowDivider(palette: palette)

                    SettingsToggleRow(
                        title: "Overlay transparency",
                        subtitle: "Makes the notch overlay translucent so desktop content remains visible behind it.",
                        icon: "square.on.square.intersection.dashed",
                        isOn: $settings.overlayTransparency,
                        palette: palette
                    )

                    if settings.overlayTransparency {
                        SettingsRowDivider(palette: palette)

                        SettingsSliderRow(
                            title: "Transparency amount",
                            valueLabel: "\(Int(settings.overlayTransparencyOpacity * 100))%",
                            value: $settings.overlayTransparencyOpacity,
                            range: 0.2...0.95,
                            step: 0.05,
                            leadingLabel: "More transparent",
                            trailingLabel: "Less transparent",
                            palette: palette
                        )
                    }
                }

                if settings.overlayMode == .floating {
                    SettingsRowDivider(palette: palette)

                    SettingsToggleRow(
                        title: "Follow cursor",
                        subtitle: "Keep the floating window anchored smoothly beside your cursor.",
                        icon: "cursorarrow.motionlines",
                        isOn: $settings.followCursorWhenUndocked,
                        palette: palette
                    )

                    SettingsRowDivider(palette: palette)

                    SettingsToggleRow(
                        title: "Glass effect",
                        subtitle: "Use translucent frosted glass backing for the floating teleprompter window.",
                        icon: "sparkles.rectangle.stack",
                        isOn: $settings.floatingGlassEffect,
                        palette: palette
                    )

                    if settings.floatingGlassEffect {
                        SettingsRowDivider(palette: palette)

                        SettingsSliderRow(
                            title: "Glass opacity",
                            valueLabel: "\(Int(settings.glassOpacity * 100))%",
                            value: $settings.glassOpacity,
                            range: 0.0...0.6,
                            step: 0.05,
                            leadingLabel: "Clearer",
                            trailingLabel: "More solid",
                            palette: palette
                        )
                    }
                }

                if settings.overlayMode == .fullscreen {
                    SettingsRowDivider(palette: palette)

                    SettingsRow(
                        title: "Exit shortcut",
                        subtitle: "Press Escape at any time to dismiss the fullscreen teleprompter.",
                        icon: "escape",
                        palette: palette
                    ) {
                        DanteKeycapBadge(label: "Esc", palette: palette)
                    }
                }
            }

            if (settings.overlayMode == .pinned && settings.notchDisplayMode == .fixedDisplay)
                || settings.overlayMode == .fullscreen {
                SettingsSection(
                    title: "Target display",
                    subtitle: settings.overlayMode == .fullscreen
                        ? "Select which screen displays the fullscreen teleprompter."
                        : "Select the display where the notch teleprompter remains pinned.",
                    palette: palette,
                    trailing: {
                        Button {
                            refreshOverlayScreens()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 10.5, weight: .medium))
                                Text("Refresh")
                                    .font(.system(size: 11.5, weight: .medium))
                            }
                            .foregroundStyle(palette.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Refresh displays")
                    }
                ) {
                    displaySelectionRows(
                        screens: overlayScreens,
                        selectedID: settings.overlayMode == .fullscreen
                            ? $settings.fullscreenScreenID
                            : $settings.pinnedScreenID,
                        emptyMessage: "No displays found. Click Refresh to rescan connected screens."
                    )
                }
            }

            SettingsSection(
                title: "Dimensions",
                subtitle: "Adjust the reading window geometry beneath your Mac's camera lens.",
                palette: palette
            ) {
                SettingsSliderRow(
                    title: "Width",
                    subtitle: "Horizontal width of the teleprompter viewport.",
                    valueLabel: "\(Int(settings.notchWidth)) px",
                    value: widthBinding,
                    range: Double(NotchSettings.minWidth)...Double(NotchSettings.maxWidth),
                    step: 10,
                    leadingLabel: "\(Int(NotchSettings.minWidth)) px",
                    trailingLabel: "\(Int(NotchSettings.maxWidth)) px",
                    palette: palette
                )

                SettingsRowDivider(palette: palette)

                SettingsSliderRow(
                    title: "Text area height",
                    subtitle: "Vertical height available for script lines inside the overlay.",
                    valueLabel: "\(Int(settings.textAreaHeight)) px",
                    value: heightBinding,
                    range: Double(NotchSettings.minHeight)...Double(NotchSettings.maxHeight),
                    step: 10,
                    leadingLabel: "\(Int(NotchSettings.minHeight)) px",
                    trailingLabel: "\(Int(NotchSettings.maxHeight)) px",
                    palette: palette
                )
            }

            SettingsSection(title: "Privacy & pagination", palette: palette) {
                SettingsToggleRow(
                    title: "Hide from screen sharing",
                    subtitle: "Exclude the teleprompter overlay from screen recordings and video calls.",
                    icon: "eye.slash",
                    isOn: $settings.hideFromScreenShare,
                    palette: palette
                )

                SettingsRowDivider(palette: palette)

                SettingsToggleRow(
                    title: "Show elapsed time",
                    subtitle: "Show a live timer while reading.",
                    icon: "timer",
                    isOn: $settings.showElapsedTime,
                    palette: palette
                )

                SettingsRowDivider(palette: palette)

                SettingsToggleRow(
                    title: "Auto next page",
                    subtitle: "Automatically advance to the next script page after a brief countdown.",
                    icon: "doc.on.doc",
                    isOn: $settings.autoNextPage,
                    palette: palette
                )

                if settings.autoNextPage {
                    SettingsRowDivider(palette: palette)

                    SettingsRow(
                        title: "Page advance countdown",
                        subtitle: "Wait duration before flipping to the next page automatically.",
                        palette: palette
                    ) {
                        SettingsSegmentedPill(
                            options: AutoAdvanceDelayOption.allCases,
                            selection: Binding(
                                get: { AutoAdvanceDelayOption(seconds: settings.autoNextPageDelay) },
                                set: { settings.autoNextPageDelay = $0.rawValue }
                            ),
                            palette: palette,
                            labelForOption: \.label
                        )
                    }
                }
            }
        }
    }

    // MARK: - Reading Page

    private var readingTab: some View {
        VStack(alignment: .leading, spacing: 26) {
            SettingsPageHeader(
                title: SettingsTab.reading.label,
                subtitle: SettingsTab.reading.subtitle,
                palette: palette
            )

            SettingsSection(title: "Layout & alignment", palette: palette) {
                SettingsRow(
                    title: "Reading position",
                    subtitle: "Near Top keeps the active line closest to the camera lens with the previous line visible above.",
                    icon: "text.alignleft",
                    palette: palette
                ) {
                    SettingsSegmentedPill(
                        options: ReadingPosition.allCases,
                        selection: $settings.readingPosition,
                        palette: palette,
                        labelForOption: \.label
                    )
                }

                SettingsRowDivider(palette: palette)

                SettingsToggleRow(
                    title: "Show paragraph dividers",
                    subtitle: "Separate source line breaks with extra breathing space and three centered dots.",
                    icon: "line.3.horizontal",
                    isOn: $settings.showParagraphDividers,
                    palette: palette
                )

                SettingsRowDivider(palette: palette)

                SettingsToggleRow(
                    title: "Show last spoken words",
                    subtitle: "Display recently recognized words at the bottom while using Word Tracking.",
                    icon: "captions.bubble",
                    isOn: $settings.showLastSpokenWords,
                    palette: palette
                )
            }

            SettingsSection(title: "Smart coaching & recovery", palette: palette) {
                SettingsToggleRow(
                    title: "Smart Retake recovery",
                    subtitle: "Automatically rewind when you restart a sentence mid-take, or press ← manually.",
                    icon: "arrow.counterclockwise",
                    isOn: $settings.smartRetakeEnabled,
                    palette: palette
                )

                SettingsRowDivider(palette: palette)

                SettingsToggleRow(
                    title: "Live pacing coach",
                    subtitle: "Track live words-per-minute and schedule delta against your script's target pace.",
                    icon: "gauge.with.needle",
                    isOn: $settings.showPacingCoach,
                    palette: palette
                )

                SettingsRowDivider(palette: palette)

                SettingsToggleRow(
                    title: "Keep screen awake",
                    subtitle: "Prevent macOS from dimming or sleeping the display during long reads.",
                    icon: "sun.max",
                    isOn: $settings.keepScreenAwake,
                    palette: palette
                )
            }
        }
    }

    // MARK: - Actions & Helpers

    private func handleEscape() {
        if isSearching {
            searchQuery = ""
        } else {
            closeSettings()
        }
    }

    func closeSettings() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func syncNetworkDraftsFromSettings() {
        browserPortDraft = String(settings.browserServerPort)
        directorPortDraft = String(settings.directorServerPort)
        obsHostDraft = settings.obsHost
        obsPortDraft = String(settings.obsPort)
    }

    private func ensureLocalModelSelection() {
        guard !modelStore.models.isEmpty else { return }
        if settings.localModelFilename.isEmpty || modelStore.model(named: settings.localModelFilename) == nil {
            settings.localModelFilename = modelStore.models[0].filename
        }
    }

    private func iCloudStatusColor(_ status: ScriptSyncStatus) -> Color {
        switch status {
        case .idle:        return palette.statusSuccess
        case .syncing:     return palette.accent
        case .offline:     return palette.statusWarning
        case .unavailable: return palette.textTertiary
        case .disabled:    return palette.textTertiary
        }
    }

    private func syncPreviewVisibility() {
        previewCursorTask?.cancel()
        previewCursorTask = nil
        guard shouldRenderOverlayPreview else {
            previewController.dismiss()
            return
        }
        previewController.show(settings: settings)
        if settings.followCursorWhenUndocked && settings.overlayMode == .floating {
            previewCursorTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled, shouldRenderOverlayPreview,
                      settings.followCursorWhenUndocked,
                      settings.overlayMode == .floating else { return }
                previewController.animateToCursor(settings: settings)
            }
        }
    }

    private func loadSupportedLocalesIfNeeded() async {
        let currentIdentifier = Locale.current.identifier
        if !Self.cachedLocales.isEmpty && Self.cachedLocaleIdentifier == currentIdentifier {
            supportedLocales = Self.cachedLocales
            return
        }
        let locales = await Task.detached(priority: .userInitiated) {
            let current = Locale.current
            return SFSpeechRecognizer.supportedLocales()
                .map { locale in
                    LocalizedSpeechLocale(
                        id: locale.identifier,
                        displayName: current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
                    )
                }
                .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        }.value
        guard !Task.isCancelled else { return }
        Self.cachedLocales = locales
        Self.cachedLocaleIdentifier = currentIdentifier
        supportedLocales = locales
    }

    func refreshMicrophones() {
        availableMics = AudioInputDevice.allInputDevices()
    }

    func refreshScreens() {
        availableScreens = NSScreen.screens.filter { $0 != NSScreen.main }
        if let first = availableScreens.first,
           !availableScreens.contains(where: { $0.displayID == settings.externalScreenID }) {
            settings.externalScreenID = first.displayID
        }
    }

    func refreshOverlayScreens() {
        overlayScreens = NSScreen.screens
        if let main = NSScreen.main ?? overlayScreens.first {
            if !overlayScreens.contains(where: { $0.displayID == settings.pinnedScreenID }) {
                settings.pinnedScreenID = main.displayID
            }
            if !overlayScreens.contains(where: { $0.displayID == settings.fullscreenScreenID }) {
                settings.fullscreenScreenID = main.displayID
            }
        }
    }
}

// MARK: - Auto Advance Delay Option

private enum AutoAdvanceDelayOption: Int, CaseIterable, Identifiable {
    case instant = 0
    case oneSecond = 1
    case threeSeconds = 3
    case fiveSeconds = 5

    var id: Int { rawValue }

    init(seconds: Int) {
        self = AutoAdvanceDelayOption(rawValue: seconds) ?? .threeSeconds
    }

    var label: String {
        switch self {
        case .instant:      return "Instant"
        case .oneSecond:    return "1s"
        case .threeSeconds: return "3s"
        case .fiveSeconds:  return "5s"
        }
    }
}


