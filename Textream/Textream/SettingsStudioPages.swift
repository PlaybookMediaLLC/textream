//
//  SettingsStudioPages.swift
//  Dante for Creators
//
//  Voice & AI, Studio, Integrations, and System pages for SettingsView.
//

import AppKit
import CoreImage.CIFilterBuiltins
import Speech
import SwiftUI

extension SettingsView {

    // MARK: - Guidance Page

    var guidanceTab: some View {
        VStack(alignment: .leading, spacing: 26) {
            SettingsPageHeader(
                title: SettingsTab.guidance.label,
                subtitle: SettingsTab.guidance.subtitle,
                palette: palette
            )

            SettingsSection(title: "Tracking mode", palette: palette) {
                SettingsRow(
                    title: "Listening mode",
                    subtitle: settings.listeningMode.description,
                    icon: settings.listeningMode.icon,
                    iconColor: palette.accent,
                    palette: palette
                ) {
                    SettingsMenuPicker(
                        options: ListeningMode.allCases,
                        selection: $settings.listeningMode,
                        minWidth: 152,
                        palette: palette,
                        iconForOption: \.icon,
                        labelForOption: \.label
                    )
                }

                if settings.listeningMode == .wordTracking {
                    SettingsRowDivider(palette: palette)

                    SettingsRow(
                        title: "Smart Follow active",
                        subtitle: "Automatically recovers when you ad-lib, pause, skip a paragraph, or re-read a line.",
                        icon: "waveform.path.ecg",
                        iconColor: palette.accent,
                        palette: palette
                    ) {
                        SettingsStatusPill(
                            label: "Active",
                            color: palette.statusSuccess,
                            palette: palette
                        )
                    }

                    SettingsRowDivider(palette: palette)

                    SettingsRow(
                        title: "Speech engine",
                        subtitle: settings.speechEngine.description,
                        icon: settings.speechEngine == .local ? "cpu" : "apple.logo",
                        palette: palette
                    ) {
                        SettingsSegmentedPill(
                            options: SpeechEngine.allCases,
                            selection: $settings.speechEngine,
                            palette: palette,
                            labelForOption: \.label
                        )
                    }

                    if settings.speechEngine == .local {
                        SettingsRowDivider(palette: palette)
                        localModelSummaryRow
                    }

                    SettingsRowDivider(palette: palette)

                    SettingsRow(
                        title: "Speech language",
                        subtitle: settings.speechEngine == .local
                            ? "Used when supported by the selected model; some local models auto-detect language."
                            : "Select the spoken language for macOS speech recognition.",
                        icon: "globe",
                        palette: palette
                    ) {
                        if supportedLocales.isEmpty {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Menu {
                                ForEach(supportedLocales, id: \.identifier) { locale in
                                    Button {
                                        settings.speechLocale = locale.identifier
                                    } label: {
                                        HStack {
                                            Text(localizedLocaleName(locale.identifier))
                                            if settings.speechLocale == locale.identifier {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Text(localizedLocaleName(settings.speechLocale))
                                        .font(.system(size: 12.5, weight: .medium))
                                        .foregroundStyle(palette.textPrimary)
                                        .lineLimit(1)
                                    Spacer(minLength: 4)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 9.5, weight: .semibold))
                                        .foregroundStyle(palette.textTertiary)
                                }
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .frame(minWidth: 168, maxWidth: 220)
                                .background(
                                    palette.elevatedSurface,
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(palette.borderSubtle, lineWidth: 1)
                                )
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .fixedSize()
                        }
                    }

                    SettingsRowDivider(palette: palette)

                    SettingsRow(
                        title: "Test guidance",
                        subtitle: isPrompterActive
                            ? "Stop the active teleprompter before running a live transcription test."
                            : "Listen with \(settings.speechEngine.label) and verify live transcription accuracy.",
                        icon: "play.circle",
                        palette: palette
                    ) {
                        SettingsActionButton(
                            "Test Guidance",
                            icon: "waveform",
                            isDisabled: isPrompterActive,
                            palette: palette
                        ) {
                            guidanceTestEngine = settings.speechEngine
                        }
                    }
                }
            }

            if settings.listeningMode != .classic || settings.listeningMode != .wordTracking {
                SettingsSection(
                    title: "Audio & pacing",
                    palette: palette,
                    trailing: {
                        if settings.listeningMode != .classic {
                            Button {
                                refreshMicrophones()
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
                        }
                    }
                ) {
                    if settings.listeningMode != .classic {
                        SettingsRow(
                            title: "Microphone input",
                            subtitle: "Select the audio device used for voice tracking and dictation.",
                            icon: "mic",
                            palette: palette
                        ) {
                            Menu {
                                Button {
                                    settings.selectedMicUID = ""
                                } label: {
                                    HStack {
                                        Text("System Default")
                                        if settings.selectedMicUID.isEmpty {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                ForEach(availableMics) { mic in
                                    Button {
                                        settings.selectedMicUID = mic.uid
                                    } label: {
                                        HStack {
                                            Text(mic.name)
                                            if settings.selectedMicUID == mic.uid {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Text(selectedMicrophoneName)
                                        .font(.system(size: 12.5, weight: .medium))
                                        .foregroundStyle(palette.textPrimary)
                                        .lineLimit(1)
                                    Spacer(minLength: 4)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 9.5, weight: .semibold))
                                        .foregroundStyle(palette.textTertiary)
                                }
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .frame(minWidth: 168, maxWidth: 220)
                                .background(
                                    palette.elevatedSurface,
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(palette.borderSubtle, lineWidth: 1)
                                )
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .fixedSize()
                        }
                    }

                    if settings.listeningMode != .classic && settings.listeningMode != .wordTracking {
                        SettingsRowDivider(palette: palette)
                    }

                    if settings.listeningMode != .wordTracking {
                        SettingsSliderRow(
                            title: "Scroll speed",
                            subtitle: "Target reading rate used in Classic and Voice-Activated scrolling modes.",
                            valueLabel: String(format: "%.1f wps", settings.scrollSpeed),
                            value: $settings.scrollSpeed,
                            range: 0.5...8.0,
                            step: 0.5,
                            leadingLabel: "Slower (0.5 wps)",
                            trailingLabel: "Faster (8.0 wps)",
                            palette: palette
                        )
                    }
                }
            }
        }
    }

    private var localModelSummaryRow: some View {
        let installed = modelStore.model(named: settings.localModelFilename)
        let subtitle = installed.map { "\($0.displayName) (\($0.sizeMB) MB) — runs 100% on this Mac." }
            ?? "No local model installed yet. Open Speech Models to download from Hugging Face."
        return SettingsRow(
            title: "Active local model",
            subtitle: subtitle,
            icon: "cpu",
            iconColor: installed != nil ? palette.statusSuccess : palette.textTertiary,
            palette: palette
        ) {
            HStack(spacing: 8) {
                if !modelStore.models.isEmpty {
                    Menu {
                        ForEach(modelStore.models) { model in
                            Button {
                                settings.localModelFilename = model.filename
                            } label: {
                                HStack {
                                    Text("\(model.displayName) — \(model.sizeMB) MB")
                                    if settings.localModelFilename == model.filename {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(installed?.displayName ?? "Select model")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(palette.textPrimary)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(palette.textTertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5.5)
                        .background(
                            palette.elevatedSurface,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(palette.borderSubtle, lineWidth: 1)
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }

                SettingsActionButton("Manage…", palette: palette) {
                    showModelManager = true
                }
            }
        }
    }

    // MARK: - Speech Models Page

    var modelsTab: some View {
        let activeDownloads = modelDownloads.states.values.filter(\.isActive).count
        let firstFailure = modelDownloads.states
            .sorted { $0.key < $1.key }
            .compactMap { if case .failed(let msg) = $0.value { return msg } else { return nil } }
            .first
        let installedModel = modelStore.model(named: settings.localModelFilename)

        return VStack(alignment: .leading, spacing: 26) {
            SettingsPageHeader(
                title: SettingsTab.models.label,
                subtitle: SettingsTab.models.subtitle,
                palette: palette
            )

            SettingsSection(title: "Engine & hardware", palette: palette) {
                SettingsRow(
                    title: "Use on-device speech engine",
                    subtitle: "Switch Word Tracking to run locally on your Mac so audio never leaves this device.",
                    icon: "lock.shield",
                    iconColor: settings.speechEngine == .local ? palette.accent : palette.textSecondary,
                    palette: palette
                ) {
                    SettingsSegmentedPill(
                        options: SpeechEngine.allCases,
                        selection: $settings.speechEngine,
                        palette: palette,
                        labelForOption: \.label
                    )
                }

                SettingsRowDivider(palette: palette)

                SettingsRow(
                    title: LocalSpeechHardwareAdvisor.isAppleSilicon ? "Apple Silicon ready" : "Intel Mac detected",
                    subtitle: LocalSpeechHardwareAdvisor.isAppleSilicon
                        ? "\(LocalSpeechHardwareAdvisor.physicalMemoryGB) GB unified memory available for Metal-accelerated streaming models."
                        : "\(LocalSpeechHardwareAdvisor.physicalMemoryGB) GB RAM. Lightweight models and Apple Speech are recommended for real-time tracking.",
                    icon: "cpu",
                    iconColor: LocalSpeechHardwareAdvisor.isAppleSilicon ? palette.statusSuccess : palette.statusWarning,
                    palette: palette
                ) {
                    SettingsStatusPill(
                        label: LocalSpeechHardwareAdvisor.isAppleSilicon ? "Metal GPU" : "CPU Mode",
                        color: LocalSpeechHardwareAdvisor.isAppleSilicon ? palette.statusSuccess : palette.statusWarning,
                        palette: palette
                    )
                }
            }

            SettingsSection(
                title: "Installed models",
                subtitle: "Models marked Live stream words as you speak. All weights stay locally on disk.",
                palette: palette,
                trailing: {
                    SettingsActionButton("Manage Models…", icon: "plus", isProminent: true, palette: palette) {
                        showModelManager = true
                    }
                }
            ) {
                SettingsRow(
                    title: "Model status",
                    subtitle: localModelStatusText(
                        activeDownloads: activeDownloads,
                        failure: firstFailure,
                        installed: installedModel
                    ),
                    icon: "waveform",
                    iconColor: localModelStatusColor(
                        activeDownloads: activeDownloads,
                        failure: firstFailure,
                        installed: installedModel
                    ),
                    palette: palette
                ) {
                    SettingsStatusPill(
                        label: activeDownloads > 0
                            ? "\(Int(modelDownloads.overallProgress * 100))%"
                            : (installedModel != nil ? "Ready" : "Not installed"),
                        color: localModelStatusColor(
                            activeDownloads: activeDownloads,
                            failure: firstFailure,
                            installed: installedModel
                        ),
                        palette: palette
                    )
                }

                if !modelStore.models.isEmpty {
                    SettingsRowDivider(palette: palette)

                    SettingsRow(
                        title: "Selected model",
                        subtitle: "Active model loaded when Word Tracking starts in Local Model mode.",
                        palette: palette
                    ) {
                        Menu {
                            ForEach(modelStore.models) { model in
                                Button {
                                    settings.localModelFilename = model.filename
                                } label: {
                                    HStack {
                                        Text("\(model.displayName) — \(model.sizeMB) MB")
                                        if settings.localModelFilename == model.filename {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(installedModel?.displayName ?? "Select a model…")
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundStyle(palette.textPrimary)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(palette.textTertiary)
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .frame(minWidth: 180)
                            .background(
                                palette.elevatedSurface,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(palette.borderSubtle, lineWidth: 1)
                            )
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                    }
                }

                SettingsRowDivider(palette: palette)

                SettingsRow(
                    title: "Local models folder",
                    subtitle: "Inspect downloaded GGUF weights or drag custom model files directly into Finder.",
                    icon: "folder",
                    palette: palette
                ) {
                    SettingsActionButton("Reveal in Finder", icon: "arrow.up.forward", palette: palette) {
                        modelStore.revealInFinder()
                    }
                }
            }
        }
    }

    // MARK: - External Display Page

    var externalTab: some View {
        VStack(alignment: .leading, spacing: 26) {
            SettingsPageHeader(
                title: SettingsTab.external.label,
                subtitle: SettingsTab.external.subtitle,
                palette: palette
            )

            SettingsSection(title: "Output mode", palette: palette) {
                SettingsRow(
                    title: "External display output",
                    subtitle: settings.externalDisplayMode.description,
                    icon: "rectangle.on.rectangle",
                    iconColor: settings.externalDisplayMode == .off ? palette.textSecondary : palette.accent,
                    palette: palette
                ) {
                    SettingsSegmentedPill(
                        options: ExternalDisplayMode.allCases,
                        selection: $settings.externalDisplayMode,
                        palette: palette,
                        labelForOption: \.label
                    )
                }

                if settings.externalDisplayMode == .mirror {
                    SettingsRowDivider(palette: palette)

                    SettingsRow(
                        title: "Mirror axis",
                        subtitle: settings.mirrorAxis.description,
                        icon: "arrow.left.and.right",
                        palette: palette
                    ) {
                        SettingsSegmentedPill(
                            options: MirrorAxis.allCases,
                            selection: $settings.mirrorAxis,
                            palette: palette,
                            labelForOption: \.label
                        )
                    }
                }
            }

            if settings.externalDisplayMode != .off {
                SettingsSection(
                    title: "Target display",
                    subtitle: "Choose the monitor or Sidecar iPad that receives the external teleprompter feed.",
                    palette: palette,
                    trailing: {
                        Button {
                            refreshScreens()
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
                    }
                ) {
                    displaySelectionRows(
                        screens: availableScreens,
                        selectedID: $settings.externalScreenID,
                        emptyMessage: "No external displays detected. Connect a monitor or enable Sidecar, then click Refresh."
                    )
                }
            }
        }
    }

    // MARK: - Remote Page

    var browserTab: some View {
        let remoteURL = "http://\(localIP):\(settings.browserServerPort)"

        return VStack(alignment: .leading, spacing: 26) {
            SettingsPageHeader(
                title: SettingsTab.browser.label,
                subtitle: SettingsTab.browser.subtitle,
                palette: palette
            )

            SettingsSection(title: "LAN browser server", palette: palette) {
                SettingsRow(
                    title: "Enable remote connection",
                    subtitle: "Serve a live web teleprompter to any iPhone, Android, tablet, or TV browser on the same Wi-Fi.",
                    icon: "antenna.radiowaves.left.and.right",
                    iconColor: settings.browserServerEnabled ? palette.accent : palette.textSecondary,
                    palette: palette
                ) {
                    HStack(spacing: 12) {
                        SettingsStatusPill(
                            label: settings.browserServerEnabled ? "Running" : "Off",
                            color: settings.browserServerEnabled ? palette.statusSuccess : palette.textTertiary,
                            palette: palette
                        )
                        Toggle("", isOn: $settings.browserServerEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(palette.accent)
                            .controlSize(.small)
                            .accessibilityLabel("Enable remote connection")
                    }
                }

                if settings.browserServerEnabled {
                    SettingsRowDivider(palette: palette)

                    SettingsRow(
                        title: "Remote URL",
                        subtitle: "Open this address on any device connected to your local Wi-Fi network.",
                        icon: "link",
                        palette: palette
                    ) {
                        SettingsCopyablePill(value: remoteURL, accentValue: true, palette: palette)
                    }

                    SettingsRowDivider(palette: palette)

                    qrCodeSectionRow(
                        title: "Quick scan QR code",
                        subtitle: "Point your phone or tablet camera at the QR code to launch the remote prompt instantly.",
                        url: remoteURL
                    )
                }
            }

            if settings.browserServerEnabled {
                SettingsSection(
                    title: "Network port",
                    subtitle: "Uses port \(settings.browserServerPort) (HTTP) and \(settings.browserServerPort + 1) (WebSocket).",
                    palette: palette
                ) {
                    SettingsRow(
                        title: "Server port",
                        subtitle: "Restart the server after changing the port number (1024–65534).",
                        icon: "network",
                        palette: palette
                    ) {
                        HStack(spacing: 8) {
                            TextField("Port", text: Binding(
                                get: { String(settings.browserServerPort) },
                                set: { str in
                                    if let val = UInt16(str), val >= 1024, val < UInt16.max {
                                        settings.browserServerPort = val
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12.5, design: .monospaced))
                            .frame(width: 82)

                            SettingsActionButton("Restart", icon: "arrow.clockwise", palette: palette) {
                                TextreamService.shared.browserServer.stop()
                                TextreamService.shared.browserServer.start()
                                localIP = BrowserServer.localIPAddress() ?? "localhost"
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Director Page

    var directorTab: some View {
        let directorURL = "http://\(directorLocalIP):\(settings.directorServerPort)"
        let pairingCode = TextreamService.shared.directorServer.pairingCode
        let obsState = TextreamService.shared.obsClient.state

        return VStack(alignment: .leading, spacing: 26) {
            SettingsPageHeader(
                title: SettingsTab.director.label,
                subtitle: SettingsTab.director.subtitle,
                palette: palette
            )

            SettingsSection(title: "Director server", palette: palette) {
                SettingsRow(
                    title: "Enable Director Mode",
                    subtitle: "Locks the local script editor so a remote director or iOS Studio Remote can drive live reads.",
                    icon: "megaphone",
                    iconColor: settings.directorModeEnabled ? palette.accent : palette.textSecondary,
                    palette: palette
                ) {
                    HStack(spacing: 12) {
                        SettingsStatusPill(
                            label: settings.directorModeEnabled ? "Active" : "Off",
                            color: settings.directorModeEnabled ? palette.statusSuccess : palette.textTertiary,
                            palette: palette
                        )
                        Toggle("", isOn: $settings.directorModeEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(palette.accent)
                            .controlSize(.small)
                            .accessibilityLabel("Enable Director Mode")
                    }
                }

                if settings.directorModeEnabled {
                    SettingsRowDivider(palette: palette)

                    SettingsRow(
                        title: "Director web URL",
                        subtitle: "Word Tracking is automatically enabled whenever a remote director starts reading.",
                        icon: "globe",
                        palette: palette
                    ) {
                        SettingsCopyablePill(value: directorURL, accentValue: true, palette: palette)
                    }

                    if !pairingCode.isEmpty {
                        SettingsRowDivider(palette: palette)

                        SettingsRow(
                            title: "iOS Studio Remote PIN",
                            subtitle: "Discovered automatically via Bonjour on the same Wi-Fi network.",
                            icon: "iphone.radiowaves.left.and.right",
                            iconColor: palette.accent,
                            palette: palette
                        ) {
                            SettingsCopyablePill(value: pairingCode, accentValue: true, palette: palette)
                        }
                    }

                    SettingsRowDivider(palette: palette)

                    qrCodeSectionRow(
                        title: "Director QR code",
                        subtitle: "Scan from an iPad or producer laptop to open the Director control panel.",
                        url: directorURL
                    )
                }
            }

            if settings.directorModeEnabled {
                SettingsSection(
                    title: "Network port",
                    subtitle: "Uses port \(settings.directorServerPort) (HTTP) and \(settings.directorServerPort + 1) (WebSocket).",
                    palette: palette
                ) {
                    SettingsRow(
                        title: "Director server port",
                        subtitle: "Restart the Director server after updating the port (1024–65534).",
                        icon: "network",
                        palette: palette
                    ) {
                        HStack(spacing: 8) {
                            TextField("Port", text: Binding(
                                get: { String(settings.directorServerPort) },
                                set: { str in
                                    if let val = UInt16(str), val >= 1024, val < UInt16.max {
                                        settings.directorServerPort = val
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12.5, design: .monospaced))
                            .frame(width: 82)

                            SettingsActionButton("Restart", icon: "arrow.clockwise", palette: palette) {
                                TextreamService.shared.directorServer.stop()
                                TextreamService.shared.directorServer.start()
                                directorLocalIP = BrowserServer.localIPAddress() ?? "localhost"
                            }
                        }
                    }
                }
            }

            SettingsSection(
                title: "Studio integrations",
                subtitle: "Connect broadcast automation and hands-free hardware controllers.",
                palette: palette
            ) {
                SettingsRow(
                    title: "OBS Studio WebSocket v5",
                    subtitle: "Auto-start and stop your teleprompter in sync with OBS recordings.",
                    icon: "record.circle",
                    iconColor: obsState.isConnected ? palette.statusSuccess : palette.textSecondary,
                    palette: palette
                ) {
                    HStack(spacing: 10) {
                        SettingsStatusPill(
                            label: obsState.label,
                            color: obsStateColor(obsState),
                            palette: palette
                        )
                        SettingsActionButton("Configure", palette: palette) {
                            selectedTab = .obs
                        }
                    }
                }

                SettingsRowDivider(palette: palette)

                SettingsRow(
                    title: "Clickers, foot pedals & controllers",
                    subtitle: "Presenter clickers, USB/Bluetooth foot pedals, and gamepads work automatically.",
                    icon: "gamecontroller",
                    palette: palette
                ) {
                    SettingsActionButton("View Bindings", palette: palette) {
                        selectedTab = .shortcuts
                    }
                }
            }
        }
    }

    // MARK: - OBS Studio Page

    var obsTab: some View {
        let obsState = TextreamService.shared.obsClient.state

        return VStack(alignment: .leading, spacing: 26) {
            SettingsPageHeader(
                title: SettingsTab.obs.label,
                subtitle: SettingsTab.obs.subtitle,
                palette: palette
            )

            SettingsSection(title: "WebSocket connection", palette: palette) {
                SettingsRow(
                    title: "Connect to OBS WebSocket",
                    subtitle: "Enable Tools → WebSocket Server Settings inside OBS Studio (v28+).",
                    icon: "record.circle",
                    iconColor: obsState.isConnected ? palette.statusSuccess : palette.textSecondary,
                    palette: palette
                ) {
                    HStack(spacing: 12) {
                        SettingsStatusPill(
                            label: obsState.label,
                            color: obsStateColor(obsState),
                            palette: palette
                        )
                        Toggle("", isOn: $settings.obsWebSocketEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(palette.accent)
                            .controlSize(.small)
                            .accessibilityLabel("Connect to OBS WebSocket")
                    }
                }

                if settings.obsWebSocketEnabled {
                    SettingsRowDivider(palette: palette)

                    SettingsRow(
                        title: "Server host & port",
                        subtitle: "Use 127.0.0.1 for OBS running on this Mac, or enter a studio machine's LAN IP.",
                        icon: "server.rack",
                        palette: palette
                    ) {
                        HStack(spacing: 8) {
                            TextField("127.0.0.1", text: $settings.obsHost)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12.5, design: .monospaced))
                                .frame(width: 144)

                            TextField("4455", text: Binding(
                                get: { String(settings.obsPort) },
                                set: { str in
                                    if let val = UInt16(str), val > 0 {
                                        settings.obsPort = val
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12.5, design: .monospaced))
                            .frame(width: 68)
                        }
                    }

                    SettingsRowDivider(palette: palette)

                    SettingsRow(
                        title: "Authentication password",
                        subtitle: "Optional WebSocket password configured in OBS Studio.",
                        icon: "key",
                        palette: palette
                    ) {
                        HStack(spacing: 8) {
                            SecureField("Optional", text: $settings.obsPassword)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 164)

                            SettingsActionButton("Reconnect", icon: "arrow.clockwise", palette: palette) {
                                TextreamService.shared.updateOBSConnection()
                            }
                        }
                    }
                }
            }

            if settings.obsWebSocketEnabled {
                SettingsSection(
                    title: "Recording automation",
                    subtitle: "Control how Dante responds when OBS recording state changes.",
                    palette: palette
                ) {
                    SettingsToggleRow(
                        title: "Auto-start teleprompter on OBS Record Start",
                        subtitle: "Launch the active script immediately when OBS begins recording.",
                        icon: "play.fill",
                        iconColor: palette.accent,
                        isOn: $settings.obsAutoStartTeleprompter,
                        palette: palette
                    )

                    SettingsRowDivider(palette: palette)

                    SettingsToggleRow(
                        title: "Auto-stop teleprompter on OBS Record Stop",
                        subtitle: "Dismiss the teleprompter cleanly as soon as OBS stops recording.",
                        icon: "stop.fill",
                        isOn: $settings.obsAutoStopTeleprompter,
                        palette: palette
                    )
                }
            }
        }
    }

    // MARK: - Shortcuts & Hardware Page

    var shortcutsTab: some View {
        VStack(alignment: .leading, spacing: 26) {
            SettingsPageHeader(
                title: SettingsTab.shortcuts.label,
                subtitle: SettingsTab.shortcuts.subtitle,
                palette: palette
            )

            SettingsSection(
                title: "Clickers, foot pedals & game controllers",
                subtitle: "Hands-free hardware controls work automatically during any live teleprompter session.",
                palette: palette
            ) {
                shortcutBindingRow(
                    title: "Play or pause",
                    subtitle: "Toggle scrolling and voice tracking mid-take.",
                    icon: "playpause",
                    keys: ["Space", ".", "F13", "Btn A"]
                )
                SettingsRowDivider(palette: palette)
                shortcutBindingRow(
                    title: "Rewind sentence (Smart Retake)",
                    subtitle: "Jump back cleanly to re-deliver the current sentence.",
                    icon: "arrow.counterclockwise",
                    keys: ["←", "F14", "Btn B"]
                )
                SettingsRowDivider(palette: palette)
                shortcutBindingRow(
                    title: "Next page",
                    subtitle: "Advance to the following script page or slide note.",
                    icon: "arrow.right.doc.on.clipboard",
                    keys: ["PgDn", "→", "F17"]
                )
                SettingsRowDivider(palette: palette)
                shortcutBindingRow(
                    title: "Previous page",
                    subtitle: "Return to the previous page in a multi-page script.",
                    icon: "arrow.left.square",
                    keys: ["PgUp", "F16"]
                )
                SettingsRowDivider(palette: palette)
                shortcutBindingRow(
                    title: "Adjust scroll speed",
                    subtitle: "Fine-tune scrolling speed in ±0.5 words/sec increments.",
                    icon: "speedometer",
                    keys: ["↑", "↓"]
                )
                SettingsRowDivider(palette: palette)
                shortcutBindingRow(
                    title: "Drop NLE timeline marker",
                    subtitle: "Stamp a timestamped marker for Final Cut Pro / DaVinci / Premiere export.",
                    icon: "bookmark",
                    keys: ["M", "F15", "Btn X"]
                )
            }

            SettingsSection(title: "Studio workspace shortcuts", palette: palette) {
                shortcutBindingRow(
                    title: "Quick Composer & script search",
                    subtitle: "Open the command palette from anywhere in Dante.",
                    icon: "magnifyingglass",
                    keys: ["⌘K"]
                )
                SettingsRowDivider(palette: palette)
                shortcutBindingRow(
                    title: "Start teleprompter",
                    subtitle: "Begin reading the current script page immediately.",
                    icon: "play.fill",
                    keys: ["⌘↩"]
                )
                SettingsRowDivider(palette: palette)
                shortcutBindingRow(
                    title: "New script",
                    subtitle: "Create a fresh script in your studio library.",
                    icon: "square.and.pencil",
                    keys: ["⌘N"]
                )
                SettingsRowDivider(palette: palette)
                shortcutBindingRow(
                    title: "Open file or presentation",
                    subtitle: "Import .dante, text, or Keynote/PowerPoint speaker notes.",
                    icon: "folder",
                    keys: ["⌘O"]
                )
                SettingsRowDivider(palette: palette)
                shortcutBindingRow(
                    title: "Open settings",
                    subtitle: "Toggle the Settings workspace.",
                    icon: "gearshape",
                    keys: ["⌘,"]
                )
            }
        }
    }

    // MARK: - About & Reset Page

    var aboutTab: some View {
        VStack(alignment: .leading, spacing: 26) {
            SettingsPageHeader(
                title: SettingsTab.about.label,
                subtitle: SettingsTab.about.subtitle,
                palette: palette
            )

            SettingsSection(title: "Application", palette: palette) {
                SettingsRow(
                    title: DanteAppLinks.appName,
                    subtitle: DanteAppLinks.companyName,
                    palette: palette
                ) {
                    if let icon = NSImage(named: "AppIcon") {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        Text("D")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(palette.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }

                SettingsRowDivider(palette: palette)

                SettingsRow(
                    title: "Version",
                    subtitle: "Copy for support diagnostics and bug reports.",
                    palette: palette
                ) {
                    SettingsCopyablePill(value: appVersionLabel, palette: palette)
                }

                SettingsRowDivider(palette: palette)

                SettingsRow(
                    title: "Creator Setup Guide",
                    subtitle: "Re-open the quick studio onboarding tour and format presets.",
                    icon: "sparkles",
                    palette: palette
                ) {
                    SettingsActionButton("Open Guide", palette: palette) {
                        closeSettings()
                        NotificationCenter.default.post(name: .openOnboarding, object: nil)
                    }
                }

                SettingsRowDivider(palette: palette)

                SettingsRow(
                    title: "Open source acknowledgements",
                    subtitle: "View licenses for Textream, OpenDyslexic, TranscribeCpp, and local speech models.",
                    icon: "doc.text",
                    palette: palette
                ) {
                    SettingsActionButton("View Licenses", palette: palette) {
                        showAcknowledgements = true
                    }
                }

                SettingsRowDivider(palette: palette)

                SettingsRow(
                    title: "Support & privacy",
                    subtitle: DanteAppLinks.copyrightNotice,
                    icon: "hand.raised",
                    palette: palette
                ) {
                    HStack(spacing: 8) {
                        Link(destination: DanteAppLinks.supportURL) {
                            HStack(spacing: 4) {
                                Text("Support")
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(palette.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5.5)
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

                        Link(destination: DanteAppLinks.privacyURL) {
                            HStack(spacing: 4) {
                                Text("Privacy")
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(palette.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5.5)
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
                    }
                }
            }

            SettingsSection(title: "Danger zone", palette: palette) {
                SettingsRow(
                    title: "Reset all settings",
                    subtitle: "Restore every appearance, teleprompter, speech, and studio integration option to factory defaults.",
                    palette: palette
                ) {
                    Button("Reset all settings") {
                        showResetConfirmation = true
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(palette.statusDanger)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
            }
        }
    }

    // MARK: - Shared Helpers

    func shortcutBindingRow(
        title: String,
        subtitle: String,
        icon: String,
        keys: [String]
    ) -> some View {
        SettingsRow(title: title, subtitle: subtitle, icon: icon, palette: palette) {
            HStack(spacing: 5) {
                ForEach(keys, id: \.self) { key in
                    DanteKeycapBadge(label: key, palette: palette)
                }
            }
        }
    }

    @ViewBuilder
    func displaySelectionRows(
        screens: [NSScreen],
        selectedID: Binding<UInt32>,
        emptyMessage: String
    ) -> some View {
        if screens.isEmpty {
            SettingsRow(
                title: "No displays available",
                subtitle: emptyMessage,
                icon: "exclamationmark.triangle",
                iconColor: palette.statusWarning,
                palette: palette
            ) {
                EmptyView()
            }
        } else {
            ForEach(Array(screens.enumerated()), id: \.element.displayID) { index, screen in
                if index > 0 {
                    SettingsRowDivider(palette: palette)
                }
                let isSelected = selectedID.wrappedValue == screen.displayID
                Button {
                    selectedID.wrappedValue = screen.displayID
                } label: {
                    SettingsRow(
                        title: screen.displayName,
                        subtitle: "\(Int(screen.frame.width)) × \(Int(screen.frame.height))",
                        icon: "display",
                        iconColor: isSelected ? palette.accent : palette.textSecondary,
                        palette: palette
                    ) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(palette.accent)
                        } else {
                            Circle()
                                .strokeBorder(palette.borderStrong, lineWidth: 1.25)
                                .frame(width: 15, height: 15)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    func qrCodeSectionRow(title: String, subtitle: String, url: String) -> some View {
        SettingsRow(title: title, subtitle: subtitle, icon: "qrcode", palette: palette) {
            if let qrImage = generateQRCode(from: url) {
                Image(nsImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 86, height: 86)
                    .padding(6)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(palette.borderSubtle, lineWidth: 1)
                    )
            }
        }
    }

    func generateQRCode(from string: String) -> NSImage? {
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

    private func localizedLocaleName(_ identifier: String) -> String {
        Locale.current.localizedString(forIdentifier: identifier) ?? identifier
    }

    private var selectedMicrophoneName: String {
        guard !settings.selectedMicUID.isEmpty else { return "System Default" }
        return availableMics.first(where: { $0.uid == settings.selectedMicUID })?.name ?? "System Default"
    }

    private func obsStateColor(_ state: OBSConnectionState) -> Color {
        switch state {
        case .connected:    return palette.statusSuccess
        case .connecting:   return palette.statusWarning
        case .error:        return palette.statusDanger
        case .disconnected: return palette.textTertiary
        }
    }

    private func localModelStatusColor(
        activeDownloads: Int,
        failure: String?,
        installed: LocalSpeechModel?
    ) -> Color {
        if activeDownloads > 0 { return palette.accent }
        if failure != nil { return palette.statusDanger }
        if installed != nil { return palette.statusSuccess }
        return palette.textTertiary
    }

    private func localModelStatusText(
        activeDownloads: Int,
        failure: String?,
        installed: LocalSpeechModel?
    ) -> String {
        if activeDownloads > 0 {
            let pct = Int(modelDownloads.overallProgress * 100)
            return activeDownloads == 1
                ? "Downloading model — \(pct)% complete."
                : "Downloading \(activeDownloads) models — \(pct)% complete."
        }
        if let failure {
            return failure
        }
        if let installed {
            return "\(installed.displayName) ready (\(installed.sizeMB) MB)."
        }
        return "No on-device model installed. Click Manage Models to download from Hugging Face."
    }
}
