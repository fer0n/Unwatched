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

    /// Audio the show's own transcript doesn't cover. Appended last on purpose: the raw values are
    /// stored and synced, so an older build decodes this as nil and falls back to the title.
    case notTranscribed

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
        case .notTranscribed:
            return ".notTranscribed"
        }
    }

    /// Category identifier used by the SponsorBlock API, `nil` for categories it doesn't know
    public var apiName: String? {
        switch self {
        case .sponsor:
            return "sponsor"
        case .filler:
            return "filler"
        case .intro:
            return "intro"
        case .selfpromo:
            return "selfpromo"
        case .interaction:
            return "interaction"
        case .outro:
            return "outro"
        case .preview:
            return "preview"
        case .musicOfftopic:
            return "music_offtopic"
        case .chapter:
            return "chapter"
        case .generated, .notTranscribed:
            return nil
        }
    }

    /// Segments with exact times from SponsorBlock win over the video's own chapters when they overlap
    public var hasPriority: Bool {
        self == .sponsor || self == .selfpromo
    }

    public var isExternal: Bool {
        self != .generated && self != .notTranscribed
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
