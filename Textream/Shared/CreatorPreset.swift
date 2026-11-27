//
//  CreatorPreset.swift
//  Dante for Creators
//

import Foundation

enum CreatorPresetID: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case youtubeStudio
    case shortsReels
    case podcastInterview
    case keynoteLive

    var id: String { rawValue }
}

struct CreatorPreset: Identifiable, Hashable, Sendable {
    let id: CreatorPresetID
    let name: String
    let shortName: String
    let tagline: String
    let systemImage: String
    let targetWPM: Int
    let targetDurationSeconds: Int?
    let recommendedScrollWordsPerSecond: Double
    let prefersWordTracking: Bool
    let prefersNearCamera: Bool
    let prefersLargeFont: Bool
    let prefersParagraphDividers: Bool
    let prefersHideFromScreenShare: Bool
    let prefersKeepScreenAwake: Bool
    let prefersAutoNextPage: Bool
    let prefersRecordModeOnIOS: Bool
    let prefersBrightCues: Bool

    static let all: [CreatorPreset] = [
        CreatorPreset(
            id: .youtubeStudio,
            name: "YouTube Studio",
            shortName: "YouTube",
            tagline: "Natural eye contact, 150 WPM pacing, and large readable type for studio camera rigs.",
            systemImage: "play.rectangle.fill",
            targetWPM: 150,
            targetDurationSeconds: nil,
            recommendedScrollWordsPerSecond: 2.5,
            prefersWordTracking: true,
            prefersNearCamera: true,
            prefersLargeFont: true,
            prefersParagraphDividers: false,
            prefersHideFromScreenShare: true,
            prefersKeepScreenAwake: true,
            prefersAutoNextPage: false,
            prefersRecordModeOnIOS: true,
            prefersBrightCues: false
        ),
        CreatorPreset(
            id: .shortsReels,
            name: "Shorts / Reels / TikTok",
            shortName: "Shorts",
            tagline: "Tight 60-second pacing, near-camera framing, high-contrast cues, and Record mode ready.",
            systemImage: "sparkles.tv.fill",
            targetWPM: 165,
            targetDurationSeconds: 60,
            recommendedScrollWordsPerSecond: 3.0,
            prefersWordTracking: true,
            prefersNearCamera: true,
            prefersLargeFont: true,
            prefersParagraphDividers: false,
            prefersHideFromScreenShare: true,
            prefersKeepScreenAwake: true,
            prefersAutoNextPage: false,
            prefersRecordModeOnIOS: true,
            prefersBrightCues: true
        ),
        CreatorPreset(
            id: .podcastInterview,
            name: "Podcast / Interview",
            shortName: "Podcast",
            tagline: "Ad-lib resilient Smart Follow with paragraph dividers and elapsed session timer.",
            systemImage: "mic.fill",
            targetWPM: 140,
            targetDurationSeconds: nil,
            recommendedScrollWordsPerSecond: 2.5,
            prefersWordTracking: true,
            prefersNearCamera: false,
            prefersLargeFont: false,
            prefersParagraphDividers: true,
            prefersHideFromScreenShare: true,
            prefersKeepScreenAwake: true,
            prefersAutoNextPage: false,
            prefersRecordModeOnIOS: false,
            prefersBrightCues: false
        ),
        CreatorPreset(
            id: .keynoteLive,
            name: "Keynote / Live Stream",
            shortName: "Keynote",
            tagline: "Pinned below the notch, hidden from screen share, screen awake, and auto next page.",
            systemImage: "person.wave.2.fill",
            targetWPM: 135,
            targetDurationSeconds: nil,
            recommendedScrollWordsPerSecond: 2.5,
            prefersWordTracking: true,
            prefersNearCamera: true,
            prefersLargeFont: false,
            prefersParagraphDividers: true,
            prefersHideFromScreenShare: true,
            prefersKeepScreenAwake: true,
            prefersAutoNextPage: true,
            prefersRecordModeOnIOS: false,
            prefersBrightCues: false
        )
    ]

    var badgeLabel: String {
        switch id {
        case .youtubeStudio:
            return "\(targetWPM) WPM · 16:9"
        case .shortsReels:
            return "60s Target · \(targetWPM) WPM"
        case .podcastInterview:
            return "\(targetWPM) WPM · Ad-lib Safe"
        case .keynoteLive:
            return "\(targetWPM) WPM · Multi-Slide"
        }
    }

    var starterPages: [String] {
        switch id {
        case .youtubeStudio:
            return [
                "[hook — lock eyes with lens]\nMost creators lose half their viewers in the first ten seconds—not because of bad lighting, but because they look away from the camera to check their notes.\n\n[slight smile]\nToday I'll walk through the exact three-step studio workflow I use to nail a clean take on the first try.",
                "[section 2 — main takeaway]\nFirst, keep every sentence short and conversational. Use [brackets] for breathing cues so Dante skips them while tracking your voice automatically.\n\n[call to action]\nIf this workflow helped, subscribe for next week's deep dive."
            ]
        case .shortsReels:
            return [
                "[high energy — 60s target]\nStop memorizing scripts word for word.\n\n[pause 1s]\nHere's the fastest way to shoot a crisp 60-second vertical video without a single jump cut.\n\n[lean in]\nTurn on Smart Follow, keep the prompt right beside the lens, and talk like you're explaining it to a friend. Even if you ad-lib a line, Dante catches right back up."
            ]
        case .podcastInterview:
            return [
                "[intro — warm conversational tone]\nWelcome back to the show. Today we're diving into how independent creators build repeatable production systems without burning out.\n\n[transition to guest]\nBefore we jump into the rapid-fire questions, let's set the stage with three numbers that surprised our whole team."
            ]
        case .keynoteLive:
            return [
                "[slide 1 — opening]\nGood morning everyone, and thank you for joining us live. Over the next few minutes, we're going to share what we've been building and why it matters for your workflow.",
                "[slide 2 — live demo]\n[pause for screen transition]\nNotice how the teleprompter stays pinned below the camera while remaining completely hidden from screen share."
            ]
        }
    }

    static func preset(for id: CreatorPresetID) -> CreatorPreset {
        all.first { $0.id == id } ?? all[0]
    }
}
