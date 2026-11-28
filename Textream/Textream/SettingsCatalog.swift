//
//  SettingsCatalog.swift
//  Dante for Creators
//
//  Navigation structure and live search index for the modernized Settings workspace.
//

import Foundation

// MARK: - Settings Tabs

enum SettingsTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    // Core
    case general
    case appearance
    case teleprompter
    case reading
    // Voice & AI
    case guidance
    case models
    // Studio
    case external
    case browser
    case director
    // Integrations
    case obs
    case shortcuts
    // System
    case about

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general:      return "General"
        case .appearance:   return "Appearance"
        case .teleprompter: return "Teleprompter"
        case .reading:      return "Reading"
        case .guidance:     return "Guidance"
        case .models:       return "Speech Models"
        case .external:     return "External Display"
        case .browser:      return "Remote"
        case .director:     return "Director"
        case .obs:          return "OBS Studio"
        case .shortcuts:    return "Shortcuts & Hardware"
        case .about:        return "About & Reset"
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            return "Workspace defaults, creator presets, cloud sync, and live session preferences."
        case .appearance:
            return "Workspace theme mode, teleprompter typography, and highlight color styling."
        case .teleprompter:
            return "Overlay presentation, display placement, dimensions, translucency, and pagination."
        case .reading:
            return "Eye-contact alignment, visual reading aids, and smart pacing tools."
        case .guidance:
            return "Voice tracking modes, speech recognition engine, microphone input, and scroll speed."
        case .models:
            return "Download and manage 100% on-device speech models for private offline tracking."
        case .external:
            return "Drive a dedicated teleprompter or beamsplitter-mirrored feed on an external display."
        case .browser:
            return "Mirror and control your live prompt from any phone, tablet, or TV browser on Wi-Fi."
        case .director:
            return "Let a producer or iOS Studio Remote control scripts and live sessions over your network."
        case .obs:
            return "Sync teleprompter start and stop automatically with OBS Studio WebSocket v5."
        case .shortcuts:
            return "Hands-free clickers, foot pedals, game controllers, and studio keyboard shortcuts."
        case .about:
            return "App version, creator setup resources, open-source licenses, and factory reset."
        }
    }

    var icon: String {
        switch self {
        case .general:      return "gearshape"
        case .appearance:   return "circle.lefthalf.filled"
        case .teleprompter: return "macwindow"
        case .reading:      return "book"
        case .guidance:     return "waveform"
        case .models:       return "cpu"
        case .external:     return "rectangle.on.rectangle"
        case .browser:      return "antenna.radiowaves.left.and.right"
        case .director:     return "megaphone"
        case .obs:          return "record.circle"
        case .shortcuts:    return "keyboard"
        case .about:        return "info.circle"
        }
    }

    var group: SettingsSidebarGroup {
        switch self {
        case .general, .appearance, .teleprompter, .reading:
            return .core
        case .guidance, .models:
            return .voiceAndAI
        case .external, .browser, .director:
            return .studio
        case .obs, .shortcuts:
            return .integrations
        case .about:
            return .system
        }
    }
}

// MARK: - Sidebar Groups

enum SettingsSidebarGroup: String, CaseIterable, Identifiable, Sendable {
    case core
    case voiceAndAI
    case studio
    case integrations
    case system

    var id: String { rawValue }

    /// `nil` for the top core group so General & Appearance sit directly under search.
    var title: String? {
        switch self {
        case .core:         return nil
        case .voiceAndAI:   return "Voice & AI"
        case .studio:       return "Studio"
        case .integrations: return "Integrations"
        case .system:       return "System"
        }
    }

    var tabs: [SettingsTab] {
        SettingsTab.allCases.filter { $0.group == self }
    }
}

// MARK: - Live Settings Search Index

struct SettingsSearchItem: Identifiable, Hashable, Sendable {
    let id: String
    let tab: SettingsTab
    let section: String
    let title: String
    let subtitle: String
    let keywords: [String]
    let icon: String

    func matches(tokens: [String]) -> Bool {
        guard !tokens.isEmpty else { return true }
        let searchable = [
            title,
            subtitle,
            section,
            tab.label,
            keywords.joined(separator: " ")
        ]
        .joined(separator: " ")
        .lowercased()

        return tokens.allSatisfy { searchable.contains($0) }
    }
}

enum SettingsSearchIndex {
    static let allItems: [SettingsSearchItem] = [
        // General
        SettingsSearchItem(
            id: "general.preset",
            tab: .general,
            section: "Studio workflow",
            title: "Quick Creator Preset",
            subtitle: "Apply recommended teleprompter settings for YouTube, Shorts, Podcasts, or Keynotes.",
            keywords: ["preset", "youtube", "shorts", "reels", "tiktok", "podcast", "keynote", "template"],
            icon: "sparkles"
        ),
        SettingsSearchItem(
            id: "general.icloud",
            tab: .general,
            section: "Studio workflow",
            title: "iCloud Script Sync",
            subtitle: "Automatically sync scripts and pages across Mac, iPhone, and iPad via iCloud.",
            keywords: ["icloud", "cloud", "sync", "iphone", "ipad", "cross-device"],
            icon: "icloud"
        ),
        SettingsSearchItem(
            id: "general.awake",
            tab: .general,
            section: "Studio workflow",
            title: "Keep Screen Awake",
            subtitle: "Prevent display and system sleep while the teleprompter is active.",
            keywords: ["sleep", "awake", "display", "dim", "energy"],
            icon: "sun.max"
        ),
        SettingsSearchItem(
            id: "general.checklist",
            tab: .general,
            section: "Studio workflow",
            title: "Show Setup Checklist",
            subtitle: "Display onboarding progress steps in the main workspace sidebar.",
            keywords: ["onboarding", "checklist", "setup", "sidebar", "getting started"],
            icon: "checklist"
        ),
        SettingsSearchItem(
            id: "general.retake",
            tab: .general,
            section: "Live session",
            title: "Smart Retake Recovery",
            subtitle: "Automatically rewind when you restart a sentence mid-take, or press ← manually.",
            keywords: ["retake", "rewind", "recovery", "restart", "sentence"],
            icon: "arrow.counterclockwise"
        ),
        SettingsSearchItem(
            id: "general.pacing",
            tab: .general,
            section: "Live session",
            title: "Live Pacing Coach",
            subtitle: "Show real-time WPM and schedule delta against your script's target pace.",
            keywords: ["pacing", "wpm", "coach", "tempo", "speed", "cadence"],
            icon: "gauge.with.needle"
        ),

        // Appearance
        SettingsSearchItem(
            id: "appearance.mode",
            tab: .appearance,
            section: "Mode",
            title: "App Theme Mode",
            subtitle: "Switch between System, Light, and Dark studio appearances.",
            keywords: ["theme", "dark", "light", "system", "mode", "color scheme"],
            icon: "circle.lefthalf.filled"
        ),
        SettingsSearchItem(
            id: "appearance.preview",
            tab: .appearance,
            section: "Mode",
            title: "Live Overlay Preview",
            subtitle: "Show a live teleprompter preview while adjusting appearance and layout.",
            keywords: ["preview", "notch", "live", "overlay"],
            icon: "eye"
        ),
        SettingsSearchItem(
            id: "appearance.font",
            tab: .appearance,
            section: "Typography",
            title: "Teleprompter Font Family",
            subtitle: "Choose Sans, Serif, Mono, or OpenDyslexic typography for live scripts.",
            keywords: ["font", "typeface", "sans", "serif", "mono", "dyslexia", "opendyslexic"],
            icon: "textformat"
        ),
        SettingsSearchItem(
            id: "appearance.size",
            tab: .appearance,
            section: "Typography",
            title: "Text Size",
            subtitle: "Select XS (14pt), SM (16pt), LG (20pt), or XL (24pt) teleprompter text.",
            keywords: ["size", "font size", "xs", "sm", "lg", "xl", "large", "small"],
            icon: "textformat.size"
        ),
        SettingsSearchItem(
            id: "appearance.highlightColor",
            tab: .appearance,
            section: "Colors",
            title: "Highlight Color",
            subtitle: "Choose the active spoken text color (White, Yellow, Green, Blue, Pink, Orange).",
            keywords: ["color", "highlight", "accent", "white", "yellow", "green", "blue", "pink", "orange", "hex"],
            icon: "paintpalette"
        ),
        SettingsSearchItem(
            id: "appearance.cueColor",
            tab: .appearance,
            section: "Colors",
            title: "Stage Cue Color",
            subtitle: "Set the color for [bracketed] stage directions and delivery cues.",
            keywords: ["cue", "stage", "brackets", "annotation", "direction", "color"],
            icon: "quote.bubble"
        ),
        SettingsSearchItem(
            id: "appearance.cueBrightness",
            tab: .appearance,
            section: "Colors",
            title: "Cue Brightness",
            subtitle: "Adjust stage cue visibility from Dim to Bright.",
            keywords: ["cue", "brightness", "dim", "opacity", "contrast"],
            icon: "sun.min"
        ),

        // Teleprompter
        SettingsSearchItem(
            id: "teleprompter.mode",
            tab: .teleprompter,
            section: "Overlay mode",
            title: "Overlay Presentation Mode",
            subtitle: "Switch between Pinned to Notch, Floating Window, and Fullscreen teleprompter.",
            keywords: ["overlay", "notch", "pinned", "floating", "fullscreen", "window"],
            icon: "macwindow"
        ),
        SettingsSearchItem(
            id: "teleprompter.display",
            tab: .teleprompter,
            section: "Overlay mode",
            title: "Notch Display Placement",
            subtitle: "Follow your mouse across monitors or lock the notch to a fixed display.",
            keywords: ["display", "monitor", "screen", "follow mouse", "fixed"],
            icon: "display"
        ),
        SettingsSearchItem(
            id: "teleprompter.transparency",
            tab: .teleprompter,
            section: "Overlay mode",
            title: "Transparency & Glass Effect",
            subtitle: "Make the notch or floating window translucent so desktop content shows through.",
            keywords: ["transparency", "opacity", "glass", "blur", "see-through"],
            icon: "square.on.square.intersection.dashed"
        ),
        SettingsSearchItem(
            id: "teleprompter.cursor",
            tab: .teleprompter,
            section: "Overlay mode",
            title: "Follow Cursor",
            subtitle: "Keep the floating teleprompter attached near your cursor.",
            keywords: ["cursor", "mouse", "follow", "undocked", "floating"],
            icon: "cursorarrow.motionlines"
        ),
        SettingsSearchItem(
            id: "teleprompter.dimensions",
            tab: .teleprompter,
            section: "Dimensions",
            title: "Notch Width & Text Area Height",
            subtitle: "Resize the teleprompter viewport from 310–500px wide and 100–400px tall.",
            keywords: ["width", "height", "size", "dimensions", "resize", "viewport"],
            icon: "arrow.up.left.and.arrow.down.right"
        ),
        SettingsSearchItem(
            id: "teleprompter.screenshare",
            tab: .teleprompter,
            section: "Privacy & pagination",
            title: "Hide from Screen Sharing",
            subtitle: "Keep the teleprompter invisible during Zoom, Meet, OBS, and screen recordings.",
            keywords: ["screen share", "privacy", "zoom", "meet", "hide", "recording", "invisible"],
            icon: "eye.slash"
        ),
        SettingsSearchItem(
            id: "teleprompter.elapsed",
            tab: .teleprompter,
            section: "Privacy & pagination",
            title: "Elapsed Time",
            subtitle: "Display a running session timer inside the teleprompter header.",
            keywords: ["timer", "elapsed", "clock", "duration"],
            icon: "timer"
        ),
        SettingsSearchItem(
            id: "teleprompter.autonext",
            tab: .teleprompter,
            section: "Privacy & pagination",
            title: "Auto Next Page & Countdown",
            subtitle: "Automatically advance to the next script page after an optional countdown.",
            keywords: ["pagination", "next page", "auto", "countdown", "slides", "delay"],
            icon: "doc.on.doc"
        ),

        // Reading
        SettingsSearchItem(
            id: "reading.position",
            tab: .reading,
            section: "Layout & alignment",
            title: "Reading Position",
            subtitle: "Position the active line Centered or Near Top for natural camera eye contact.",
            keywords: ["reading position", "centered", "near top", "camera", "eye contact"],
            icon: "text.alignleft"
        ),
        SettingsSearchItem(
            id: "reading.dividers",
            tab: .reading,
            section: "Layout & alignment",
            title: "Show Paragraph Dividers",
            subtitle: "Separate source line breaks with extra breathing room and centered dots.",
            keywords: ["paragraph", "divider", "breaks", "spacing", "dots"],
            icon: "line.3.horizontal"
        ),
        SettingsSearchItem(
            id: "reading.lastSpoken",
            tab: .reading,
            section: "Layout & alignment",
            title: "Show Last Spoken Words",
            subtitle: "Display recently recognized words while Word Tracking is active.",
            keywords: ["spoken", "transcript", "caption", "recognized", "feedback"],
            icon: "captions.bubble"
        ),

        // Guidance
        SettingsSearchItem(
            id: "guidance.mode",
            tab: .guidance,
            section: "Tracking mode",
            title: "Listening Mode",
            subtitle: "Choose Word Tracking (Smart Follow), Voice-Activated, or Classic auto-scroll.",
            keywords: ["listening", "word tracking", "smart follow", "classic", "voice", "scroll"],
            icon: "waveform"
        ),
        SettingsSearchItem(
            id: "guidance.engine",
            tab: .guidance,
            section: "Tracking mode",
            title: "Speech Recognition Engine",
            subtitle: "Use built-in Apple Speech or a private on-device Local Model.",
            keywords: ["engine", "apple speech", "local", "offline", "ai", "asr"],
            icon: "waveform.path.ecg"
        ),
        SettingsSearchItem(
            id: "guidance.language",
            tab: .guidance,
            section: "Tracking mode",
            title: "Speech Language",
            subtitle: "Select the spoken language locale for Word Tracking recognition.",
            keywords: ["language", "locale", "english", "spanish", "french", "multilingual"],
            icon: "globe"
        ),
        SettingsSearchItem(
            id: "guidance.test",
            tab: .guidance,
            section: "Tracking mode",
            title: "Test Guidance",
            subtitle: "Run a live transcription check with your selected engine and microphone.",
            keywords: ["test", "diagnostics", "microphone test", "transcribe"],
            icon: "play.circle"
        ),
        SettingsSearchItem(
            id: "guidance.microphone",
            tab: .guidance,
            section: "Audio & pacing",
            title: "Microphone Input",
            subtitle: "Choose System Default or a dedicated studio USB/XLR audio input.",
            keywords: ["mic", "microphone", "audio", "input", "usb", "xlr"],
            icon: "mic"
        ),
        SettingsSearchItem(
            id: "guidance.speed",
            tab: .guidance,
            section: "Audio & pacing",
            title: "Scroll Speed",
            subtitle: "Configure words-per-second pacing for Classic and Voice-Activated modes.",
            keywords: ["speed", "scroll", "wps", "words per second", "tempo"],
            icon: "speedometer"
        ),

        // Speech Models
        SettingsSearchItem(
            id: "models.manager",
            tab: .models,
            section: "On-device models",
            title: "Manage Local Speech Models",
            subtitle: "Download, import, switch, or delete local GGUF speech models from Hugging Face.",
            keywords: ["models", "gguf", "hugging face", "download", "whisper", "nemotron", "canary", "parakeet", "qwen", "apple silicon", "ram"],
            icon: "cpu"
        ),

        // External Display
        SettingsSearchItem(
            id: "external.mode",
            tab: .external,
            section: "External output",
            title: "External Display Mode",
            subtitle: "Output a fullscreen teleprompter or mirrored view to an external monitor or Sidecar iPad.",
            keywords: ["external", "sidecar", "ipad", "monitor", "mirror", "beamsplitter", "rig"],
            icon: "rectangle.on.rectangle"
        ),
        SettingsSearchItem(
            id: "external.mirrorAxis",
            tab: .external,
            section: "External output",
            title: "Mirror Axis",
            subtitle: "Flip external display output Horizontally, Vertically, or on Both axes.",
            keywords: ["mirror", "flip", "horizontal", "vertical", "axis", "glass"],
            icon: "arrow.left.and.right.righttriangle.left.righttriangle.right"
        ),

        // Remote
        SettingsSearchItem(
            id: "remote.server",
            tab: .browser,
            section: "LAN browser server",
            title: "Enable Remote Connection",
            subtitle: "Serve a live web teleprompter with QR code and local Wi-Fi URL.",
            keywords: ["remote", "browser", "wifi", "lan", "qr", "phone", "tablet", "tv", "http", "port"],
            icon: "antenna.radiowaves.left.and.right"
        ),

        // Director
        SettingsSearchItem(
            id: "director.mode",
            tab: .director,
            section: "Director server",
            title: "Enable Director Mode & iOS Studio Remote",
            subtitle: "Allow a remote producer or iOS Studio Remote (with Bonjour PIN) to drive live scripts.",
            keywords: ["director", "producer", "pin", "pairing", "bonjour", "ios remote", "qr", "port"],
            icon: "megaphone"
        ),

        // OBS Studio
        SettingsSearchItem(
            id: "obs.connection",
            tab: .obs,
            section: "WebSocket connection",
            title: "OBS Studio WebSocket v5",
            subtitle: "Connect to OBS WebSocket host, port, and optional authentication password.",
            keywords: ["obs", "websocket", "stream", "record", "4455", "host", "password"],
            icon: "record.circle"
        ),
        SettingsSearchItem(
            id: "obs.automation",
            tab: .obs,
            section: "Recording automation",
            title: "Auto-Start & Auto-Stop with OBS",
            subtitle: "Automatically start and stop the teleprompter when OBS starts or stops recording.",
            keywords: ["obs", "auto-start", "auto-stop", "record", "automation", "sync"],
            icon: "bolt.horizontal"
        ),

        // Shortcuts & Hardware
        SettingsSearchItem(
            id: "shortcuts.hardware",
            tab: .shortcuts,
            section: "Live session controls",
            title: "Clickers, Foot Pedals & Controllers",
            subtitle: "View key and button bindings for presenter clickers, foot pedals, and gamepads.",
            keywords: ["clicker", "pedal", "foot pedal", "controller", "gamepad", "bluetooth", "marker", "f13", "f14", "shortcuts", "keyboard"],
            icon: "gamecontroller"
        ),

        // About & Reset
        SettingsSearchItem(
            id: "about.licenses",
            tab: .about,
            section: "Application",
            title: "Open Source Acknowledgements",
            subtitle: "View open-source licenses and attributions for Dante for Creators.",
            keywords: ["acknowledgements", "licenses", "open source", "credits", "version", "support", "privacy"],
            icon: "doc.text"
        ),
        SettingsSearchItem(
            id: "about.reset",
            tab: .about,
            section: "Danger zone",
            title: "Reset All Settings",
            subtitle: "Restore every preference, overlay dimension, and integration option to factory defaults.",
            keywords: ["reset", "factory", "defaults", "restore", "danger", "clear"],
            icon: "arrow.uturn.backward.circle"
        )
    ]

    static func search(_ query: String) -> [SettingsSearchItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return allItems }
        let tokens = trimmed
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        return allItems.filter { $0.matches(tokens: tokens) }
    }

    static func matchingTabs(for query: String) -> [SettingsTab] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return SettingsTab.allCases }
        let matchedSet = Set(search(trimmed).map(\.tab))
        return SettingsTab.allCases.filter { matchedSet.contains($0) }
    }
}
