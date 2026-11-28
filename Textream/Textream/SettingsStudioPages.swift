//
//  SettingsStudioPages.swift
//  Dante for Creators
//
//  Voice & AI, Studio, Integrations, and System pages for SettingsView.
//

import AppKit
import SwiftUI

struct LocalizedSpeechLocale: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
}

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
                        accessibilityTitle: "Listening mode",
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
                                .accessibilityLabel("Loading speech languages")
                        } else {
                            SettingsStringMenuPicker(
                                options: supportedLocales.map {
                                    SettingsDropdownOption(id: $0.id, label: $0.displayName)
                                },
                                selectedID: $settings.speechLocale,
                                placeholder: selectedLocaleDisplayName,
                                minWidth: 168,
                                maxWidth: 224,
                                accessibilityTitle: "Speech language",
                                palette: palette
                            )
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
                            activeSheet = .guidanceTest(settings.speechEngine)
                        }
                    }
                }
            }

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
                        .accessibilityLabel("Refresh microphones")
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
                        SettingsStringMenuPicker(
                            options: [SettingsDropdownOption(id: "", label: "System Default")]
                                + availableMics.map { SettingsDropdownOption(id: $0.uid, label: $0.name) },
                            selectedID: $settings.selectedMicUID,
                            placeholder: "System Default",
                            minWidth: 168,
                            maxWidth: 224,
                            accessibilityTitle: "Microphone input",
                            palette: palette
                        )
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

    private var localModelSummaryRow: some View {
        let installed = modelStore.model(named: settings.localModelFilename)
        let hasAnyInstalled = !modelStore.models.isEmpty
        let subtitle: String
        if let installed {
            subtitle = "\(installed.displayName) (\(installed.sizeMB) MB) — runs 100% on this Mac."
        } else if hasAnyInstalled {
            subtitle = "\(modelStore.models.count) local model(s) installed. Choose one to enable offline tracking."
        } else {
            subtitle = "No local model installed yet. Open Speech Models to download from Hugging Face."
        }

        return SettingsRow(
            title: "Active local model",
            subtitle: subtitle,
            icon: "cpu",
            iconColor: installed != nil ? palette.statusSuccess : palette.textTertiary,
            palette: palette
        ) {
            HStack(spacing: 8) {
                if hasAnyInstalled {
                    SettingsStringMenuPicker(
                        options: modelStore.models.map {
                            SettingsDropdownOption(id: $0.filename, label: "\($0.displayName) — \($0.sizeMB) MB")
                        },
                        selectedID: $settings.localModelFilename,
                        placeholder: "Select model…",
                        minWidth: 140,
                        maxWidth: 196,
                        accessibilityTitle: "Active local speech model",
                        palette: palette
                    )
                }

                SettingsActionButton("Manage…", palette: palette) {
                    activeSheet = .modelManager
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
        let hasAnyModels = !modelStore.models.isEmpty

        return VStack(alignment: .leading, spacing: 26) {
            SettingsPageHeader(
                title: SettingsTab.models.label,
                subtitle: SettingsTab.models.subtitle,
                palette: palette
            )

            SettingsSection(title: "Engine & hardware", palette: palette) {
                SettingsRow(
                    title: "Speech engine",
                    subtitle: "Switch Word Tracking to Local Model so audio never leaves this Mac.",
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
                        activeSheet = .modelManager
                    }
                }
            ) {
                SettingsRow(
                    title: "Model status",
                    subtitle: localModelStatusText(
                        activeDownloads: activeDownloads,
                        failure: firstFailure,
                        installed: installedModel,
                        hasAnyModels: hasAnyModels
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
                        label: localModelStatusBadge(
                            activeDownloads: activeDownloads,
                            installed: installedModel,
                            hasAnyModels: hasAnyModels
                        ),
                        color: localModelStatusColor(
                            activeDownloads: activeDownloads,
                            failure: firstFailure,
                            installed: installedModel
                        ),
                        palette: palette
                    )
                }

                if hasAnyModels {
                    SettingsRowDivider(palette: palette)

                    SettingsRow(
                        title: "Selected model",
                        subtitle: "Active model loaded when Word Tracking starts in Local Model mode.",
                        palette: palette
                    ) {
                        SettingsStringMenuPicker(
                            options: modelStore.models.map {
                                SettingsDropdownOption(id: $0.filename, label: "\($0.displayName) — \($0.sizeMB) MB")
                            },
                            selectedID: $settings.localModelFilename,
                            placeholder: "Select a model…",
                            minWidth: 168,
                            maxWidth: 224,
                            accessibilityTitle: "Selected local speech model",
                            palette: palette
                        )
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
                        .accessibilityLabel("Refresh external displays")
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
        let _ = browserRestartNonce
        let browserIsRunning = service.browserServer.isRunning
        let remoteURL = "http://\(localIP):\(settings.browserServerPort)"
        let parsedPort = SettingsNetworkValidator.parseLANPort(browserPortDraft)
        let hasCollision = parsedPort.map {
            settings.directorModeEnabled && SettingsNetworkValidator.lanPortsCollide($0, settings.directorServerPort)
        } ?? false
        let portValidationMessage: String? = {
            if parsedPort == nil {
                return "Enter a port between 1024 and 65534."
            }
            if hasCollision {
                return "Port collides with Director (\(settings.directorServerPort)–\(settings.directorServerPort + 1))."
            }
            return nil
        }()

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
                            label: settings.browserServerEnabled
                                ? (browserIsRunning ? "Running" : "Starting")
                                : "Off",
                            color: settings.browserServerEnabled
                                ? (browserIsRunning ? palette.statusSuccess : palette.statusWarning)
                                : palette.textTertiary,
                            palette: palette
                        )
                        Toggle("", isOn: $settings.browserServerEnabled)
                            .labelsHidden()
                            .toggleStyle(SettingsSwitchToggleStyle(palette: palette))
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
                        SettingsCopyablePill(
                            value: remoteURL,
                            accentValue: true,
                            accessibilityContext: "Remote URL",
                            palette: palette
                        )
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
                        subtitle: portValidationMessage ?? "Click Restart after changing the port number (1024–65534).",
                        icon: "network",
                        iconColor: portValidationMessage != nil ? palette.statusDanger : nil,
                        palette: palette
                    ) {
                        HStack(spacing: 8) {
                            TextField("7373", text: $browserPortDraft)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12.5, design: .monospaced))
                                .frame(width: 82)
                                .accessibilityLabel("Remote server port")
                                .onSubmit { commitBrowserPortAndRestart() }

                            SettingsActionButton(
                                "Restart",
                                icon: "arrow.clockwise",
                                isDisabled: parsedPort == nil || hasCollision,
                                palette: palette
                            ) {
                                commitBrowserPortAndRestart()
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
        let activePIN = directorPairingCode.isEmpty
            ? service.directorServer.pairingCode
            : directorPairingCode
        let obsState = service.obsClient.state
        let parsedPort = SettingsNetworkValidator.parseLANPort(directorPortDraft)
        let hasCollision = parsedPort.map {
            settings.browserServerEnabled && SettingsNetworkValidator.lanPortsCollide($0, settings.browserServerPort)
        } ?? false
        let portValidationMessage: String? = {
            if parsedPort == nil {
                return "Enter a port between 1024 and 65534."
            }
            if hasCollision {
                return "Port collides with Remote (\(settings.browserServerPort)–\(settings.browserServerPort + 1))."
            }
            return nil
        }()

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
                            label: settings.directorModeEnabled
                                ? (service.directorServer.isRunning ? "Active" : "Starting")
                                : "Off",
                            color: settings.directorModeEnabled
                                ? (service.directorServer.isRunning ? palette.statusSuccess : palette.statusWarning)
                                : palette.textTertiary,
                            palette: palette
                        )
                        Toggle("", isOn: $settings.directorModeEnabled)
                            .labelsHidden()
                            .toggleStyle(SettingsSwitchToggleStyle(palette: palette))
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
                        SettingsCopyablePill(
                            value: directorURL,
                            accentValue: true,
                            accessibilityContext: "Director URL",
                            palette: palette
                        )
                    }

                    if !activePIN.isEmpty {
                        SettingsRowDivider(palette: palette)

                        SettingsRow(
                            title: "iOS Studio Remote PIN",
                            subtitle: "Discovered automatically via Bonjour on the same Wi-Fi network.",
                            icon: "iphone.radiowaves.left.and.right",
                            iconColor: palette.accent,
                            palette: palette
                        ) {
                            SettingsCopyablePill(
                                value: activePIN,
                                accentValue: true,
                                isSensitive: true,
                                accessibilityContext: "iOS Studio Remote PIN",
                                palette: palette
                            )
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
                        subtitle: portValidationMessage ?? "Click Restart after updating the port (1024–65534). Generates a fresh pairing PIN.",
                        icon: "network",
                        iconColor: portValidationMessage != nil ? palette.statusDanger : nil,
                        palette: palette
                    ) {
                        HStack(spacing: 8) {
                            TextField("7575", text: $directorPortDraft)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12.5, design: .monospaced))
                                .frame(width: 82)
                                .accessibilityLabel("Director server port")
                                .onSubmit { commitDirectorPortAndRestart() }

                            SettingsActionButton(
                                "Restart",
                                icon: "arrow.clockwise",
                                isDisabled: parsedPort == nil || hasCollision,
                                palette: palette
                            ) {
                                commitDirectorPortAndRestart()
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
        let obsState = service.obsClient.state
        let sanitizedHost = SettingsNetworkValidator.sanitizeOBSHost(obsHostDraft)
        let parsedOBSPort = SettingsNetworkValidator.parseOBSPort(obsPortDraft)
        let hostIsRemote = sanitizedHost.map { !SettingsNetworkValidator.isLoopbackHost($0) } ?? false
        let endpointValidationMessage: String? = {
            if sanitizedHost == nil {
                return "Enter a hostname or IP address without a scheme (e.g., 127.0.0.1)."
            }
            if parsedOBSPort == nil {
                return "Enter a valid TCP port between 1 and 65535."
            }
            if hostIsRemote {
                return "Uses unencrypted ws:// on your local network. Use only on a trusted studio LAN."
            }
            return nil
        }()

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
                            .toggleStyle(SettingsSwitchToggleStyle(palette: palette))
                            .accessibilityLabel("Connect to OBS WebSocket")
                    }
                }

                if settings.obsWebSocketEnabled {
                    SettingsRowDivider(palette: palette)

                    SettingsRow(
                        title: "Server host & port",
                        subtitle: endpointValidationMessage
                            ?? "Use 127.0.0.1 for OBS running on this Mac, or a trusted studio LAN IP.",
                        icon: "server.rack",
                        iconColor: (sanitizedHost == nil || parsedOBSPort == nil)
                            ? palette.statusDanger
                            : (hostIsRemote ? palette.statusWarning : nil),
                        palette: palette
                    ) {
                        HStack(spacing: 8) {
                            TextField("127.0.0.1", text: $obsHostDraft)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12.5, design: .monospaced))
                                .frame(width: 136)
                                .accessibilityLabel("OBS server host")
                                .onSubmit { commitOBSConnection() }

                            TextField("4455", text: $obsPortDraft)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12.5, design: .monospaced))
                                .frame(width: 68)
                                .accessibilityLabel("OBS server port")
                                .onSubmit { commitOBSConnection() }
                        }
                    }

                    SettingsRowDivider(palette: palette)

                    SettingsRow(
                        title: "Password",
                        subtitle: "Optional OBS WebSocket authentication password.",
                        icon: "key",
                        palette: palette
                    ) {
                        HStack(spacing: 8) {
                            SecureField("Optional", text: $settings.obsPassword)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 152)
                                .accessibilityLabel("OBS WebSocket password")
                                .onSubmit { commitOBSConnection() }

                            SettingsActionButton(
                                "Reconnect",
                                icon: "arrow.clockwise",
                                isDisabled: sanitizedHost == nil || parsedOBSPort == nil,
                                palette: palette
                            ) {
                                commitOBSConnection()
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
                    icon: "arrow.right.square",
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
                    keys: ["↑", "↓", "F18", "F19"]
                )
                SettingsRowDivider(palette: palette)
                shortcutBindingRow(
                    title: "Drop NLE timeline marker",
                    subtitle: "Stamp a timestamped marker for Final Cut Pro / DaVinci / Premiere export.",
                    icon: "bookmark",
                    keys: ["M", "F15", "Btn X"]
                )
                SettingsRowDivider(palette: palette)
                shortcutBindingRow(
                    title: "Stop live teleprompter",
                    subtitle: "Dismiss the active overlay and return to the studio workspace.",
                    icon: "escape",
                    keys: ["Esc"]
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
                    title: "Toggle settings",
                    subtitle: "Open or close the Settings workspace.",
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
                    SettingsCopyablePill(
                        value: appVersionLabel,
                        accessibilityContext: "app version",
                        palette: palette
                    )
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
                        activeSheet = .acknowledgements
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
                        SettingsExternalLinkPill(
                            title: "Support",
                            destination: DanteAppLinks.supportURL,
                            palette: palette
                        )
                        SettingsExternalLinkPill(
                            title: "Privacy",
                            destination: DanteAppLinks.privacyURL,
                            palette: palette
                        )
                    }
                }
            }

            SettingsSection(title: "Danger zone", palette: palette) {
                SettingsRow(
                    title: "Reset all settings",
                    subtitle: "Restore every appearance, teleprompter, speech, and studio integration option to factory defaults.",
                    palette: palette
                ) {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Text("Reset all settings")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(palette.statusDanger)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
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
            .fixedSize()
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
                .accessibilityLabel("\(screen.displayName), \(Int(screen.frame.width)) by \(Int(screen.frame.height))")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    func qrCodeSectionRow(title: String, subtitle: String, url: String) -> some View {
        SettingsRow(title: title, subtitle: subtitle, icon: "qrcode", palette: palette) {
            SettingsQRCodeView(url: url, size: 86, palette: palette)
        }
    }

    private func commitBrowserPortAndRestart() {
        guard let port = SettingsNetworkValidator.parseLANPort(browserPortDraft) else { return }
        if settings.directorModeEnabled && SettingsNetworkValidator.lanPortsCollide(port, settings.directorServerPort) {
            return
        }
        settings.browserServerPort = port
        browserPortDraft = String(port)
        service.browserServer.stop()
        browserRestartNonce &+= 1
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            if settings.browserServerEnabled {
                service.browserServer.start()
            }
            localIP = BrowserServer.localIPAddress() ?? "localhost"
            browserRestartNonce &+= 1
        }
    }

    private func commitDirectorPortAndRestart() {
        guard let port = SettingsNetworkValidator.parseLANPort(directorPortDraft) else { return }
        if settings.browserServerEnabled && SettingsNetworkValidator.lanPortsCollide(port, settings.browserServerPort) {
            return
        }
        settings.directorServerPort = port
        directorPortDraft = String(port)
        service.directorServer.stop()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            if settings.directorModeEnabled {
                service.directorServer.start()
            }
            directorLocalIP = BrowserServer.localIPAddress() ?? "localhost"
            directorPairingCode = service.directorServer.pairingCode
        }
    }

    private func commitOBSConnection() {
        guard let host = SettingsNetworkValidator.sanitizeOBSHost(obsHostDraft),
              let port = SettingsNetworkValidator.parseOBSPort(obsPortDraft) else { return }
        settings.obsHost = host
        settings.obsPort = port
        obsHostDraft = host
        obsPortDraft = String(port)
        service.updateOBSConnection()
    }

    private var selectedLocaleDisplayName: String {
        if let match = supportedLocales.first(where: { $0.id == settings.speechLocale }) {
            return match.displayName
        }
        return Locale.current.localizedString(forIdentifier: settings.speechLocale) ?? settings.speechLocale
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

    private func localModelStatusBadge(
        activeDownloads: Int,
        installed: LocalSpeechModel?,
        hasAnyModels: Bool
    ) -> String {
        if activeDownloads > 0 {
            return "\(Int(modelDownloads.overallProgress * 100))%"
        }
        if installed != nil { return "Ready" }
        return hasAnyModels ? "Not selected" : "Not installed"
    }

    private func localModelStatusText(
        activeDownloads: Int,
        failure: String?,
        installed: LocalSpeechModel?,
        hasAnyModels: Bool
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
        if hasAnyModels {
            return "\(modelStore.models.count) local model(s) installed. Choose one below to activate offline tracking."
        }
        return "No on-device model installed. Click Manage Models to download from Hugging Face."
    }
}
