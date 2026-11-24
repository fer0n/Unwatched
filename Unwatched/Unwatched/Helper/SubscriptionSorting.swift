//
//  SubscriptionSorting.swift
//  Unwatched
//

import Foundation
import SwiftUI
import UnwatchedShared

enum SubscriptionSorting: Int, CustomStringConvertible, CaseIterable {
    case title
    case recentlyAdded
    case mostRecentVideo

    static var stored: SubscriptionSorting {
        (UserDefaults.standard.object(forKey: Const.subscriptionSortOrder) as? Int)
            .flatMap(SubscriptionSorting.init) ?? .recentlyAdded
    }

    var sortDescriptors: [SortDescriptor<Subscription>] {
        switch self {
        case .title: [SortDescriptor(\.title)]
        case .recentlyAdded: [SortDescriptor(\.subscribedDate, order: .reverse)]
        case .mostRecentVideo: [SortDescriptor(\.mostRecentVideoDate, order: .reverse)]
        }
    }

    var description: String {
        switch self {
        case .title:
            return String(localized: "subscriptionTitle")
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
