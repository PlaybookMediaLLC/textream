import Foundation
import SwiftUI

struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable var model: AppModel
    @State private var floatingActionOverlayHeight = RootFloatingActionLayout.fallbackOverlayHeight
    @State private var isShowingExpandedScriptEditor = false
    @State private var isInlineScriptEditorFocused = false
    @State private var languageSuggestions = SpeechLanguageSuggestionCoordinator()
    @State private var foldLayout: PromptFoldLayout?

    private var palette: DantePalette {
        DantePalette(colorScheme: colorScheme)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppBackground()
                    .ignoresSafeArea()

                if let foldLayout {
                    foldedLayout(foldLayout)
                } else if geometry.size.width > 700 || geometry.size.width > geometry.size.height * 1.35 {
                    VStack(spacing: 16) {
                        header

                        HStack(spacing: 16) {
                            editorPanel
                            landscapeSetupColumn
                                .frame(width: min(390, geometry.size.width * 0.42))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                } else {
                    ZStack(alignment: .bottom) {
                        ScrollView {
                            VStack(spacing: 16) {
                                header

                                editorPanel
                                    .frame(height: max(280, min(380, geometry.size.height * 0.42)))

                                setupPanel
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, 12)
                            .padding(
                                .bottom,
                                RootFloatingActionLayout.contentBottomClearance(
                                    measuredOverlayHeight: floatingActionOverlayHeight
                                )
                            )
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .scrollIndicators(.hidden)

                        floatingStartAction(
                            horizontalPadding: 18,
                            bottomPadding: RootFloatingActionLayout.portraitBottomPadding
                        )
                    }
                }
            }
        }
        .background {
            // Measure the fold with the keyboard ignored. On a tabletop the
            // keyboard rises over the half on the table; measuring the space
            // above it would lose the split, and the script editor with its
            // focus, in the middle of typing.
            GeometryReader { proxy in
                let fold = PromptFoldLayout.current(in: proxy)
                Color.clear
                    .onChange(of: fold, initial: true) { _, fold in
                        foldLayout = fold
                    }
            }
            .ignoresSafeArea(.keyboard)
        }
        .sheet(isPresented: $model.isShowingSettings) {
            SettingsView(model: model)
        }
        .sheet(isPresented: $model.isShowingLibrary) {
            ScriptLibrarySheet(model: model)
        }
        .sheet(isPresented: $model.isShowingQuickComposer) {
            QuickComposerSheet(model: model)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $model.isShowingOnboarding) {
            CreatorOnboardingSheet(model: model)
        }
        .sheet(isPresented: $model.isShowingStudioRemote) {
            StudioRemoteView()
                .preferredColorScheme(model.appAppearance.colorScheme)
        }
        .fullScreenCover(isPresented: $isShowingExpandedScriptEditor) {
            ExpandedScriptEditor(
                model: model,
                languageSuggestions: languageSuggestions
            )
        }
        .fullScreenCover(isPresented: $model.isShowingSession) {
            PromptSessionView(
                configuration: model.configuration(),
                onScrollSpeedChanged: { speed in
                    model.scrollSpeed = speed
                },
                onDisplaySettingsChanged: { settings in
                    model.mirrorEnabled = settings.mirrorEnabled
                    model.mirrorAxis = settings.mirrorAxis
                    model.readingPosition = settings.readingPosition
                    model.fontSize = settings.fontSize
                }
            )
            .preferredColorScheme(.dark)
        }
        .onChange(of: model.sessionMode) { _, mode in
            if mode == .record { model.cameraEnabled = true }
        }
        .onChange(of: model.script) { _, script in
            languageSuggestions.schedule(
                text: script,
                currentLocaleIdentifier: model.speechLocaleIdentifier
            )
        }
        .onChange(of: model.speechLocaleIdentifier) { _, localeIdentifier in
            guard !isShowingExpandedScriptEditor else { return }
            languageSuggestions.reset(
                text: model.script,
                currentLocaleIdentifier: localeIdentifier
            )
        }
        .onAppear {
            let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            if !isRunningTests && !model.hasCompletedOnboarding {
                model.isShowingOnboarding = true
            }
        }
    }

    private var header: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        headerLogo
                        headerTitle
                        Spacer(minLength: 6)
                        studioRemoteButton
                        themeToggleButton
                        quickComposeButton
                        libraryButton
                        settingsButton
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Smart teleprompter")
                            .font(.system(size: 17, weight: .medium))
                            .lineLimit(1)
                        Text("for creators")
                            .font(.system(size: 17, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Smart teleprompter for creators")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 10) {
                    headerLogo

                    VStack(alignment: .leading, spacing: 1) {
                        headerTitle
                        headerTagline
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 8)
                    studioRemoteButton
                    themeToggleButton
                    quickComposeButton
                    libraryButton
                    settingsButton
                }
            }
        }
    }

    private var studioRemoteButton: some View {
        Button {
            isInlineScriptEditorFocused = false
            model.isShowingStudioRemote = true
        } label: {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 34, height: 34)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(palette.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mac Studio Remote")
        .accessibilityIdentifier("studioRemoteButton")
    }

    private var headerLogo: some View {
        Image("DanteLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 40, height: 40)
            .accessibilityHidden(true)
    }

    private var headerTitle: some View {
        Text(DanteAppLinks.shortName)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(palette.textPrimary)
    }

    private var headerTagline: some View {
        Text("Studio Teleprompter")
            .font(.caption.weight(.medium))
            .foregroundStyle(palette.textTertiary)
    }

    private var themeToggleButton: some View {
        Button {
            withAnimation(.snappy) {
                model.appAppearance = model.appAppearance.next()
            }
        } label: {
            Image(systemName: model.appAppearance.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.textSecondary)
                .frame(width: 34, height: 34)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(palette.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Theme: \(model.appAppearance.label)")
        .accessibilityIdentifier("themeToggleButton")
    }

    private var quickComposeButton: some View {
        Button {
            isInlineScriptEditorFocused = false
            model.isShowingQuickComposer = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
                .frame(width: 34, height: 34)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(palette.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Quick compose script")
        .accessibilityIdentifier("quickComposeButton")
    }

    private var libraryButton: some View {
        Button {
            isInlineScriptEditorFocused = false
            model.isShowingLibrary = true
        } label: {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.textSecondary)
                .frame(width: 34, height: 34)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(palette.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Script library")
        .accessibilityIdentifier("scriptLibraryButton")
    }

    private var settingsButton: some View {
        Button {
            model.isShowingSettings = true
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.textSecondary)
                .frame(width: 34, height: 34)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(palette.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
        .accessibilityIdentifier("settingsButton")
    }

    private var editorPanel: some View {
        let metrics = model.scriptMetrics
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    isInlineScriptEditorFocused = false
                    model.isShowingLibrary = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(palette.accent)
                        Text(model.activeScript?.displayTitle ?? "Script")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(palette.textTertiary)
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(metrics.summaryLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(palette.textSecondary)
                    if let targetSeconds = model.activePreset?.targetDurationSeconds,
                       metrics.spokenWordCount > 0 {
                        let fits = metrics.estimatedSeconds <= targetSeconds
                        Text(fits ? "Fits \(targetSeconds)s" : "+\(metrics.estimatedSeconds - targetSeconds)s over \(targetSeconds)s")
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(fits ? palette.statusSuccess : palette.statusWarning)
                    }
                }

                Button {
                    isInlineScriptEditorFocused = false
                    Task { @MainActor in
                        await Task.yield()
                        isShowingExpandedScriptEditor = true
                    }
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(palette.surfaceHover, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(palette.borderSubtle, lineWidth: 1)
                        )
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit script full screen")
                .accessibilityIdentifier("expandScriptEditorButton")
            }

            Rectangle()
                .fill(palette.borderSubtle)
                .frame(height: 1)

            if let suggestion = languageSuggestions.suggestion {
                LanguageSuggestionBanner(
                    suggestion: suggestion,
                    currentLocaleIdentifier: model.speechLocaleIdentifier,
                    onUse: useSuggestedLanguage,
                    onDismiss: { languageSuggestions.dismiss(suggestion) }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            BracketHighlightingTextEditor(
                text: $model.script,
                isFocused: $isInlineScriptEditorFocused,
                accessibilityLabel: "Script",
                accessibilityIdentifier: "scriptEditor"
            )
            .padding(2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text("Use [brackets] for stage directions. Dante displays them but skips them while following your voice.")
                .font(.caption2)
                .foregroundStyle(palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
    }

    private func useSuggestedLanguage() {
        guard let localeIdentifier = languageSuggestions.useSuggestedLocale() else { return }
        model.speechLocaleIdentifier = localeIdentifier
    }

    private var setupPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("CREATOR PRESET")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(palette.textTertiary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CreatorPreset.all) { preset in
                            let isSelected = model.activePreset?.id == preset.id
                            Button {
                                withAnimation(.snappy) {
                                    model.apply(preset: preset)
                                }
                            } label: {
                                Label(preset.shortName, systemImage: preset.systemImage)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(isSelected ? palette.accent : palette.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        isSelected ? palette.accentSubtle : palette.canvasBackground,
                                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(isSelected ? palette.accent.opacity(0.65) : palette.borderSubtle, lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("creatorPreset_\(preset.id.rawValue)")
                        }
                    }
                }
            }

            Picker("Session", selection: $model.sessionMode) {
                ForEach(SessionMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("sessionModePicker")

            VStack(alignment: .leading, spacing: 8) {
                Text("FOLLOW MODE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(palette.textTertiary)

                HStack(spacing: 8) {
                    ForEach(FollowMode.allCases) { mode in
                        followModeButton(mode)
                    }
                }

                Text(model.followMode.description)
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if model.followMode != .wordTracking {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Speed")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.textPrimary)
                        Spacer()
                        Text(String(format: "%.1f words/s", model.scrollSpeed))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(palette.textSecondary)
                    }
                    Slider(value: $model.scrollSpeed, in: 0.5...8, step: 0.5)
                        .tint(palette.accent)
                        .accessibilityIdentifier("scrollSpeedSlider")
                }
            }

            Toggle(isOn: $model.cameraEnabled) {
                Label(
                    model.sessionMode == .record ? "Camera required for recording" : "Show camera behind prompt",
                    systemImage: model.cameraEnabled ? "camera.fill" : "camera"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(palette.textPrimary)
            }
            .disabled(model.sessionMode == .record)
            .tint(palette.accent)
            .accessibilityIdentifier("cameraToggle")

            if model.sessionMode == .read {
                Rectangle().fill(palette.borderSubtle).frame(height: 1)

                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $model.mirrorEnabled) {
                        Label(
                            "Mirror in landscape",
                            systemImage: "arrow.left.and.right"
                        )
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(palette.textPrimary)
                    }
                    .tint(palette.accent)
                    .accessibilityIdentifier("mirrorModeToggle")

                    if model.mirrorEnabled {
                        Picker("Mirror axis", selection: $model.mirrorAxis) {
                            ForEach(PromptMirrorAxis.allCases) { axis in
                                Text(axis.label).tag(axis)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("mirrorAxisPicker")

                        Text("Rotate to landscape for teleprompter glass. Prompt controls stay readable on the device.")
                            .font(.caption)
                            .foregroundStyle(palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
    }

    /// On a partially folded display the script takes the upright half of a
    /// tabletop, or the leading half of a book, and the setup controls with
    /// the start button take the other half, so nothing straddles the hinge.
    private func foldedLayout(_ fold: PromptFoldLayout) -> some View {
        ZStack {
            VStack(spacing: 18) {
                header
                editorPanel
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(width: fold.stage.width, height: fold.stage.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            landscapeSetupColumn
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .frame(width: fold.controls.width, height: fold.controls.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        // The panes keep their halves while the keyboard covers the lower one.
        .ignoresSafeArea(.keyboard)
    }

    private var landscapeSetupColumn: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                setupPanel
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(
                        .bottom,
                        RootFloatingActionLayout.contentBottomClearance(
                            measuredOverlayHeight: floatingActionOverlayHeight
                        )
                    )
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)

            floatingStartAction(
                horizontalPadding: 20,
                bottomPadding: RootFloatingActionLayout.landscapeBottomPadding
            )
        }
        .frame(maxHeight: .infinity)
    }

    private func floatingStartAction(horizontalPadding: CGFloat, bottomPadding: CGFloat) -> some View {
        startSessionButton
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, bottomPadding)
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                floatingActionOverlayHeight = height
            }
    }

    private var startSessionButton: some View {
        Button {
            model.startSession()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: startSessionIcon)
                    .font(.subheadline.weight(.semibold))
                Text(startSessionLabel)
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: RootFloatingActionLayout.buttonMinimumHeight)
            .background(
                palette.accent,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .shadow(color: palette.accent.opacity(palette.isDark ? 0.35 : 0.22), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!model.canStart)
        .opacity(model.canStart ? 1 : 0.45)
        .accessibilityIdentifier("startSessionButton")
    }

    private var startSessionIcon: String {
        if model.sessionMode == .record { return "camera.fill" }
        return model.mirrorEnabled ? "arrow.left.and.right" : "play.fill"
    }

    private var startSessionLabel: String {
        if model.sessionMode == .record { return "Open Camera" }
        return model.mirrorEnabled ? "Start Mirror Mode" : "Start Prompter"
    }

    private func followModeButton(_ mode: FollowMode) -> some View {
        let isSelected = model.followMode == mode
        return Button {
            withAnimation(.snappy) { model.followMode = mode }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: mode.icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(mode.shortLabel)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(isSelected ? .white : palette.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                isSelected ? palette.accent : palette.canvasBackground,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? palette.accent : palette.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("followMode_\(mode.rawValue)")
    }
}

enum RootFloatingActionLayout {
    static let buttonMinimumHeight: CGFloat = 48
    static let clearanceGap: CGFloat = 12
    static let portraitBottomPadding: CGFloat = 12
    static let landscapeBottomPadding: CGFloat = 18
    static let fallbackOverlayHeight: CGFloat = buttonMinimumHeight + landscapeBottomPadding

    static func contentBottomClearance(measuredOverlayHeight: CGFloat) -> CGFloat {
        max(measuredOverlayHeight, fallbackOverlayHeight) + clearanceGap
    }
}

private struct ExpandedScriptEditor: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AppModel
    let languageSuggestions: SpeechLanguageSuggestionCoordinator
    @State private var draft: String
    @State private var isEditorFocused = false

    private var palette: DantePalette {
        DantePalette(colorScheme: colorScheme)
    }

    init(model: AppModel, languageSuggestions: SpeechLanguageSuggestionCoordinator) {
        self.model = model
        self.languageSuggestions = languageSuggestions
        _draft = State(initialValue: model.script)
    }

    var body: some View {
        let metrics = ScriptMetrics.measure(text: draft, wordsPerMinute: model.activeTargetWPM)
        NavigationStack {
            VStack(spacing: 8) {
                HStack {
                    Text(metrics.summaryLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(palette.textSecondary)
                    Spacer()
                    Text("\(model.activeTargetWPM) WPM")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(palette.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)

                Rectangle()
                    .fill(palette.borderSubtle)
                    .frame(height: 1)

                if let suggestion = languageSuggestions.suggestion {
                    LanguageSuggestionBanner(
                        suggestion: suggestion,
                        currentLocaleIdentifier: model.speechLocaleIdentifier,
                        onUse: useSuggestedLanguage,
                        onDismiss: { languageSuggestions.dismiss(suggestion) }
                    )
                    .padding(.horizontal, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                BracketHighlightingTextEditor(
                    text: $draft,
                    isFocused: $isEditorFocused,
                    accessibilityLabel: "Script",
                    accessibilityIdentifier: "expandedScriptEditor"
                )
                .scrollDismissesKeyboard(.interactively)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(AppBackground().ignoresSafeArea())
            .navigationTitle(model.activeScript?.displayTitle ?? "Edit Script")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitDraft()
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isEditorFocused = false }
                }
            }
        }
        .preferredColorScheme(model.appAppearance.colorScheme)
        .task {
            await Task.yield()
            isEditorFocused = true
        }
        .onChange(of: draft, initial: true) { _, text in
            languageSuggestions.schedule(
                text: text,
                currentLocaleIdentifier: model.speechLocaleIdentifier
            )
        }
        .onChange(of: model.speechLocaleIdentifier) { _, localeIdentifier in
            languageSuggestions.reset(
                text: draft,
                currentLocaleIdentifier: localeIdentifier
            )
        }
        .onDisappear { commitDraft() }
    }

    private func commitDraft() {
        guard model.script != draft else { return }
        model.script = draft
    }

    private func useSuggestedLanguage() {
        guard let localeIdentifier = languageSuggestions.useSuggestedLocale() else { return }
        model.speechLocaleIdentifier = localeIdentifier
    }
}

private struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        DantePalette(colorScheme: colorScheme).canvasBackground
    }
}
