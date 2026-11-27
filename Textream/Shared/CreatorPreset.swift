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

    static func preset(for id: CreatorPresetID) -> CreatorPreset {
        all.first { $0.id == id } ?? all[0]
    }
}
