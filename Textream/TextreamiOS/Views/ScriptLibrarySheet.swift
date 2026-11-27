import Foundation
import SwiftUI

private enum IOSLibrarySegment: String, CaseIterable, Identifiable {
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

struct ScriptLibrarySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AppModel
    @State private var searchQuery = ""
    @State private var segment: IOSLibrarySegment = .all
    @State private var presetFilter: CreatorPresetID? = nil
    @State private var renamingScript: DanteScript?
    @State private var renameDraft = ""

    private var palette: DantePalette {
        DantePalette(colorScheme: colorScheme)
    }

    private var filteredScripts: [DanteScript] {
        var result = ScriptLibraryPersistence.filtered(model.scripts, query: searchQuery)
        if let presetFilter {
            result = result.filter { $0.presetID == presetFilter }
        }
        return result
    }

    private var pinnedScripts: [DanteScript] {
        filteredScripts.filter(\.isPinned)
    }

    private var unpinnedScripts: [DanteScript] {
        filteredScripts.filter { !$0.isPinned }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented filter + preset filter menu
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        ForEach(IOSLibrarySegment.allCases) { item in
                            let isSelected = segment == item
                            Button {
                                withAnimation(.snappy) { segment = item }
                            } label: {
                                Text(item.label)
                                    .font(.caption.weight(isSelected ? .semibold : .medium))
                                    .foregroundStyle(isSelected ? palette.textPrimary : palette.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
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
                    }
                    .padding(3)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(palette.borderSubtle, lineWidth: 1)
                    )

                    Spacer()

                    Button {
                        Task {
                            await model.syncWithCloud()
                        }
                    } label: {
                        Image(systemName: model.syncStatus.systemImage)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(model.syncStatus == .syncing ? palette.accent : palette.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(palette.borderSubtle, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("iCloud Sync: \(model.syncStatus.label)")

                    Menu {
                        Button {
                            presetFilter = nil
                        } label: {
                            Label("All Presets", systemImage: presetFilter == nil ? "checkmark" : "line.3.horizontal.decrease")
                        }
                        Divider()
                        ForEach(CreatorPreset.all) { preset in
                            Button {
                                presetFilter = preset.id
                            } label: {
                                Label(preset.name, systemImage: preset.systemImage)
                            }
                        }
                    } label: {
                        Image(systemName: presetFilter == nil ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(presetFilter == nil ? palette.textSecondary : palette.accent)
                            .frame(width: 32, height: 32)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(palette.borderSubtle, lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if let presetFilter {
                    HStack {
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
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                ScrollView {
                    VStack(spacing: 0) {
                        // Read-Time Estimator inline strip
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Speaking Pace Estimator")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(palette.textSecondary)
                                Spacer()
                                Text("\(model.activeTargetWPM) WPM")
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(palette.accent)
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(model.activeTargetWPM) },
                                    set: { model.setActiveTargetWPM(Int($0.rounded())) }
                                ),
                                in: Double(ScriptMetrics.minWPM)...Double(ScriptMetrics.maxWPM),
                                step: 5
                            )
                            .tint(palette.accent)
                        }
                        .padding(14)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(palette.borderSubtle, lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                        if segment != .templates {
                            if !pinnedScripts.isEmpty {
                                DanteSectionHeaderBand(title: "Pinned", count: pinnedScripts.count, palette: palette)
                                ForEach(pinnedScripts) { script in
                                    scriptRow(script)
                                }
                            }

                            if segment == .all {
                                DanteSectionHeaderBand(title: "Active Scripts", count: unpinnedScripts.count, palette: palette)
                                if unpinnedScripts.isEmpty {
                                    emptyRow
                                } else {
                                    ForEach(unpinnedScripts) { script in
                                        scriptRow(script)
                                    }
                                }
                            } else if pinnedScripts.isEmpty {
                                emptyRow
                            }
                        }

                        // Creator Templates 2-column grid
                        DanteSectionHeaderBand(title: "Templates", count: CreatorPreset.all.count, palette: palette)
                            .padding(.top, segment == .templates ? 0 : 10)

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)
                            ],
                            spacing: 10
                        ) {
                            ForEach(CreatorPreset.all) { preset in
                                templateCard(preset)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(palette.canvasBackground.ignoresSafeArea())
            .searchable(text: $searchQuery, prompt: "Search scripts")
            .navigationTitle("Scripts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        model.createNewScript()
                        dismiss()
                    } label: {
                        Label("New Script", systemImage: "square.and.pencil")
                    }
                    .accessibilityIdentifier("newScriptLibraryButton")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .buttonStyle(.glassProminent)
                }
            }
            .alert("Rename Script", isPresented: Binding(
                get: { renamingScript != nil },
                set: { if !$0 { renamingScript = nil } }
            )) {
                TextField("Title", text: $renameDraft)
                Button("Cancel", role: .cancel) { renamingScript = nil }
                Button("Rename") {
                    if let script = renamingScript {
                        model.renameScript(scriptID: script.id, to: renameDraft)
                    }
                    renamingScript = nil
                }
            }
        }
        .preferredColorScheme(model.appAppearance.colorScheme)
    }

    private func scriptRow(_ script: DanteScript) -> some View {
        let isSelected = script.id == model.selectedScriptID
        let preset = script.presetID.map { CreatorPreset.preset(for: $0) }

        return Button {
            model.selectScript(script)
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: preset?.systemImage ?? "doc.text")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isSelected ? palette.accent : palette.textSecondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if script.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundStyle(palette.accent)
                        }
                        Text(script.displayTitle)
                            .font(.subheadline.weight(isSelected ? .semibold : .medium))
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)
                    }

                    Text(script.previewSnippet)
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(script.metrics.formattedDuration)
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundStyle(palette.textSecondary)
                    Text("\(script.metrics.spokenWordCount)w")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(palette.textTertiary)
                }

                if isSelected {
                    Circle()
                        .fill(palette.accent)
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(isSelected ? palette.surface : Color.clear)
            .overlay(alignment: .bottom) {
                Rectangle().fill(palette.borderSubtle).frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                model.togglePin(scriptID: script.id)
            } label: {
                Label(script.isPinned ? "Unpin" : "Pin Script", systemImage: script.isPinned ? "pin.slash" : "pin")
            }
            Button {
                renameDraft = script.displayTitle
                renamingScript = script
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button {
                model.duplicateScript(scriptID: script.id)
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            if model.scripts.count > 1 {
                Button(role: .destructive) {
                    model.deleteScript(scriptID: script.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var emptyRow: some View {
        HStack {
            Text("No matching scripts. Tap a template below to start.")
                .font(.caption)
                .foregroundStyle(palette.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private func templateCard(_ preset: CreatorPreset) -> some View {
        Button {
            model.createScriptFromTemplate(preset)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: preset.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.accent)
                    Text(preset.shortName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                    Spacer()
                }

                Text(preset.tagline)
                    .font(.caption2)
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)

                Spacer(minLength: 2)

                Text(preset.badgeLabel)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(palette.canvasBackground, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(palette.borderSubtle, lineWidth: 1)
                    )
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(palette.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
