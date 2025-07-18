//
//  ChapterCategory.swift
//  Unwatched
//

import Foundation

public enum ChapterCategory: Int, Codable, CaseIterable, CustomStringConvertible, Sendable {
    case sponsor
    case filler
    case intro
    case selfpromo
    case interaction
    case outro
    case preview
    case musicOfftopic
    case chapter

    case generated

    public var description: String {
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
        case .chapter:
            return ".chapter"
        case .generated:
            return ".generated"
        }
    }

    public var hasPriority: Bool {
        self == .sponsor
    }

    public var isExternal: Bool {
        self != .generated
    }

    public static func parse(_ sponsorBlockCategory: String) -> ChapterCategory? {
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
        case "chapter":
            return .chapter
        default:
            return nil
        }
    }
}
