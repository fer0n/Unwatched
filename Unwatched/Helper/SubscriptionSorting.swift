//
//  SubscriptionSorting.swift
//  Unwatched
//

import Foundation

enum SubscriptionSorting: Int, CustomStringConvertible, CaseIterable {
    case title
    case recentlyAdded
    case mostRecentVideo

    var description: String {
        switch self {
        case .title:
            return "title"
        case .recentlyAdded:
            return "recentlyAdded"
        case .mostRecentVideo:
            return "mostRecentVideo"
        }
    }
}
