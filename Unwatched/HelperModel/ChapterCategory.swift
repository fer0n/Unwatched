//
//  ChapterCategory.swift
//  Unwatched
//

import Foundation

enum ChapterCategory: Int, Codable, CaseIterable, CustomStringConvertible {
    case sponsor
    case filler
    case intro
    case selfpromo
    case interaction
    case outro
    case preview
    case musicOfftopic

    case generated

    var translated: String? {
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
        }
    }

    var description: String {
        switch self {
        case .sponsor:
            return ".sponsor"
        case .filler:
            return ".filler"
        case .intro:
            return ".intro"
        case .selfpromo:
            return ".selfpromo"
        case .interaction:
            return ".interaction"
        case .outro:
            return ".outro"
        case .preview:
            return ".preview"
        case .musicOfftopic:
            return ".music_offtopic"
        case .generated:
            return ".generated"
        }
    }

    static func parse(_ sponsorBlockCategory: String) -> ChapterCategory? {
        switch sponsorBlockCategory {
        case "sponsor":
            return .sponsor
        case "filler":
            return .filler
        case "intro":
            return .intro
        case "selfpromo":
            return .selfpromo
        case "interaction":
            return .interaction
        case "outro":
            return .outro
        case "preview":
            return .preview
        case "music_offtopic":
            return .musicOfftopic
        default:
            return nil
        }
    }
}
