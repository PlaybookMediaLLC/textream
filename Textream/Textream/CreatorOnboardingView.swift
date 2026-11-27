//
//  CreatorOnboardingView.swift
//  Dante for Creators
//

import AppKit
import AVFoundation
import Foundation
import Speech
import SwiftUI

struct CreatorOnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let onApplyPreset: (CreatorPreset) -> Void

    @State private var step = 0
    @State private var selectedPresetID: CreatorPresetID = .youtubeStudio
    @State private var micStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var speechStatus: SFSpeechRecognizerAuthorizationStatus = SFSpeechRecognizer.authorizationStatus()

    static let completedDefaultsKey = "dante.mac.hasCompletedOnboarding"

    private var palette: DantePalette {
        DantePalette(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            if step == 0 {
                welcomeStep
            } else {
                permissionsStep
            }

            Rectangle().fill(palette.borderSubtle).frame(height: 1)

            HStack {
                if step > 0 {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.2)) { step = 0 }
                    }
                } else {
                    Button("Skip Setup") {
                        completeOnboarding(applySelectedPreset: false)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(palette.textSecondary)
                }

                Spacer()

                if step == 0 {
                    Button("Continue") {
                        withAnimation(.easeInOut(duration: 0.2)) { step = 1 }
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Start Creating") {
                        completeOnboarding(applySelectedPreset: true)
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
            .background(palette.surface)
        }
        .frame(width: 560, height: 500)
        .background(palette.canvasBackground)
        .onAppear {
            refreshPermissions()
        }
    }

    private var welcomeStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    if let icon = NSImage(named: "AppIcon") {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Welcome to Dante for Creators")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(palette.textPrimary)
                        Text("Smart voice-following teleprompter built for camera-ready delivery.")
                            .font(.callout)
                            .foregroundStyle(palette.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label("Smart Follow stays locked to your voice", systemImage: "waveform.path.ecg")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.accent)
                    Text("Pause naturally, ad-lib a thought, skip a paragraph, or re-read a line—Dante aligns to your speech automatically, with optional 100% offline AI speech models on Apple Silicon.")
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(palette.borderSubtle, lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose a Creator Format Preset")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(CreatorPreset.all) { preset in
                            let isSelected = selectedPresetID == preset.id
                            Button {
                                selectedPresetID = preset.id
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: preset.systemImage)
                                            .foregroundStyle(isSelected ? palette.accent : palette.textSecondary)
                                        Text(preset.name)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(palette.textPrimary)
                                        Spacer()
                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(palette.accent)
                                        }
                                    }
                                    Text(preset.tagline)
                                        .font(.system(size: 11))
                                        .foregroundStyle(palette.textSecondary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(preset.badgeLabel)
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundStyle(palette.textTertiary)
                                }
                                .padding(11)
                                .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(isSelected ? palette.accentSubtle : palette.surface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(isSelected ? palette.accent.opacity(0.6) : palette.borderSubtle, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(22)
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Microphone & Speech Access")
                    .font(.title2.weight(.bold))
                Text("Grant permissions now for Smart Follow, or skip and use Classic auto-scroll without a microphone.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            permissionCard(
                icon: "mic.fill",
                title: "Microphone",
                detail: "Used only while reading or dictating so Dante can follow your voice and display live audio levels.",
                statusLabel: micStatusLabel,
                isGranted: micStatus == .authorized,
                isDenied: micStatus == .denied || micStatus == .restricted
            ) {
                if micStatus == .denied || micStatus == .restricted {
                    if let url = SpeechRecognizer.microphoneSettingsURL {
                        NSWorkspace.shared.open(url)
                    }
                } else {
                    AVCaptureDevice.requestAccess(for: .audio) { _ in
                        DispatchQueue.main.async { refreshPermissions() }
                    }
                }
            }

            permissionCard(
                icon: "text.bubble.fill",
                title: "Apple Speech Recognition",
                detail: "Powers instant Word Tracking out of the box. You can also switch to a 100% offline Local AI Model in Settings → Guidance.",
                statusLabel: speechStatusLabel,
                isGranted: speechStatus == .authorized,
                isDenied: speechStatus == .denied || speechStatus == .restricted
            ) {
                if speechStatus == .denied || speechStatus == .restricted {
                    if let url = SpeechRecognizer.speechRecognitionSettingsURL {
                        NSWorkspace.shared.open(url)
                    }
                } else {
                    SFSpeechRecognizer.requestAuthorization { _ in
                        DispatchQueue.main.async { refreshPermissions() }
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(Color.accentColor)
                Text("Dante for Creators collects zero analytics and requires no account. Your scripts stay on your Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(22)
    }

    private func permissionCard(
        icon: String,
        title: String,
        detail: String,
        statusLabel: String,
        isGranted: Bool,
        isDenied: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isGranted ? .green : Color.accentColor)
                .frame(width: 36, height: 36)
                .background((isGranted ? Color.green : Color.accentColor).opacity(0.12), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 10)

            if isGranted {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Button(isDenied ? "Open Settings" : "Allow") {
                    action()
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    private var micStatusLabel: String {
        switch micStatus {
        case .authorized: return "Allowed"
        case .denied, .restricted: return "Denied"
        default: return "Not Requested"
        }
    }

    private var speechStatusLabel: String {
        switch speechStatus {
        case .authorized: return "Allowed"
        case .denied, .restricted: return "Denied"
        default: return "Not Requested"
        }
    }

    private func refreshPermissions() {
        micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        speechStatus = SFSpeechRecognizer.authorizationStatus()
    }

    private func completeOnboarding(applySelectedPreset: Bool) {
        UserDefaults.standard.set(true, forKey: Self.completedDefaultsKey)
        if applySelectedPreset {
            onApplyPreset(CreatorPreset.preset(for: selectedPresetID))
        }
        dismiss()
    }
}
