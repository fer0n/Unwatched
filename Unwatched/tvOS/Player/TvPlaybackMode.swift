//
//  TvPlaybackMode.swift
//  UnwatchedTV
//

import SwiftUI

/// Where a queue video is played when it's selected.
enum TvPlaybackMode: String, CaseIterable, Identifiable {
    /// Hand the video over to the YouTube app.
    case youtubeApp
    /// Play it in Unwatched with AVPlayer.
    case inApp

    var id: Self { self }

    var label: LocalizedStringKey {
        switch self {
        case .youtubeApp: "playbackModeYouTube"
        case .inApp: "playbackModeInApp"
        }
    }
}
