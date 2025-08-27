//
//  PremiumFeature.swift
//  Unwatched
//

import UnwatchedShared

enum PremiumFeature: String, CaseIterable {
    case supportDevelopment,
         unlockEverything,
         customTemporaryPlaybackSpeed,
         videoTitleFilter,
         chapterFilter

    var description: String {
        switch self {
        case .unlockEverything:
            return String(localized: "unlockEverythingDesc")
        case .customTemporaryPlaybackSpeed:
            return String(localized: "customTemporaryPlaybackSpeedDesc")
        case .supportDevelopment:
            return String(localized: "supportDevelopmentDesc")
        case .videoTitleFilter:
            return String(localized: "videoTitleFilterDesc")
        case .chapterFilter:
            return String(localized: "chapterFilterDesc")
        }
    }

    var title: String {
        switch self {
        case .unlockEverything:
            return String(localized: "unlockEverythingTitle")
        case .customTemporaryPlaybackSpeed:
            return String(localized: "customTemporaryPlaybackSpeedTitle")
        case .supportDevelopment:
            return String(localized: "supportDevelopmentTitle")
        case .videoTitleFilter:
            return String(localized: "videoTitleFilter")
        case .chapterFilter:
            return String(localized: "chapterFilterTitle")
        }
    }

    var icon: String {
        switch self {
        case .unlockEverything:
            return "lock.open"
        case .customTemporaryPlaybackSpeed:
            return "gauge.with.needle"
        case .supportDevelopment:
            return "heart"
        case .videoTitleFilter:
            return Const.filterSF
        case .chapterFilter:
            return "checkmark.circle.fill"
        }
    }
}
