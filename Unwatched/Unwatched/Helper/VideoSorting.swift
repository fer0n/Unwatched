//
//  VideoSorting.swift
//  Unwatched
//

import Foundation
import SwiftUI

enum VideoSorting: Int, CustomStringConvertible, CaseIterable {
    case publishedDate
    case clearedInboxDate
    case createdDate

    var description: String {
        switch self {
        case .clearedInboxDate:
            return String(localized: "clearedInboxDate")
        case .publishedDate:
            return String(localized: "publishedDate")
        case .createdDate:
            return String(localized: "createdDate")
        }
    }

    var systemName: String {
        switch self {
        case .clearedInboxDate:
            return "tray.and.arrow.up.fill"
        case .publishedDate:
            return "calendar"
        case .createdDate:
            return "plus"
        }
    }
}
