import Foundation
import SwiftUI

struct AcknowledgementsView: View {
    private let entries = OpenSourceLicenseCatalog.entries(includeLocalSpeechModels: false)

    var body: some View {
        List {
            Section {
                Text("Dante for Creators builds on open-source software and typefaces. We gratefully acknowledge the following contributors and licenses.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Open Source Licenses") {
                ForEach(entries) { entry in
                    NavigationLink {
                        LicenseDetailView(entry: entry)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.name)
                                .font(.body.weight(.semibold))
                            Text(entry.licenseType)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(entry.copyright)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LicenseDetailView: View {
    let entry: OpenSourceLicenseEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.licenseType)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    Text(entry.copyright)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(entry.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let urlString = entry.urlString, let url = URL(string: urlString) {
                    Link(destination: url) {
                        Label("Visit Project Page", systemImage: "arrow.up.right.square")
                            .font(.subheadline.weight(.medium))
                    }
                }

                Divider()

                Text(entry.fullText)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .navigationTitle(entry.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
