//
//  VideoSorting.swift
//  Unwatched
//

import Foundation
import SwiftUI

enum VideoSorting: Int, CustomStringConvertible, CaseIterable {
    case publishedDate
    case clearedDate

    var description: String {
        switch self {
        case .clearedDate:
            return String(localized: "clearedDate")
        case .publishedDate:
            return String(localized: "publishedDate")
        }
    }

    var systemName: String {
        switch self {
        case .clearedDate:
            return "clock.badge.xmark"
        case .publishedDate:
            return "calendar.badge.plus"
        }
    }
}
