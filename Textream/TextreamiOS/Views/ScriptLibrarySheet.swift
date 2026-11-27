import Foundation
import SwiftUI

struct ScriptLibrarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AppModel
    @State private var searchQuery = ""
    @State private var renamingScript: DanteScript?
    @State private var renameDraft = ""

    private var filteredScripts: [DanteScript] {
        ScriptLibraryPersistence.filtered(model.scripts, query: searchQuery)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Target Speaking Pace")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text("\(model.activeTargetWPM) WPM")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(model.activeTargetWPM) },
                                set: { model.setActiveTargetWPM(Int($0.rounded())) }
                            ),
                            in: Double(ScriptMetrics.minWPM)...Double(ScriptMetrics.maxWPM),
                            step: 5
                        )
                        .tint(Color.accentColor)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Read-Time Estimator")
                }

                Section("Your Scripts (\(filteredScripts.count))") {
                    ForEach(filteredScripts) { script in
                        let isSelected = script.id == model.selectedScriptID
                        Button {
                            model.selectScript(script)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        if script.isPinned {
                                            Image(systemName: "pin.fill")
                                                .font(.caption2)
                                                .foregroundStyle(Color.accentColor)
                                        }
                                        Text(script.displayTitle)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                    }

                                    Text(script.previewSnippet)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)

                                    HStack(spacing: 8) {
                                        Text(script.metrics.summaryLabel)
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(Color.accentColor)
                                        if let presetID = script.presetID {
                                            Text("· \(CreatorPreset.preset(for: presetID).shortName)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                model.togglePin(scriptID: script.id)
                            } label: {
                                Label(script.isPinned ? "Unpin" : "Pin", systemImage: script.isPinned ? "pin.slash" : "pin")
                            }
                            .tint(Color.accentColor)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if model.scripts.count > 1 {
                                Button(role: .destructive) {
                                    model.deleteScript(scriptID: script.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            Button {
                                renameDraft = script.displayTitle
                                renamingScript = script
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
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
                }
            }
            .searchable(text: $searchQuery, prompt: "Search scripts")
            .navigationTitle("Script Library")
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
        .preferredColorScheme(.dark)
    }
}
