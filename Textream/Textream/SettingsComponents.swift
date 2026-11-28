//
//  SettingsComponents.swift
//  Dante for Creators
//
//  Reusable modern Settings UI primitives: clean grouped cards, hairline row
//  dividers, bordered dropdown pills, visual appearance thumbnails, color
//  swatch + hex controls, copyable pills, cached QR codes, and live prompt preview.
//

import AppKit
import CoreImage.CIFilterBuiltins
import SwiftUI

// MARK: - Page Header

struct SettingsPageHeader: View {
    let title: String
    let subtitle: String?
    let palette: DantePalette

    init(title: String, subtitle: String? = nil, palette: DantePalette) {
        self.title = title
        self.subtitle = subtitle
        self.palette = palette
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .tracking(-0.3)
                .foregroundStyle(palette.textPrimary)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Section & Card Container

struct SettingsSection<Trailing: View, Content: View>: View {
    let title: String?
    let subtitle: String?
    let palette: DantePalette
    @ViewBuilder let trailing: () -> Trailing
    @ViewBuilder let content: () -> Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        palette: DantePalette,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.palette = palette
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if title != nil || subtitle != nil || Trailing.self != EmptyView.self {
                HStack(alignment: .lastTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        if let title {
                            Text(title)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(palette.textPrimary)
                        }
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 12)

                    trailing()
                }
            }

            SettingsCard(palette: palette) {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension SettingsSection where Trailing == EmptyView {
    init(
        title: String? = nil,
        subtitle: String? = nil,
        palette: DantePalette,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            palette: palette,
            trailing: { EmptyView() },
            content: content
        )
    }
}

struct SettingsCard<Content: View>: View {
    let palette: DantePalette
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            palette.settingsCardBackground,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
        .shadow(
            color: palette.isDark ? Color.clear : Color.black.opacity(0.025),
            radius: 2,
            x: 0,
            y: 1
        )
    }
}

// MARK: - Hairline Row Divider

struct SettingsRowDivider: View {
    let palette: DantePalette

    var body: some View {
        Rectangle()
            .fill(palette.settingsDivider)
            .frame(height: 1)
    }
}

// MARK: - Standard Horizontal Setting Row

struct SettingsRow<Control: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let iconColor: Color?
    let palette: DantePalette
    @ViewBuilder let control: () -> Control

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color? = nil,
        palette: DantePalette,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.palette = palette
        self.control = control
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let icon {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(palette.surface)
                        .frame(width: 34, height: 34)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(palette.borderSubtle, lineWidth: 1)
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(iconColor ?? palette.textSecondary)
                }
                .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2.5) {
                Text(title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            control()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(minHeight: 54)
    }
}

// MARK: - Toggle Switch Row

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let iconColor: Color?
    @Binding var isOn: Bool
    let palette: DantePalette

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color? = nil,
        isOn: Binding<Bool>,
        palette: DantePalette
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self._isOn = isOn
        self.palette = palette
    }

    var body: some View {
        SettingsRow(
            title: title,
            subtitle: subtitle,
            icon: icon,
            iconColor: iconColor,
            palette: palette
        ) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(palette.accent)
                .controlSize(.small)
                .accessibilityLabel(title)
        }
    }
}

// MARK: - Bordered Dropdown Menu Picker

struct SettingsMenuPicker<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    let labelForOption: (Option) -> String
    let iconForOption: ((Option) -> String)?
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let accessibilityTitle: String?
    let palette: DantePalette

    init(
        options: [Option],
        selection: Binding<Option>,
        minWidth: CGFloat = 132,
        maxWidth: CGFloat = 220,
        accessibilityTitle: String? = nil,
        palette: DantePalette,
        iconForOption: ((Option) -> String)? = nil,
        labelForOption: @escaping (Option) -> String
    ) {
        self.options = options
        self._selection = selection
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.accessibilityTitle = accessibilityTitle
        self.palette = palette
        self.iconForOption = iconForOption
        self.labelForOption = labelForOption
    }

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    selection = option
                } label: {
                    HStack {
                        if let icon = iconForOption?(option) {
                            Label(labelForOption(option), systemImage: icon)
                        } else {
                            Text(labelForOption(option))
                        }
                        if option == selection {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            SettingsDropdownPillLabel(
                text: labelForOption(selection),
                icon: iconForOption?(selection),
                minWidth: minWidth,
                maxWidth: maxWidth,
                palette: palette
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(accessibilityTitle ?? labelForOption(selection))
        .accessibilityValue(labelForOption(selection))
    }
}

/// Shared bordered dropdown pill surface used across `SettingsMenuPicker` and custom menus.
struct SettingsDropdownPillLabel: View {
    let text: String
    let icon: String?
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let palette: DantePalette

    init(
        text: String,
        icon: String? = nil,
        minWidth: CGFloat = 148,
        maxWidth: CGFloat = 220,
        palette: DantePalette
    ) {
        self.text = text
        self.icon = icon
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.palette = palette
    }

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
            }
            Text(text)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            Image(systemName: "chevron.down")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(palette.textTertiary)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .frame(minWidth: minWidth, maxWidth: maxWidth)
        .background(
            palette.elevatedSurface,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
    }
}

// MARK: - Segmented Pill Control

struct SettingsSegmentedPill<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    let palette: DantePalette
    let labelForOption: (Option) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                let isSelected = option == selection
                let label = labelForOption(option)
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selection = option
                    }
                } label: {
                    Text(label)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? palette.textPrimary : palette.textSecondary)
                        .lineLimit(1)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isSelected ? palette.activeTabBackground : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(isSelected ? palette.borderSubtle : Color.clear, lineWidth: 1)
                        )
                        .shadow(
                            color: (isSelected && !palette.isDark) ? Color.black.opacity(0.05) : Color.clear,
                            radius: 1.5,
                            x: 0,
                            y: 1
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(
            palette.surface,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
        .fixedSize()
    }
}

// MARK: - Slider Row

struct SettingsSliderRow: View {
    let title: String
    let subtitle: String?
    let valueLabel: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let leadingLabel: String?
    let trailingLabel: String?
    let palette: DantePalette

    init(
        title: String,
        subtitle: String? = nil,
        valueLabel: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        leadingLabel: String? = nil,
        trailingLabel: String? = nil,
        palette: DantePalette
    ) {
        self.title = title
        self.subtitle = subtitle
        self.valueLabel = valueLabel
        self._value = value
        self.range = range
        self.step = step
        self.leadingLabel = leadingLabel
        self.trailingLabel = trailingLabel
        self.palette = palette
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2.5) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(valueLabel)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.textPrimary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        palette.surface,
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(palette.borderSubtle, lineWidth: 1)
                    )
                    .fixedSize()
            }

            VStack(spacing: 4) {
                Slider(value: $value, in: range, step: step)
                    .tint(palette.accent)
                    .accessibilityLabel(title)
                    .accessibilityValue(valueLabel)

                if leadingLabel != nil || trailingLabel != nil {
                    HStack {
                        Text(leadingLabel ?? "")
                        Spacer()
                        Text(trailingLabel ?? "")
                    }
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.textTertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - Copyable Value Pill

struct SettingsCopyablePill: View {
    let value: String
    let accentValue: Bool
    let isSensitive: Bool
    let accessibilityContext: String
    let palette: DantePalette

    @State private var didCopy = false
    @State private var resetTask: Task<Void, Never>?

    init(
        value: String,
        accentValue: Bool = false,
        isSensitive: Bool = false,
        accessibilityContext: String = "value",
        palette: DantePalette
    ) {
        self.value = value
        self.accentValue = accentValue
        self.isSensitive = isSensitive
        self.accessibilityContext = accessibilityContext
        self.palette = palette
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(accentValue ? palette.accent : palette.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            Button {
                copyToPasteboard()
                withAnimation(.easeInOut(duration: 0.15)) {
                    didCopy = true
                }
                resetTask?.cancel()
                resetTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1500))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.15)) {
                        didCopy = false
                    }
                }
            } label: {
                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(didCopy ? palette.statusSuccess : palette.textSecondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(didCopy ? "Copied" : "Copy to clipboard")
            .accessibilityLabel(didCopy ? "Copied \(accessibilityContext)" : "Copy \(accessibilityContext)")
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 5)
        .background(
            palette.surface,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
        .onDisappear {
            resetTask?.cancel()
        }
    }

    private func copyToPasteboard() {
        let pasteboard = NSPasteboard.general
        if isSensitive {
            pasteboard.prepareForNewContents(with: .currentHostOnly)
            pasteboard.setString(value, forType: .string)
            pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
            pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        } else {
            pasteboard.clearContents()
            pasteboard.setString(value, forType: .string)
        }
    }
}

// MARK: - Cached QR Code View

struct SettingsQRCodeView: View {
    private static let ciContext = CIContext()

    let url: String
    let size: CGFloat
    let palette: DantePalette

    @State private var renderedImage: NSImage?

    init(url: String, size: CGFloat = 86, palette: DantePalette) {
        self.url = url
        self.size = size
        self.palette = palette
    }

    var body: some View {
        Group {
            if let renderedImage {
                Image(nsImage: renderedImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
        .padding(6)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
        .accessibilityLabel("QR code for \(url)")
        .task(id: url) {
            renderedImage = Self.renderQRCode(from: url)
        }
    }

    private static func renderQRCode(from string: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let ciImage = filter.outputImage else { return nil }
        let scale = 10.0
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = ciContext.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: scaled.extent.width, height: scaled.extent.height))
    }
}

// MARK: - Status Pill

struct SettingsStatusPill: View {
    let label: String
    let color: Color
    let palette: DantePalette

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            palette.surface,
            in: Capsule()
        )
        .overlay(
            Capsule()
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
        .fixedSize()
    }
}

// MARK: - Action & External Link Buttons

struct SettingsActionButton: View {
    let title: String
    let icon: String?
    let isDestructive: Bool
    let isProminent: Bool
    let isDisabled: Bool
    let palette: DantePalette
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        isDestructive: Bool = false,
        isProminent: Bool = false,
        isDisabled: Bool = false,
        palette: DantePalette,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isDestructive = isDestructive
        self.isProminent = isProminent
        self.isDisabled = isDisabled
        self.palette = palette
        self.action = action
    }

    var body: some View {
        Button(role: isDestructive ? .destructive : nil, action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11.5, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .opacity(isDisabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .fixedSize()
    }

    private var foregroundColor: Color {
        if isDestructive { return palette.statusDanger }
        if isProminent { return .white }
        return palette.textPrimary
    }

    private var backgroundColor: Color {
        if isProminent { return palette.accent }
        if isDestructive { return palette.statusDanger.opacity(palette.isDark ? 0.14 : 0.08) }
        return palette.elevatedSurface
    }

    private var borderColor: Color {
        if isProminent { return Color.clear }
        if isDestructive { return palette.statusDanger.opacity(0.28) }
        return palette.borderSubtle
    }
}

struct SettingsExternalLinkPill: View {
    let title: String
    let destination: URL
    let palette: DantePalette

    var body: some View {
        Link(destination: destination) {
            HStack(spacing: 4) {
                Text(title)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(palette.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5.5)
            .background(
                palette.elevatedSurface,
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(palette.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
}

// MARK: - Visual Mode Preview Picker (System / Light / Dark)

struct SettingsVisualModePicker: View {
    @Binding var selection: AppAppearance
    let palette: DantePalette

    var body: some View {
        HStack(spacing: 10) {
            ForEach(AppAppearance.allCases) { appearance in
                let isSelected = selection == appearance
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selection = appearance
                    }
                } label: {
                    VStack(spacing: 5) {
                        modeThumbnail(for: appearance)
                            .frame(width: 68, height: 46)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(
                                        isSelected ? palette.accent : palette.borderSubtle,
                                        lineWidth: isSelected ? 2 : 1
                                    )
                            )
                            .shadow(
                                color: isSelected ? palette.accent.opacity(0.22) : Color.clear,
                                radius: 4,
                                x: 0,
                                y: 1
                            )

                        Text(appearance.label)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? palette.textPrimary : palette.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(appearance.label) appearance")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .fixedSize()
    }

    @ViewBuilder
    private func modeThumbnail(for appearance: AppAppearance) -> some View {
        switch appearance {
        case .light:
            miniWindowArtwork(isDark: false)
        case .dark:
            miniWindowArtwork(isDark: true)
        case .system:
            ZStack {
                miniWindowArtwork(isDark: false)
                miniWindowArtwork(isDark: true)
                    .mask(
                        HStack(spacing: 0) {
                            Color.clear
                            Color.black
                        }
                    )
            }
        }
    }

    private func miniWindowArtwork(isDark: Bool) -> some View {
        let rail = isDark
            ? Color(red: 15.0 / 255.0, green: 15.0 / 255.0, blue: 17.0 / 255.0)
            : Color(red: 242.0 / 255.0, green: 242.0 / 255.0, blue: 246.0 / 255.0)
        let canvas = isDark
            ? Color(red: 26.0 / 255.0, green: 26.0 / 255.0, blue: 29.0 / 255.0)
            : Color.white
        let lineStrong = isDark ? Color.white.opacity(0.55) : Color.black.opacity(0.55)
        let lineSoft = isDark ? Color.white.opacity(0.22) : Color.black.opacity(0.18)

        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 1.5).fill(lineSoft).frame(width: 9, height: 2.5)
                RoundedRectangle(cornerRadius: 1.5).fill(lineSoft).frame(width: 11, height: 2.5)
                RoundedRectangle(cornerRadius: 1.5).fill(lineSoft).frame(width: 8, height: 2.5)
                Spacer(minLength: 0)
            }
            .padding(.top, 9)
            .padding(.leading, 5)
            .frame(width: 19)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .background(rail)

            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: 1.5).fill(lineStrong).frame(width: 22, height: 3)
                RoundedRectangle(cornerRadius: 1.5).fill(lineSoft).frame(width: 30, height: 2.5)
                RoundedRectangle(cornerRadius: 1.5).fill(lineSoft).frame(width: 18, height: 2.5)
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    Circle()
                        .fill(palette.accent)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(canvas)
        }
    }
}

// MARK: - Visual Font Family Preview Grid

struct SettingsFontCardGrid: View {
    @Binding var selection: FontFamilyPreset
    let highlightColor: Color
    let palette: DantePalette

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(FontFamilyPreset.allCases) { preset in
                let isSelected = selection == preset
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selection = preset
                    }
                } label: {
                    VStack(spacing: 7) {
                        ZStack(alignment: .bottomTrailing) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Ag")
                                    .font(Font(preset.font(size: 19, weight: .semibold)))
                                    .foregroundStyle(isSelected ? palette.accent : palette.textPrimary)

                                VStack(alignment: .leading, spacing: 3) {
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(palette.textTertiary.opacity(0.45))
                                        .frame(width: 58, height: 3)
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(palette.textTertiary.opacity(0.25))
                                        .frame(width: 40, height: 3)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(11)

                            Circle()
                                .fill(highlightColor == .white && !palette.isDark ? palette.accent : highlightColor)
                                .frame(width: 7, height: 7)
                                .padding(9)
                        }
                        .frame(height: 68)
                        .background(
                            isSelected ? palette.accentSubtle : palette.surface,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(
                                    isSelected ? palette.accent : palette.borderSubtle,
                                    lineWidth: isSelected ? 1.75 : 1
                                )
                        )

                        Text(preset.label)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? palette.textPrimary : palette.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(preset.label) font")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(16)
    }
}

// MARK: - Color Swatch + Hex Row

struct SettingsColorSwatchRow: View {
    let title: String
    let subtitle: String
    @Binding var selection: FontColorPreset
    let palette: DantePalette

    var body: some View {
        SettingsRow(title: title, subtitle: subtitle, palette: palette) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    ForEach(FontColorPreset.allCases) { preset in
                        let isSelected = selection == preset
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selection = preset
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(preset.color)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(
                                                preset == .white ? palette.borderStrong : Color.black.opacity(0.14),
                                                lineWidth: 1
                                            )
                                    )
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9.5, weight: .bold))
                                        .foregroundStyle(checkmarkColor(for: preset))
                                }
                            }
                            .padding(2)
                            .overlay(
                                Circle()
                                    .strokeBorder(isSelected ? palette.accent : Color.clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .help(preset.label)
                        .accessibilityLabel("\(title): \(preset.label)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }

                // Active color swatch + monospaced hex badge
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(selection.color)
                        .frame(width: 14, height: 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(palette.borderStrong, lineWidth: 1)
                        )
                    Text(selection.hexString)
                        .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(palette.textPrimary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    palette.surface,
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(palette.borderSubtle, lineWidth: 1)
                )
            }
            .fixedSize()
        }
    }

    private func checkmarkColor(for preset: FontColorPreset) -> Color {
        switch preset {
        case .white, .yellow, .green, .orange:
            return .black
        case .blue, .pink:
            return .white
        }
    }
}

// MARK: - Inline Live Teleprompter Preview Strip

struct SettingsInlinePrompterPreview: View {
    let fontFamily: FontFamilyPreset
    let fontSize: FontSizePreset
    let highlightColor: FontColorPreset
    let cueColor: FontColorPreset
    let cueBrightness: CueBrightness
    let palette: DantePalette

    private var previewPointSize: CGFloat {
        switch fontSize {
        case .xs: return 13
        case .sm: return 15
        case .lg: return 18
        case .xl: return 22
        }
    }

    private var previewAttributedText: AttributedString {
        var spoken = AttributedString("Clear communication begins ")
        spoken.foregroundColor = highlightColor.color

        var cue = AttributedString("[look at camera] ")
        cue.foregroundColor = cueColor.color.opacity(cueBrightness.unreadOpacity)

        var upcoming = AttributedString("when we slow down and connect.")
        upcoming.foregroundColor = Color.white.opacity(0.42)

        return spoken + cue + upcoming
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(palette.accent)
                    .frame(width: 6, height: 6)
                Text("LIVE PROMPTER PREVIEW")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .tracking(0.6)
                Spacer()
                Text("\(fontFamily.label) · \(fontSize.label) (\(Int(fontSize.pointSize))pt)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            Text(previewAttributedText)
                .font(Font(fontFamily.font(size: previewPointSize, weight: .semibold)))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(red: 13.0 / 255.0, green: 13.0 / 255.0, blue: 15.0 / 255.0),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
