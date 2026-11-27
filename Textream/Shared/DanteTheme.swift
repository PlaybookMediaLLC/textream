//
//  DanteTheme.swift
//  Dante for Creators
//
//  Shared adaptive Dark & Light studio design system inspired by sleek
//  minimalist command workspaces: achromatic layered surfaces, crisp 1px
//  hairline borders, restrained typography, and cobalt-blue primary accents.
//

import Foundation
import SwiftUI

#if os(macOS)
import AppKit
#endif

// MARK: - App Appearance

enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    /// Cycles System -> Dark -> Light -> System for one-click theme switching.
    func next() -> AppAppearance {
        switch self {
        case .system: return .dark
        case .dark:   return .light
        case .light:  return .system
        }
    }

    #if os(macOS)
    @MainActor
    func applyToApplication() {
        guard let app = NSApp else { return }
        switch self {
        case .system:
            app.appearance = nil
        case .light:
            app.appearance = NSAppearance(named: .aqua)
        case .dark:
            app.appearance = NSAppearance(named: .darkAqua)
        }
    }
    #endif
}

// MARK: - Studio Palette

struct DantePalette: Sendable {
    let colorScheme: ColorScheme

    var isDark: Bool { colorScheme == .dark }

    /// Left navigation rail & outer window chrome (`#09090A` dark / `#F4F4F6` light).
    var sidebarBackground: Color {
        isDark
            ? Color(red: 9.0 / 255.0, green: 9.0 / 255.0, blue: 10.0 / 255.0)
            : Color(red: 244.0 / 255.0, green: 244.0 / 255.0, blue: 246.0 / 255.0)
    }

    /// Primary workspace canvas (`#121213` dark / `#FFFFFF` light).
    var canvasBackground: Color {
        isDark
            ? Color(red: 18.0 / 255.0, green: 18.0 / 255.0, blue: 19.0 / 255.0)
            : Color.white
    }

    /// Card, template tile, and control surface (`#1A1A1B` dark / `#F7F7F9` light).
    var surface: Color {
        isDark
            ? Color(red: 26.0 / 255.0, green: 26.0 / 255.0, blue: 27.0 / 255.0)
            : Color(red: 247.0 / 255.0, green: 247.0 / 255.0, blue: 249.0 / 255.0)
    }

    /// Hover / active pill fill (`#212123` dark / `#EFEFF2` light).
    var surfaceHover: Color {
        isDark
            ? Color(red: 33.0 / 255.0, green: 33.0 / 255.0, blue: 35.0 / 255.0)
            : Color(red: 239.0 / 255.0, green: 239.0 / 255.0, blue: 242.0 / 255.0)
    }

    /// Floating Quick Composer / elevated modal card (`#222223` dark / `#FFFFFF` light).
    var elevatedSurface: Color {
        isDark
            ? Color(red: 34.0 / 255.0, green: 34.0 / 255.0, blue: 35.0 / 255.0)
            : Color.white
    }

    /// Full-width grouped list section band (`#181819` dark / `#F5F5F7` light).
    var sectionHeaderBackground: Color {
        isDark
            ? Color(red: 24.0 / 255.0, green: 24.0 / 255.0, blue: 25.0 / 255.0)
            : Color(red: 245.0 / 255.0, green: 245.0 / 255.0, blue: 247.0 / 255.0)
    }

    /// Active tab / segmented control pill (`#242426` dark / `#FFFFFF` light).
    var activeTabBackground: Color {
        isDark
            ? Color(red: 36.0 / 255.0, green: 36.0 / 255.0, blue: 38.0 / 255.0)
            : Color.white
    }

    /// Crisp 1px hairline border (`rgba(255,255,255,0.08)` dark / `rgba(0,0,0,0.08)` light).
    var borderSubtle: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }

    /// Emphasized hairline border for floating modals and active chips.
    var borderStrong: Color {
        isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.14)
    }

    /// Primary ink (`#F4F4F5` dark / `#111113` light).
    var textPrimary: Color {
        isDark
            ? Color(red: 244.0 / 255.0, green: 244.0 / 255.0, blue: 245.0 / 255.0)
            : Color(red: 17.0 / 255.0, green: 17.0 / 255.0, blue: 19.0 / 255.0)
    }

    /// Secondary ink (`#9A9AA0` dark / `#5C5C64` light).
    var textSecondary: Color {
        isDark
            ? Color(red: 154.0 / 255.0, green: 154.0 / 255.0, blue: 160.0 / 255.0)
            : Color(red: 92.0 / 255.0, green: 92.0 / 255.0, blue: 100.0 / 255.0)
    }

    /// Muted metadata / timestamps / shortcut hints (`#64646A` dark / `#8E8E96` light).
    var textTertiary: Color {
        isDark
            ? Color(red: 100.0 / 255.0, green: 100.0 / 255.0, blue: 106.0 / 255.0)
            : Color(red: 142.0 / 255.0, green: 142.0 / 255.0, blue: 150.0 / 255.0)
    }

    /// Signature cobalt blue primary action & indicator accent (`#456AF6` dark / `#3B5FEF` light).
    var accent: Color {
        isDark
            ? Color(red: 69.0 / 255.0, green: 106.0 / 255.0, blue: 246.0 / 255.0)
            : Color(red: 59.0 / 255.0, green: 95.0 / 255.0, blue: 239.0 / 255.0)
    }

    var accentSubtle: Color {
        accent.opacity(isDark ? 0.16 : 0.11)
    }

    var keycapBackground: Color {
        isDark
            ? Color(red: 43.0 / 255.0, green: 43.0 / 255.0, blue: 46.0 / 255.0)
            : Color(red: 235.0 / 255.0, green: 235.0 / 255.0, blue: 240.0 / 255.0)
    }

    var scrim: Color {
        isDark ? Color.black.opacity(0.56) : Color.black.opacity(0.24)
    }

    var statusSuccess: Color {
        isDark
            ? Color(red: 52.0 / 255.0, green: 211.0 / 255.0, blue: 153.0 / 255.0)
            : Color(red: 16.0 / 255.0, green: 150.0 / 255.0, blue: 96.0 / 255.0)
    }

    var statusWarning: Color {
        isDark
            ? Color(red: 251.0 / 255.0, green: 191.0 / 255.0, blue: 36.0 / 255.0)
            : Color(red: 217.0 / 255.0, green: 119.0 / 255.0, blue: 6.0 / 255.0)
    }

    var statusDanger: Color {
        isDark
            ? Color(red: 248.0 / 255.0, green: 113.0 / 255.0, blue: 113.0 / 255.0)
            : Color(red: 220.0 / 255.0, green: 38.0 / 255.0, blue: 38.0 / 255.0)
    }
}

// MARK: - Setup Checklist Progress Model

struct CreatorSetupStep: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let isCompleted: Bool
}

struct CreatorSetupChecklistState: Equatable, Sendable {
    let steps: [CreatorSetupStep]

    var completedCount: Int {
        steps.filter(\.isCompleted).count
    }

    var totalCount: Int {
        steps.count
    }

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var progressLabel: String {
        "\(completedCount) of \(totalCount)"
    }

    var isAllComplete: Bool {
        totalCount > 0 && completedCount == totalCount
    }

    static func evaluate(
        hasChosenPreset: Bool,
        hasConfiguredGuidance: Bool,
        hasCustomScript: Bool,
        hasRunSession: Bool
    ) -> CreatorSetupChecklistState {
        CreatorSetupChecklistState(steps: [
            CreatorSetupStep(id: "preset", title: "Pick a creator format preset", isCompleted: hasChosenPreset),
            CreatorSetupStep(id: "guidance", title: "Configure Smart Follow or Classic", isCompleted: hasConfiguredGuidance),
            CreatorSetupStep(id: "script", title: "Create or import a script", isCompleted: hasCustomScript),
            CreatorSetupStep(id: "session", title: "Run your first prompter session", isCompleted: hasRunSession)
        ])
    }
}

// MARK: - Reusable Studio Chrome Components

/// Minimal monochrome keycap badge (e.g., `⌘K`, `↩`, `Esc`).
struct DanteKeycapBadge: View {
    let label: String
    let palette: DantePalette

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(palette.textSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(palette.keycapBackground, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(palette.borderSubtle, lineWidth: 1)
            )
    }
}

/// Full-width collapsible section header band matching sleek studio tables (`Pinned  2`, `Templates  4`).
struct DanteSectionHeaderBand: View {
    let title: String
    let count: Int
    var isExpanded: Bool = true
    var onToggle: (() -> Void)? = nil
    let palette: DantePalette

    var body: some View {
        let content = HStack(spacing: 6) {
            if onToggle != nil {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(palette.textTertiary)
                    .frame(width: 10)
            }
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
            Text("\(count)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(palette.sectionHeaderBackground)
        .overlay(alignment: .top) {
            Rectangle().fill(palette.borderSubtle).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.borderSubtle).frame(height: 1)
        }

        if let onToggle {
            Button(action: onToggle) {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }
}

/// Filter pill matching `Preset | is | YouTube Studio | ×`.
struct DanteFilterPill: View {
    let icon: String
    let field: String
    let relation: String
    let value: String
    let palette: DantePalette
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(palette.textTertiary)
                Text(field)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)

            Rectangle().fill(palette.borderSubtle).frame(width: 1, height: 14)

            Text(relation)
                .font(.system(size: 11))
                .foregroundStyle(palette.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)

            Rectangle().fill(palette.borderSubtle).frame(width: 1, height: 14)

            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)

            Rectangle().fill(palette.borderSubtle).frame(width: 1, height: 14)

            Button(action: onClear) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(palette.textTertiary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
        }
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        )
    }
}
