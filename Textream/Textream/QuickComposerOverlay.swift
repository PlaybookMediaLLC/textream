//
//  QuickComposerOverlay.swift
//  Dante for Creators
//
//  Floating studio Quick Composer modal (⌘K) modeled after minimalist
//  command palettes: breadcrumb header, inline script composer, compact
//  preset/overlay/engine selectors, cobalt-blue launch button, and keycap footer.
//

import AppKit
import Foundation
import SwiftUI

struct QuickComposerOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var settings: NotchSettings
    let scripts: [DanteScript]
    let onCreateScript: (_ title: String, _ text: String, _ preset: CreatorPreset, _ startImmediately: Bool) -> Void
    let onSelectScript: (_ script: DanteScript) -> Void
    let onImportFile: () -> Void
    let onDismiss: () -> Void

    @State private var draftText: String = ""
    @State private var selectedPresetID: CreatorPresetID = .youtubeStudio
    @FocusState private var isComposerFocused: Bool

    private var palette: DantePalette {
        DantePalette(colorScheme: colorScheme)
    }

    private var selectedPreset: CreatorPreset {
        CreatorPreset.preset(for: selectedPresetID)
    }

    private var trimmedDraft: String {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var draftMetrics: ScriptMetrics {
        ScriptMetrics.measure(text: draftText, wordsPerMinute: selectedPreset.targetWPM)
    }

    private var matchingScripts: [DanteScript] {
        guard !trimmedDraft.isEmpty, trimmedDraft.count < 48, !trimmedDraft.contains("\n") else {
            return []
        }
        return Array(ScriptLibraryPersistence.filtered(scripts, query: trimmedDraft).prefix(3))
    }

    var body: some View {
        ZStack {
            palette.scrim
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 0) {
                // Top breadcrumb bar
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.textTertiary)
                    Text("Studio")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(palette.textTertiary)
                    Text("New script")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)

                    Spacer()

                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(palette.textTertiary)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(palette.borderSubtle).frame(height: 1)
                }

                // Inline composer body
                ZStack(alignment: .topLeading) {
                    if draftText.isEmpty {
                        Text("Paste or type a script, or search existing scripts…")
                            .font(.system(size: 14))
                            .foregroundStyle(palette.textTertiary)
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $draftText)
                        .font(.system(size: 14))
                        .foregroundStyle(palette.textPrimary)
                        .scrollContentBackground(.hidden)
                        .focused($isComposerFocused)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(minHeight: 116, maxHeight: 180)
                }

                // Quick-jump matches when user types a short search term
                if !matchingScripts.isEmpty {
                    VStack(spacing: 0) {
                        HStack {
                            Text("JUMP TO SCRIPT")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(palette.textTertiary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 5)
                        .background(palette.sectionHeaderBackground)
                        .overlay(alignment: .top) {
                            Rectangle().fill(palette.borderSubtle).frame(height: 1)
                        }

                        ForEach(matchingScripts) { script in
                            Button {
                                onSelectScript(script)
                                onDismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 11))
                                        .foregroundStyle(palette.textTertiary)
                                    Text(script.displayTitle)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(palette.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(script.metrics.summaryLabel)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(palette.textTertiary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Inline control strip (matching Screenshot 2)
                HStack(spacing: 8) {
                    Button {
                        onDismiss()
                        onImportFile()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(palette.textSecondary)
                            .frame(width: 26, height: 26)
                            .background(palette.surfaceHover, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("Import .dante or .pptx file")

                    // Creator preset picker
                    Menu {
                        ForEach(CreatorPreset.all) { preset in
                            Button {
                                selectedPresetID = preset.id
                                settings.apply(preset: preset)
                            } label: {
                                Label("\(preset.name) · \(preset.targetWPM) WPM", systemImage: preset.systemImage)
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: selectedPreset.systemImage)
                                .font(.system(size: 11, weight: .medium))
                            Text(selectedPreset.shortName)
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(palette.textTertiary)
                        }
                        .foregroundStyle(palette.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(palette.borderSubtle, lineWidth: 1)
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    // Guidance mode picker
                    Menu {
                        ForEach(ListeningMode.allCases) { mode in
                            Button {
                                settings.listeningMode = mode
                            } label: {
                                Label(mode.label, systemImage: mode.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: settings.listeningMode.icon)
                                .font(.system(size: 11, weight: .medium))
                            Text(settings.listeningMode.label)
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(palette.textTertiary)
                        }
                        .foregroundStyle(palette.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    Spacer(minLength: 8)

                    // Overlay mode picker
                    Menu {
                        ForEach(OverlayMode.allCases) { mode in
                            Button {
                                settings.overlayMode = mode
                            } label: {
                                Label(mode.label, systemImage: mode.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: settings.overlayMode.icon)
                                .font(.system(size: 11))
                            Text(shortOverlayLabel(settings.overlayMode))
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(palette.textTertiary)
                        }
                        .foregroundStyle(palette.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 5)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    // Speech engine picker
                    Menu {
                        ForEach(SpeechEngine.allCases) { engine in
                            Button {
                                settings.speechEngine = engine
                            } label: {
                                Text(engine.label)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: settings.speechEngine == .local ? "cpu" : "waveform")
                                .font(.system(size: 11))
                                .foregroundStyle(palette.accent)
                            Text(settings.speechEngine == .local ? "Local AI" : "Apple Speech")
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(palette.textTertiary)
                        }
                        .foregroundStyle(palette.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 5)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    // Signature cobalt-blue square-rounded submit / launch button
                    Button {
                        submit(startImmediately: !trimmedDraft.isEmpty)
                    } label: {
                        Image(systemName: trimmedDraft.isEmpty ? "plus" : "play.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(palette.accent, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help(trimmedDraft.isEmpty ? "Create blank script" : "Create script and start prompter (⌘↩)")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                // Footer strip with keycap shortcuts
                HStack(spacing: 12) {
                    if draftMetrics.spokenWordCount > 0 {
                        Text("\(draftMetrics.summaryLabel) · \(selectedPreset.targetWPM) WPM")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(palette.textTertiary)
                    } else {
                        Text("Tip: Press ⌘↩ to create & launch prompter")
                            .font(.system(size: 11))
                            .foregroundStyle(palette.textTertiary)
                    }

                    Spacer()

                    Button {
                        submit(startImmediately: false)
                    } label: {
                        HStack(spacing: 5) {
                            DanteKeycapBadge(label: "⇧↩", palette: palette)
                            Text("Create")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(palette.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: .shift)

                    Button {
                        submit(startImmediately: !trimmedDraft.isEmpty)
                    } label: {
                        HStack(spacing: 5) {
                            DanteKeycapBadge(label: "⌘↩", palette: palette)
                            Text("Start")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(palette.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: .command)

                    HStack(spacing: 5) {
                        DanteKeycapBadge(label: "Esc", palette: palette)
                        Text("Close")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(palette.textTertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(palette.surface)
                .overlay(alignment: .top) {
                    Rectangle().fill(palette.borderSubtle).frame(height: 1)
                }
            }
            .frame(width: 580)
            .background(palette.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(palette.borderStrong, lineWidth: 1)
            )
            .shadow(color: .black.opacity(palette.isDark ? 0.55 : 0.16), radius: 28, y: 14)
        }
        .onAppear {
            isComposerFocused = true
        }
    }

    private func shortOverlayLabel(_ mode: OverlayMode) -> String {
        switch mode {
        case .pinned: return "Notch"
        case .floating: return "Floating"
        case .fullscreen: return "Fullscreen"
        }
    }

    private func submit(startImmediately: Bool) {
        let content = draftText
        let inferredTitle = trimmedDraft.isEmpty ? "Untitled Script" : ""
        onCreateScript(inferredTitle, content, selectedPreset, startImmediately)
        onDismiss()
    }
}
