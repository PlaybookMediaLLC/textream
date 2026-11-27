import Foundation
import SwiftUI

struct CreatorOnboardingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AppModel
    @State private var step = 0
    @State private var selectedPresetID: CreatorPresetID = .shortsReels

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    if step == 0 {
                        welcomeContent
                    } else {
                        permissionsContent
                    }
                }
                .scrollIndicators(.hidden)

                VStack(spacing: 10) {
                    if step == 0 {
                        Button {
                            withAnimation(.snappy) { step = 1 }
                        } label: {
                            Text("Continue")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(Color.accentColor)
                    } else {
                        Button {
                            model.apply(preset: CreatorPreset.preset(for: selectedPresetID))
                            model.markOnboardingCompleted()
                            dismiss()
                        } label: {
                            Text("Start Creating")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(Color.accentColor)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if step > 0 {
                        Button("Back") {
                            withAnimation(.snappy) { step = 0 }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") {
                        model.markOnboardingCompleted()
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var welcomeContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(spacing: 10) {
                Image("DanteLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)

                Text(DanteAppLinks.appName)
                    .font(.title2.bold())

                Text("Smart voice-following teleprompter built for creators on iPhone, iPad, and Mac.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                Label("Smart Follow Recovery", systemImage: "waveform.path.ecg")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Pause naturally, ad-lib a thought, skip ahead, or re-read a sentence—Dante realigns automatically without losing your place.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 10) {
                Text("CHOOSE YOUR FORMAT PRESET")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                ForEach(CreatorPreset.all) { preset in
                    let isSelected = selectedPresetID == preset.id
                    Button {
                        withAnimation(.snappy) { selectedPresetID = preset.id }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: preset.systemImage)
                                .font(.title3)
                                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(preset.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(preset.targetWPM) WPM")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                Text(preset.tagline)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(14)
                        .background(
                            isSelected ? Color.accentColor.opacity(0.14) : Color.white.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isSelected ? Color.accentColor.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
    }

    private var permissionsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Privacy-First Permissions")
                    .font(.title2.bold())
                Text("Dante asks for access only when you use each feature. No account, no ads, and no analytics.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            permissionRow(
                icon: "camera.fill",
                title: "Camera",
                detail: "Used in Record mode or when you turn on the camera behind your script. Your teleprompter overlay is presenter-only and never appears in saved video."
            )

            permissionRow(
                icon: "mic.fill",
                title: "Microphone",
                detail: "Used to record video audio and listen for voice pacing. Classic Read mode works without microphone access."
            )

            permissionRow(
                icon: "text.bubble.fill",
                title: "Apple Speech Recognition",
                detail: "Highlights each word in real time as you speak in Word Tracking mode."
            )

            permissionRow(
                icon: "photo.on.rectangle.angled",
                title: "Photos Library",
                detail: "Uses add-only access to save recordings. Read/write access is requested only if you open the saved-recordings gallery."
            )
        }
        .padding(20)
    }

    private func permissionRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }
}
