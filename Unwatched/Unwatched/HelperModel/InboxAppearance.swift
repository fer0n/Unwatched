//
//  InboxAppearance.swift
//  Unwatched
//

import Foundation

enum InboxAppearance: Int, Codable, CaseIterable {
    case list
    case cards

    var description: String {
        switch self {
        case .list: return String(localized: "inboxAppearanceList")
        case .cards: return String(localized: "inboxAppearanceCards")
        }
    }
}
