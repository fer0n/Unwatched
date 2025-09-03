//
//  PremiumFeature.swift
//  Unwatched
//

import UnwatchedShared

enum PremiumFeatureLarge: String, CaseIterable {
    case supportDevelopment,
         unlockEverything

    var description: String {
        switch self {
        case .unlockEverything:
            return String(localized: "unlockEverythingDesc")
        case .supportDevelopment:
            return String(localized: "supportDevelopmentDesc")
        }
    }

    var title: String {
        switch self {
        case .unlockEverything:
            return String(localized: "unlockEverythingTitle")
        case .supportDevelopment:
            return String(localized: "supportDevelopmentTitle")
        }
    }

    var icon: String {
        switch self {
        case .unlockEverything:
            return "lock.open"
        case .supportDevelopment:
            return "heart"
        }
    }
}

enum PremiumFeature: String, CaseIterable {
    case customTemporaryPlaybackSpeed,
         videoTitleFilter,
         chapterFilter,
         playBrowserVideosInApp

    var title: String {
        switch self {
        case .customTemporaryPlaybackSpeed:
            return String(localized: "customTemporaryPlaybackSpeedTitle")
        case .videoTitleFilter:
            return String(localized: "videoTitleFilter")
        case .chapterFilter:
            return String(localized: "chapterFilterTitle")
        case .playBrowserVideosInApp:
            return String(localized: "playBrowserVideosInApp")
        }
    }

    var icon: String {
        switch self {
        case .customTemporaryPlaybackSpeed:
            return "gauge.with.needle"
        case .videoTitleFilter:
            return Const.filterSF
        case .chapterFilter:
            return "chevron.forward.circle.fill"
        case .playBrowserVideosInApp:
            return "play.fill"
        }
    }
}
