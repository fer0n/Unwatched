//
//  ChapterCategory.swift
//  Unwatched
//

import UnwatchedShared

extension ChapterCategory {
    public var translated: String? {
        switch self {
        case .sponsor:
            return String(localized: "categorySponsor")
        case .filler:
            return String(localized: "categoryFiller")
        case .intro:
            return String(localized: "categoryIntro")
        case .selfpromo:
            return String(localized: "categorySelfpromo")
        case .interaction:
            return String(localized: "categoryInteraction")
        case .outro:
            return String(localized: "categoryOutro")
        case .preview:
            return String(localized: "categoryPreview")
        case .musicOfftopic:
            return String(localized: "categoryMusicOfftopic")
        case .generated:
            return nil
        @unknown default:
            return "\(self.rawValue)"
        }
    }
}
