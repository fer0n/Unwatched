//
//  VideoSorting.swift
//  Unwatched
//

import Foundation
import SwiftUI

enum VideoSorting: Int, CustomStringConvertible, CaseIterable {
    case publishedDate
    case clearedInboxDate

    var description: String {
        switch self {
        case .clearedInboxDate:
            return String(localized: "clearedInboxDate")
        case .publishedDate:
            return String(localized: "publishedDate")
        }
    }

    var systemName: String {
        switch self {
        case .clearedInboxDate:
            return "tray.and.arrow.up.fill"
        case .publishedDate:
            return "calendar.badge.plus"
        }
    }
}
