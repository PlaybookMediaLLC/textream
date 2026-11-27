//
//  OpenSourceLicensesView.swift
//  Dante for Creators
//

import AppKit
import Foundation
import SwiftUI

struct OpenSourceLicensesView: View {
    @Environment(\.dismiss) private var dismiss
    private let entries = OpenSourceLicenseCatalog.entries(includeLocalSpeechModels: true)
    @State private var selectedID: String = "textream"

    private var selectedEntry: OpenSourceLicenseEntry {
        entries.first { $0.id == selectedID } ?? entries[0]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                List(entries, selection: $selectedID) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.system(size: 13, weight: .semibold))
                        Text(entry.licenseType)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .tag(entry.id)
                }
                .listStyle(.sidebar)
                .frame(width: 210)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(selectedEntry.name)
                                    .font(.title3.weight(.semibold))
                                Text(selectedEntry.copyright)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let urlString = selectedEntry.urlString,
                               let url = URL(string: urlString) {
                                Link("Project Page", destination: url)
                                    .font(.caption.weight(.medium))
                            }
                        }

                        Text(selectedEntry.summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        Divider()

                        Text(selectedEntry.fullText)
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(18)
                }
            }

            Divider()

            HStack {
                Text(DanteAppLinks.copyrightNotice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(12)
        }
        .frame(width: 680, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
