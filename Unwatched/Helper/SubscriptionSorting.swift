//
//  SubscriptionSorting.swift
//  Unwatched
//

import Foundation
import SwiftUI

enum SubscriptionSorting: Int, CustomStringConvertible, CaseIterable {
    case title
    case recentlyAdded
    case mostRecentVideo

    var description: String {
        switch self {
        case .title:
            return String(localized: "title")
        case .recentlyAdded:
            return String(localized: "recentlyAdded")
        case .mostRecentVideo:
            return String(localized: "mostRecentVideo")
        }
    }

    var systemName: String {
        switch self {
        case .title:
            return "textformat.abc"
        case .recentlyAdded:
            return "calendar.badge.plus"
        case .mostRecentVideo:
            return "clock.arrow.circlepath"
        }
    }
}
