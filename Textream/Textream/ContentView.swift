//
//  ContentView.swift
//  Dante for Creators
//

import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject private var service = TextreamService.shared
    @State private var library = ScriptLibraryStore.shared
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
    @State private var showWPMPopover = false
    @State private var renamingScriptID: UUID?
    @State private var renameDraft: String = ""
    @State private var languageSuggestion: SpeechLanguageSuggestion?
    @State private var ignoredLanguageIdentifier: String?
    @State private var languageDetectionTask: Task<Void, Never>?
    @FocusState private var isTextFocused: Bool

    private var languageLabel: String {
        let locale = NotchSettings.shared.speechLocale
        return Locale.current.localizedString(forIdentifier: locale)
            ?? locale
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

    private func scheduleLanguageDetection(for text: String) {
        languageDetectionTask?.cancel()
        languageSuggestion = nil
        let pageIndex = service.currentPageIndex
        let localeIdentifier = NotchSettings.shared.speechLocale

        languageDetectionTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 2_500_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled,
                  service.currentPageIndex == pageIndex,
                  service.currentPageText == text,
                  NotchSettings.shared.speechLocale == localeIdentifier else { return }

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

    private func languageSuggestionBanner(_ suggestion: SpeechLanguageSuggestion) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "character.bubble.fill")
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("This text looks like \(suggestion.languageName).")
                    .font(.system(size: 12, weight: .semibold))
                Text("Speech is currently set to \(languageLabel).")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button("Use \(suggestion.languageName)") {
                if isRecording {
                    stopRecording()
                }
                ignoredLanguageIdentifier = nil
                languageSuggestion = nil
                NotchSettings.shared.speechLocale = suggestion.localeIdentifier
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .help("Switch speech recognition to \(suggestion.localeName)")

            Button {
                ignoredLanguageIdentifier = suggestion.detectedLanguageIdentifier
                withAnimation(.easeInOut(duration: 0.2)) {
                    languageSuggestion = nil
                }
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Dismiss language suggestion")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.accentColor.opacity(0.2))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var waveformPill: some View {
        let pill = AudioWaveformView(levels: dictation.audioLevels, color: .red)
            .frame(height: 34)
            .frame(maxWidth: 240)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            pill
                .glassEffect(in: .capsule)
        } else {
            pill
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        }
        #else
        pill
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        #endif
    }

    @State private var highlightClearTimer: Timer?

    // Segment tracking: each recognition session is a "segment"
    @State private var segmentStart: Int = 0
    @State private var segmentLength: Int = 0
    @State private var segmentNeedsSeparator: Bool = false
    // How many chars of the raw recognition result to skip (already committed before cursor move)
    @State private var spokenSkipOffset: Int = 0
    @State private var lastRawSpokenLength: Int = 0

    private func beginNewSegment() {
        let pageIndex = service.currentPageIndex
        guard pageIndex < service.pages.count else { return }
        let text = service.pages[pageIndex]
        let caret = min(editorCaretPosition, text.count)

        // Skip everything already recognized up to this point
        spokenSkipOffset = lastRawSpokenLength

        // Check if we need a space before the new segment
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
            // Recognition restarted — raw counter resets to 0
            lastRawSpokenLength = 0
            spokenSkipOffset = 0
            beginNewSegment()
        }

        dictation.onTextUpdate = { [self] spokenText in
            lastRawSpokenLength = spokenText.count

            // Only use the portion after the skip offset
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

            // Remove the old segment text
            let safeStart = min(segmentStart, text.count)
            let removeStart = text.index(text.startIndex, offsetBy: safeStart)
            let safeLen = min(segmentLength, text.count - safeStart)
            let removeEnd = text.index(removeStart, offsetBy: safeLen)
            text.removeSubrange(removeStart..<removeEnd)

            // Build the new segment content
            let sep = segmentNeedsSeparator ? " " : ""
            let newSegment = sep + effectiveText
            text.insert(contentsOf: newSegment, at: text.index(text.startIndex, offsetBy: min(segmentStart, text.count)))

            let prevLen = segmentLength
            segmentLength = newSegment.count
            service.pages[pageIndex] = text
            library.updateActivePages(service.pages)

            // Highlight only the newly added characters
            let newChars = segmentLength - prevLen
            if newChars > 0 {
                let highlightStart = segmentStart + prevLen
                dictationHighlightRange = NSRange(location: highlightStart, length: newChars)
            }

            // Move caret to end of segment
            dictationCaretPosition = segmentStart + segmentLength

            // Clear highlight after 1s of silence
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

    private var creatorMetricsBar: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(CreatorPreset.all) { preset in
                    Button {
                        applyPreset(preset)
                    } label: {
                        Label(
                            "\(preset.name) (\(preset.targetWPM) WPM)",
                            systemImage: preset.systemImage
                        )
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: activePreset?.systemImage ?? "sparkles")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text(activePreset?.name ?? "Creator Preset")
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.12), in: Capsule())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Apply a Creator Format Preset")

            Spacer(minLength: 8)

            if let targetSeconds = activePreset?.targetDurationSeconds,
               activeMetrics.spokenWordCount > 0 {
                let isWithinTarget = activeMetrics.estimatedSeconds <= targetSeconds
                Label(
                    isWithinTarget
                        ? "Fits \(targetSeconds)s"
                        : "+\(activeMetrics.estimatedSeconds - targetSeconds)s over \(targetSeconds)s",
                    systemImage: isWithinTarget ? "checkmark.circle.fill" : "clock.badge.exclamationmark"
                )
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(isWithinTarget ? .green : .orange)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background((isWithinTarget ? Color.green : Color.orange).opacity(0.12), in: Capsule())
            }

            Button {
                showWPMPopover.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text(activeMetrics.summaryLabel)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                    Text("· \(activeMetrics.targetWPM) WPM")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05), in: Capsule())
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
                            .foregroundStyle(Color.accentColor)
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
            .help("Adjust target speaking pace (WPM) for read-time estimates")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            creatorMetricsBar

            if let languageSuggestion {
                languageSuggestionBanner(languageSuggestion)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            ZStack {
                HighlightingTextEditor(
                    text: currentText,
                    font: .systemFont(ofSize: 16, weight: .regular).rounded,
                    highlightRange: dictationHighlightRange,
                    caretPosition: $dictationCaretPosition,
                    editorCaretPosition: $editorCaretPosition
                )
                .onChange(of: editorCaretPosition) { _, newPos in
                    guard isRecording else { return }
                    // If caret moved away from end of current segment, user clicked elsewhere
                    let segmentEnd = segmentStart + segmentLength
                    if newPos != segmentEnd {
                        beginNewSegment()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white, location: 0.03),
                            .init(color: .white, location: 0.93),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Bottom bar
                VStack {
                    Spacer()
                    ZStack {
                        // Waveform pill centered to full width
                        if dictation.isRecording {
                            waveformPill
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }

                        // Buttons pinned right
                        HStack(spacing: 10) {
                            Spacer()

                            Button {
                                if isRecording {
                                    stopRecording()
                                } else {
                                    startRecording()
                                }
                            } label: {
                                Group {
                                    if dictation.isStarting {
                                        ProgressView()
                                            .controlSize(.small)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: isRecording ? "pause.fill" : "mic.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                }
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(isRecording ? Color.orange : Color.red)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                            }
                            .buttonStyle(.plain)
                            .disabled(isRunning)
                            .opacity(isRunning ? 0.4 : 1)

                            Button {
                                if isRunning {
                                    stop()
                                } else {
                                    run()
                                }
                            } label: {
                                Image(systemName: isRunning ? "stop.fill" : "play.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(isRunning ? Color.red : Color.accentColor)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                            }
                            .buttonStyle(.plain)
                            .disabled((!isRunning && !hasAnyContent) || isRecording)
                            .opacity((!hasAnyContent && !isRunning) || isRecording ? 0.4 : 1)
                        }
                    }
                    .padding(20)
                }
                .animation(.easeInOut(duration: 0.25), value: isRecording)

                // Drop zone overlay — sits on top so TextEditor doesn't steal the drop
                if isDroppingPresentation {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(Color.accentColor)
                        Text("Drop PowerPoint (.pptx) file")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                        Text("For Keynote or Google Slides,\nexport as PPTX first.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .background(Color.accentColor.opacity(0.08).clipShape(RoundedRectangle(cornerRadius: 12)))
                    )
                    .padding(8)
                }

                // Invisible drop target covering entire window
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
        }
    }

    private var directorOverlay: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "megaphone.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)

            Text("Director Mode")
                .font(.system(size: 22, weight: .bold))

            Text(service.directorIsReading ? "Reading from director…" : "Waiting for director to send script…")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            if let ip = BrowserServer.localIPAddress() {
                let url = "http://\(ip):\(NotchSettings.shared.directorServerPort)"

                if let qrImage = generateDirectorQRCode(from: url) {
                    Image(nsImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                HStack(spacing: 8) {
                    Text(url)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.accentColor)
                        .textSelection(.enabled)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                showSettings = true
            } label: {
                Text("Open Settings")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    var body: some View {
        Group {
            if NotchSettings.shared.directorModeEnabled {
                directorOverlay
            } else {
                NavigationSplitView {
                    creatorSidebar
                } detail: {
                    mainContent
                }
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 300)
            }
        }
        .alert(dropAlertTitle, isPresented: Binding(get: { dropError != nil }, set: { if !$0 { dropError = nil } })) {
            Button("OK") { dropError = nil }
        } message: {
            Text(dropError ?? "")
        }
        .alert("Microphone or Speech Unavailable", isPresented: Binding(
            get: { dictation.error != nil },
            set: { if !$0 { dictation.error = nil } }
        )) {
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
        .alert("Rename Script", isPresented: Binding(
            get: { renamingScriptID != nil },
            set: { if !$0 { renamingScriptID = nil } }
        )) {
            TextField("Script title", text: $renameDraft)
            Button("Cancel", role: .cancel) { renamingScriptID = nil }
            Button("Rename") {
                if let id = renamingScriptID {
                    library.renameScript(id: id, to: renameDraft)
                }
                renamingScriptID = nil
            }
        }
        .frame(minWidth: 520, minHeight: 340)
        .background(.ultraThinMaterial)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 8) {
                    Button {
                        if isRecording {
                            stopRecording()
                        }
                        service.openFile()
                    } label: {
                        HStack(spacing: 4) {
                            if service.currentFileURL != nil && service.pages != service.savedPages {
                                Circle()
                                    .fill(.orange)
                                    .frame(width: 6, height: 6)
                            }
                            Text(service.currentFileURL?.deletingPathExtension().lastPathComponent
                                 ?? activeScript?.displayTitle
                                 ?? "Untitled")
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)

                    // Add page button in toolbar
                    Button {
                        if isRecording {
                            stopRecording()
                        }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            service.pages.append("")
                            service.currentPageIndex = service.pages.count - 1
                            library.updateActivePages(service.pages)
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Page")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showSettings = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: NotchSettings.shared.listeningMode.icon)
                                .font(.system(size: 10))
                            Text(NotchSettings.shared.listeningMode == .wordTracking
                                 ? languageLabel
                                 : NotchSettings.shared.listeningMode.label)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: NotchSettings.shared)
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .sheet(isPresented: $showOnboarding) {
            CreatorOnboardingView { preset in
                applyPreset(preset)
            }
        }
        .onChange(of: showSettings) { _, isShowing in
            if isShowing && isRecording {
                stopRecording()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .startPrompter)) { _ in
            // ⌘↩ from the editor. The main window hides while the prompter runs,
            // so this only ever starts; Esc stops from the overlay.
            guard !showSettings, !showOnboarding, !isRunning, !isRecording, hasAnyContent else { return }
            isTextFocused = false
            run()
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
            // Sync button state when app is re-activated (e.g. dock click)
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
        .onChange(of: NotchSettings.shared.speechLocale) { _, _ in
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
        .onAppear {
            // Load active library script into the editor when starting fresh
            if service.currentFileURL == nil,
               service.pages.count == 1 && service.pages[0].isEmpty,
               let active = library.activeScript {
                service.pages = active.pages
                service.savedPages = active.pages
                service.currentPageIndex = 0
            }
            // Sync button state with overlay
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
    }

    // MARK: - Creator Script Library & Page Sidebar

    private func pagePreview(_ page: String) -> String {
        let trimmed = page.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Empty" }
        let words = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let preview = words.prefix(5).joined(separator: " ")
        return preview.count > 26 ? String(preview.prefix(26)) + "…" : preview
    }

    private var creatorSidebar: some View {
        VStack(spacing: 0) {
            // Search scripts field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("Search scripts…", text: $library.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !library.searchQuery.isEmpty {
                    Button {
                        library.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 6)

            List {
                Section {
                    ForEach(library.filteredScripts) { script in
                        let isSelected = script.id == library.selectedScriptID
                        Button {
                            selectScript(script)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 5) {
                                    if script.isPinned {
                                        Image(systemName: "pin.fill")
                                            .font(.system(size: 9))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                    Text(script.displayTitle)
                                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                                        .foregroundStyle(isSelected ? Color.accentColor : .primary)
                                        .lineLimit(1)
                                    Spacer(minLength: 4)
                                }
                                Text(script.metrics.summaryLabel)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                isSelected
                                    ? Color.accentColor.opacity(0.14)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
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
                    }
                } header: {
                    HStack {
                        Text("Scripts")
                        Spacer()
                        Button {
                            createNewScript()
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .help("New Script (⌘N)")
                    }
                }

                Section("Pages (\(service.pages.count))") {
                    ForEach(Array(service.pages.enumerated()), id: \.offset) { index, page in
                        let isCurrent = service.currentPageIndex == index
                        Button {
                            if isRecording {
                                stopRecording()
                            }
                            withAnimation(.easeInOut(duration: 0.15)) {
                                service.currentPageIndex = index
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(isCurrent ? .white : .primary)
                                    .frame(width: 20, height: 20)
                                    .background(
                                        service.readPages.contains(index)
                                            ? Color.green.opacity(0.35)
                                            : (isCurrent ? Color.accentColor : Color.primary.opacity(0.1))
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 5))

                                Text(pagePreview(page))
                                    .font(.system(size: 12))
                                    .foregroundStyle(isCurrent ? .primary : .secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 2)
                            .padding(.horizontal, 4)
                            .background(
                                isCurrent ? Color.primary.opacity(0.06) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                        }
                        .buttonStyle(.plain)
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
            .listStyle(.sidebar)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Button {
                    createNewScript()
                } label: {
                    Label("New Script", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    if isRecording {
                        stopRecording()
                    }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        service.pages.append("")
                        service.currentPageIndex = service.pages.count - 1
                        library.updateActivePages(service.pages)
                    }
                } label: {
                    Label("Page", systemImage: "doc.badge.plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Actions

    private func applyPreset(_ preset: CreatorPreset) {
        NotchSettings.shared.apply(preset: preset)
        library.updateActiveMetadata(targetWPM: preset.targetWPM, presetID: .some(preset.id))
    }

    private func createNewScript() {
        if isRecording {
            stopRecording()
        }
        let created = library.createScript(
            title: "Untitled Script",
            pages: [""],
            presetID: activePreset?.id
        )
        loadScriptIntoEditor(created)
    }

    private func selectScript(_ script: DanteScript) {
        guard script.id != library.selectedScriptID else { return }
        if isRecording {
            stopRecording()
        }
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
        if isRecording {
            stopRecording()
        }
        library.deleteScript(id: script.id)
        if let active = library.activeScript {
            loadScriptIntoEditor(active)
        }
    }

    private func removePage(at index: Int) {
        guard service.pages.count > 1 else { return }
        if isRecording {
            stopRecording()
        }
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
        // Resign text editor focus before hiding the window to avoid ViewBridge crashes
        isTextFocused = false
        service.onOverlayDismissed = { [self] in
            isRunning = false
            service.readPages.removeAll()
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
        service.readPages.removeAll()
        // If the current page is empty, find the first non-empty page
        let currentText = service.currentPageText.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentText.isEmpty {
            if let firstNonEmpty = service.pages.firstIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                service.currentPageIndex = firstNonEmpty
            }
        }
        service.readCurrentPage()
        isRunning = true
    }

    @State private var isImporting = false

    private func handlePresentationDrop(url: URL) {
        guard service.confirmDiscardIfNeeded() else { return }
        if isRecording {
            stopRecording()
        }
        isImporting = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let notes = try PresentationNotesExtractor.extractNotes(from: url)
                let title = url.deletingPathExtension().lastPathComponent
                DispatchQueue.main.async {
                    let imported = library.createScript(title: title, pages: notes, presetID: .keynoteLive)
                    loadScriptIntoEditor(imported)
                    service.rememberDocumentURL(url)
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
    @Environment(\.dismiss) private var dismiss
    @State private var showAcknowledgements = false

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String, !build.isEmpty {
            return "\(short) (\(build))"
        }
        return short
    }

    var body: some View {
        VStack(spacing: 16) {
            // App icon
            if let icon = NSImage(named: "AppIcon") {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }

            // App name & version
            VStack(spacing: 4) {
                Text(DanteAppLinks.appName)
                    .font(.system(size: 20, weight: .bold))
                Text("Version \(appVersion)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            // Description
            Text("A studio-grade teleprompter with Smart Follow speech tracking, on-device AI models, and creator workflow presets.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            // Links
            HStack(spacing: 10) {
                Link(destination: DanteAppLinks.privacyURL) {
                    HStack(spacing: 5) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Privacy")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Capsule())
                }

                Link(destination: DanteAppLinks.supportURL) {
                    HStack(spacing: 5) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Support")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Capsule())
                }

                Button {
                    showAcknowledgements = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Licenses")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Divider().padding(.horizontal, 20)

            VStack(spacing: 4) {
                Text(DanteAppLinks.companyName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(DanteAppLinks.copyrightNotice)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Button("OK") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 360)
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showAcknowledgements) {
            OpenSourceLicensesView()
        }
    }
}

#Preview {
    ContentView()
}
