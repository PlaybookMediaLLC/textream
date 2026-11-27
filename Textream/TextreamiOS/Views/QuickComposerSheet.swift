//
//  QuickComposerSheet.swift
//  Dante for Creators (iOS / iPadOS)
//
//  Minimalist floating composer modal inspired by command-palette studio flows:
//  breadcrumb header, clean script composer, inline preset/mode/follow selectors,
//  and cobalt-blue launch CTA. Adapts seamlessly to Light and Dark Mode.
//

import Foundation
import SwiftUI

struct QuickComposerSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AppModel

    @State private var draft = ""
    @State private var selectedPresetID: CreatorPresetID = .shortsReels
    @FocusState private var isFocused: Bool

    private var palette: DantePalette {
        DantePalette(colorScheme: colorScheme)
    }

    private var selectedPreset: CreatorPreset {
        CreatorPreset.preset(for: selectedPresetID)
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var metrics: ScriptMetrics {
        ScriptMetrics.measure(text: draft, wordsPerMinute: selectedPreset.targetWPM)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top breadcrumb bar
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.textTertiary)
                Text("Studio")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(palette.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.textTertiary)
                Text("New script")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(palette.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close quick composer")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
                Rectangle().fill(palette.borderSubtle).frame(height: 1)
            }

            // Inline composer
            ZStack(alignment: .topLeading) {
                if draft.isEmpty {
                    Text("Paste or type your script, or pick a creator preset below…")
                        .font(.body)
                        .foregroundStyle(palette.textTertiary)
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $draft)
                    .font(.body)
                    .foregroundStyle(palette.textPrimary)
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(palette.elevatedSurface)

            // Bottom selector strip + cobalt launch button
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Menu {
                        ForEach(CreatorPreset.all) { preset in
                            Button {
                                selectedPresetID = preset.id
                                model.apply(preset: preset)
                            } label: {
                                Label("\(preset.name) · \(preset.targetWPM) WPM", systemImage: preset.systemImage)
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: selectedPreset.systemImage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(palette.accent)
                            Text(selectedPreset.shortName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(palette.textPrimary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(palette.textTertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(palette.borderSubtle, lineWidth: 1)
                        )
                    }

                    Menu {
                        ForEach(SessionMode.allCases) { mode in
                            Button {
                                model.sessionMode = mode
                                if mode == .record { model.cameraEnabled = true }
                            } label: {
                                Label(mode.label, systemImage: mode.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: model.sessionMode.icon)
                                .font(.caption.weight(.medium))
                            Text(model.sessionMode.label)
                                .font(.caption.weight(.medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(palette.textTertiary)
                        }
                        .foregroundStyle(palette.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(palette.borderSubtle, lineWidth: 1)
                        )
                    }

                    Menu {
                        ForEach(FollowMode.allCases) { mode in
                            Button {
                                model.followMode = mode
                            } label: {
                                Label(mode.label, systemImage: mode.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: model.followMode.icon)
                                .font(.caption.weight(.medium))
                            Text(model.followMode.shortLabel)
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(palette.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(palette.borderSubtle, lineWidth: 1)
                        )
                    }

                    Spacer()

                    Button {
                        commit(startImmediately: !trimmedDraft.isEmpty)
                    } label: {
                        Image(systemName: trimmedDraft.isEmpty ? "plus" : "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 34)
                            .background(palette.accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(trimmedDraft.isEmpty ? "Create blank script" : "Create and start prompter")
                }

                HStack {
                    Text(metrics.spokenWordCount > 0
                         ? "\(metrics.summaryLabel) · \(selectedPreset.targetWPM) WPM"
                         : "Tap a starter preset or paste text to launch")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(palette.textTertiary)

                    Spacer()

                    if !trimmedDraft.isEmpty {
                        Button("Save Draft") {
                            commit(startImmediately: false)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(palette.surface)
            .overlay(alignment: .top) {
                Rectangle().fill(palette.borderSubtle).frame(height: 1)
            }
        }
        .background(palette.elevatedSurface.ignoresSafeArea())
        .preferredColorScheme(model.appAppearance.colorScheme)
        .onAppear {
            if let activePreset = model.activePreset {
                selectedPresetID = activePreset.id
            }
            isFocused = true
        }
    }

    private func commit(startImmediately: Bool) {
        let content = draft
        let title = trimmedDraft.isEmpty ? "Untitled Script" : ""
        model.createNewScript(title: title, text: content)
        model.apply(preset: selectedPreset)
        dismiss()
        if startImmediately && !trimmedDraft.isEmpty {
            Task { @MainActor in
                await Task.yield()
                model.startSession()
            }
        }
    }
}
