//
//  StudioRemoteView.swift
//  Dante for Creators (iOS / iPadOS)
//
//  Native Studio Remote companion sheet for controlling macOS Dante sessions
//  over local Wi-Fi with Bonjour discovery, live WPM/pace telemetry, and
//  ergonomic transport controls.
//

import SwiftUI

struct StudioRemoteView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var client = StudioRemoteClient()
    @State private var pairingPIN: String = ""
    @State private var manualHost: String = ""
    @State private var manualPort: String = "7576"
    @State private var showManualEntry: Bool = false

    private var palette: DantePalette {
        DantePalette(colorScheme: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusBanner

                    if client.connectionState.isConnected {
                        telemetryCard
                        transportDeck
                    } else {
                        pairingCard
                        discoveryCard
                        manualConnectionCard
                    }
                }
                .padding(18)
            }
            .background(palette.canvasBackground.ignoresSafeArea())
            .navigationTitle("Studio Remote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        client.disconnect()
                        client.stopDiscovery()
                        dismiss()
                    }
                }
                if client.connectionState.isConnected {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Disconnect") {
                            client.disconnect()
                        }
                        .foregroundStyle(palette.statusDanger)
                    }
                }
            }
        }
        .onAppear {
            client.startDiscovery()
        }
        .onDisappear {
            client.disconnect()
            client.stopDiscovery()
        }
    }

    private var statusBanner: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(client.connectionState.isConnected ? palette.statusSuccess : palette.textTertiary)
                .frame(width: 9, height: 9)
            Text(client.connectionState.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
            Spacer()
            if client.isSearching && !client.connectionState.isConnected {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(14)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
    }

    private var pairingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PAIRING PIN")
                .font(.caption2.weight(.bold))
                .foregroundStyle(palette.textTertiary)

            TextField("6-digit PIN from Mac Settings → Director", text: $pairingPIN)
                .keyboardType(.numberPad)
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .padding(12)
                .background(palette.canvasBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(palette.borderSubtle, lineWidth: 1)
                )
        }
        .padding(16)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
    }

    private var discoveryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("NEARBY MACS")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(palette.textTertiary)
                Spacer()
                Button("Refresh") {
                    client.startDiscovery()
                }
                .font(.caption.weight(.semibold))
            }

            if client.discoveredHosts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Searching for Dante on your Wi-Fi…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(palette.textPrimary)
                    Text("Enable Director Mode in Dante Settings on your Mac to appear here automatically.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                .padding(.vertical, 6)
            } else {
                ForEach(client.discoveredHosts) { host in
                    Button {
                        client.connect(to: host, pairingPIN: pairingPIN)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "laptopcomputer")
                                .font(.title3)
                                .foregroundStyle(palette.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(host.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(palette.textPrimary)
                                Text("Tap to connect")
                                    .font(.caption)
                                    .foregroundStyle(palette.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(palette.textTertiary)
                        }
                        .padding(12)
                        .background(palette.canvasBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(pairingPIN.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(pairingPIN.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
                }
            }
        }
        .padding(16)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
    }

    private var manualConnectionCard: some View {
        DisclosureGroup("Connect by IP Address", isExpanded: $showManualEntry) {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    TextField("Mac IP (e.g. 192.168.1.24)", text: $manualHost)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(10)
                        .background(palette.canvasBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    TextField("WS Port", text: $manualPort)
                        .keyboardType(.numberPad)
                        .frame(width: 82)
                        .padding(10)
                        .background(palette.canvasBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                Button {
                    let port = UInt16(manualPort) ?? 7576
                    client.connectManual(host: manualHost, port: port, pairingPIN: pairingPIN)
                } label: {
                    Text("Connect")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(palette.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(manualHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 10)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(palette.textPrimary)
        .padding(16)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
    }

    private var telemetryCard: some View {
        let state = client.remoteState
        let progress = state?.progress ?? 0
        let wpm = state?.currentWPM ?? 0
        let elapsed = state?.elapsedSeconds ?? 0
        let retakes = state?.retakeCount ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state?.scriptTitle ?? "Mac Teleprompter")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                    Text(state?.isActive == true ? (state?.isListening == true ? "Live & Following" : "Paused") : "Standing By")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(state?.isListening == true ? palette.statusSuccess : palette.textSecondary)
                }
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(palette.accent)
            }

            ProgressView(value: progress)
                .tint(palette.accent)

            HStack(spacing: 10) {
                telemetryMetric(title: "PACE", value: wpm > 0 ? "\(wpm) WPM" : "-- WPM")
                telemetryMetric(title: "ELAPSED", value: String(format: "%d:%02d", elapsed / 60, elapsed % 60))
                telemetryMetric(title: "RETAKES", value: "\(retakes)")
            }
        }
        .padding(16)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
    }

    private func telemetryMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(palette.textTertiary)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(palette.canvasBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var transportDeck: some View {
        let state = client.remoteState
        let isListening = state?.isListening ?? false
        let pageIndex = (state?.pageIndex ?? 0) + 1
        let pageCount = max(1, state?.pageCount ?? 1)
        let speed = state?.scrollSpeed ?? 3.0

        return VStack(spacing: 12) {
            Button {
                client.toggleListening()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isListening ? "pause.fill" : "play.fill")
                        .font(.title3.weight(.bold))
                    Text(isListening ? "Pause Prompter" : "Resume Prompter")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(palette.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                remoteButton(title: "Rewind Sentence", icon: "arrow.uturn.backward") {
                    client.rewindSentence()
                }
                remoteButton(title: "Drop Marker", icon: "flag.fill") {
                    client.dropMarker()
                }
            }

            HStack(spacing: 12) {
                remoteButton(title: "Prev Page", icon: "backward.end.fill") {
                    client.previousPage()
                }
                VStack(spacing: 2) {
                    Text("PAGE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(palette.textTertiary)
                    Text("\(pageIndex) / \(pageCount)")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(palette.textPrimary)
                }
                .frame(width: 80)
                remoteButton(title: "Next Page", icon: "forward.end.fill") {
                    client.nextPage()
                }
            }

            HStack(spacing: 12) {
                remoteButton(title: "Slower", icon: "minus.circle") {
                    client.adjustSpeed(delta: -0.5)
                }
                VStack(spacing: 2) {
                    Text("SPEED")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(palette.textTertiary)
                    Text(String(format: "%.1f wps", speed))
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(palette.textPrimary)
                }
                .frame(width: 80)
                remoteButton(title: "Faster", icon: "plus.circle") {
                    client.adjustSpeed(delta: 0.5)
                }
            }

            Button {
                client.stopSession()
            } label: {
                Label("Stop Mac Session", systemImage: "stop.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.statusDanger)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(palette.statusDanger.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func remoteButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(palette.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(palette.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
