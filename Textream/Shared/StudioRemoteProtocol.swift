//
//  StudioRemoteProtocol.swift
//  Dante for Creators
//
//  Shared remote control wire protocol (macOS DirectorServer <-> iOS Studio Remote)
//  and customizable hardware key / foot-pedal / clicker action bindings.
//

import Foundation

enum StudioBonjour {
    static let serviceType = "_dante-director._tcp"
}

enum StudioRemoteAction: String, Codable, CaseIterable, Sendable {
    case auth
    case setText
    case updateText
    case stop
    case toggleListening
    case pause
    case resume
    case rewindSentence
    case nextPage
    case previousPage
    case adjustSpeed
    case dropMarker
}

/// Wire command sent from Web Director or native iOS Studio Remote to macOS.
/// Backward-compatible with legacy DirectorCommand JSON payloads.
struct StudioRemoteCommand: Codable, Equatable, Sendable {
    let type: String
    let text: String?
    let readCharCount: Int?
    let delta: Double?
    let label: String?

    init(
        type: String,
        text: String? = nil,
        readCharCount: Int? = nil,
        delta: Double? = nil,
        label: String? = nil
    ) {
        self.type = type
        self.text = text
        self.readCharCount = readCharCount
        self.delta = delta
        self.label = label
    }

    init(
        action: StudioRemoteAction,
        text: String? = nil,
        readCharCount: Int? = nil,
        delta: Double? = nil,
        label: String? = nil
    ) {
        self.init(
            type: action.rawValue,
            text: text,
            readCharCount: readCharCount,
            delta: delta,
            label: label
        )
    }

    var action: StudioRemoteAction? {
        StudioRemoteAction(rawValue: type)
    }
}

/// Live teleprompter telemetry broadcast from macOS to Web Director and native iOS Studio Remote.
/// Optional studio fields decode gracefully from legacy payloads.
struct StudioRemoteState: Codable, Equatable, Sendable {
    let highlightedCharCount: Int
    let totalCharCount: Int
    let isActive: Bool
    let isDone: Bool
    let isListening: Bool
    let fontColor: String
    let cueColor: String
    let lastSpokenText: String
    let audioLevels: [Double]

    // Extended Pro Studio telemetry
    let pageIndex: Int?
    let pageCount: Int?
    let currentWPM: Int?
    let paceDeltaSeconds: Int?
    let elapsedSeconds: Int?
    let retakeCount: Int?
    let scriptTitle: String?
    let scrollSpeed: Double?

    init(
        highlightedCharCount: Int,
        totalCharCount: Int,
        isActive: Bool,
        isDone: Bool,
        isListening: Bool,
        fontColor: String,
        cueColor: String,
        lastSpokenText: String,
        audioLevels: [Double],
        pageIndex: Int? = nil,
        pageCount: Int? = nil,
        currentWPM: Int? = nil,
        paceDeltaSeconds: Int? = nil,
        elapsedSeconds: Int? = nil,
        retakeCount: Int? = nil,
        scriptTitle: String? = nil,
        scrollSpeed: Double? = nil
    ) {
        self.highlightedCharCount = highlightedCharCount
        self.totalCharCount = totalCharCount
        self.isActive = isActive
        self.isDone = isDone
        self.isListening = isListening
        self.fontColor = fontColor
        self.cueColor = cueColor
        self.lastSpokenText = lastSpokenText
        self.audioLevels = audioLevels
        self.pageIndex = pageIndex
        self.pageCount = pageCount
        self.currentWPM = currentWPM
        self.paceDeltaSeconds = paceDeltaSeconds
        self.elapsedSeconds = elapsedSeconds
        self.retakeCount = retakeCount
        self.scriptTitle = scriptTitle
        self.scrollSpeed = scrollSpeed
    }

    var progress: Double {
        guard totalCharCount > 0 else { return 0 }
        return min(1.0, max(0.0, Double(highlightedCharCount) / Double(totalCharCount)))
    }
}

// MARK: - Hands-Free Hardware Control Bindings

enum StudioKeyAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case togglePause
    case rewindSentence
    case nextPage
    case previousPage
    case speedUp
    case speedDown
    case dropMarker
    case stop

    var id: String { rawValue }

    var label: String {
        switch self {
        case .togglePause:    return "Play / Pause"
        case .rewindSentence: return "Rewind Sentence"
        case .nextPage:       return "Next Page"
        case .previousPage:   return "Previous Page"
        case .speedUp:        return "Increase Speed"
        case .speedDown:      return "Decrease Speed"
        case .dropMarker:     return "Drop Take Marker"
        case .stop:           return "Stop Session"
        }
    }

    var systemImage: String {
        switch self {
        case .togglePause:    return "playpause.fill"
        case .rewindSentence: return "arrow.uturn.backward"
        case .nextPage:       return "forward.end.fill"
        case .previousPage:   return "backward.end.fill"
        case .speedUp:        return "plus.circle"
        case .speedDown:      return "minus.circle"
        case .dropMarker:     return "flag.fill"
        case .stop:           return "stop.fill"
        }
    }
}

/// Customizable macOS HID keyCode mapping supporting presenter clickers
/// (PageUp/PageDown/Left/Right/Period), USB & Bluetooth foot pedals (F13–F19, Space),
/// and keyboard shortcuts.
struct StudioControlBindings: Codable, Equatable, Sendable {
    static let defaultsKey = "dante.studio.controlBindings"

    /// Maps macOS virtual keyCode -> StudioKeyAction.
    var keyCodeMap: [UInt16: StudioKeyAction]

    init(keyCodeMap: [UInt16: StudioKeyAction] = StudioControlBindings.defaultKeyCodeMap) {
        self.keyCodeMap = keyCodeMap
    }

    static let defaultKeyCodeMap: [UInt16: StudioKeyAction] = [
        49:  .togglePause,    // Space / Foot pedal center
        47:  .togglePause,    // Period (Logitech presenter blank/pause button)
        53:  .stop,           // Escape
        123: .rewindSentence, // Left Arrow
        124: .nextPage,       // Right Arrow
        121: .nextPage,       // Page Down (Presenter clicker forward)
        116: .previousPage,   // Page Up (Presenter clicker back)
        126: .speedUp,        // Up Arrow
        125: .speedDown,      // Down Arrow
        46:  .dropMarker,     // M key (Drop NLE marker)
        105: .togglePause,    // F13 (Foot pedal 1)
        107: .rewindSentence, // F14 (Foot pedal 2)
        113: .dropMarker,     // F15 (Foot pedal 3)
        106: .previousPage,   // F16
        64:  .nextPage,       // F17
        79:  .speedDown,      // F18
        80:  .speedUp         // F19
    ]

    func action(forKeyCode keyCode: UInt16) -> StudioKeyAction? {
        keyCodeMap[keyCode]
    }

    mutating func bind(keyCode: UInt16, to action: StudioKeyAction?) {
        if let action {
            keyCodeMap[keyCode] = action
        } else {
            keyCodeMap.removeValue(forKey: keyCode)
        }
    }

    static func load(from defaults: UserDefaults = .standard) -> StudioControlBindings {
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(StudioControlBindings.self, from: data) else {
            return StudioControlBindings()
        }
        return decoded
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
