//
//  VideoSorting.swift
//  Unwatched
//

import Foundation
import SwiftUI

enum VideoSorting: Int, CustomStringConvertible, CaseIterable {
    case publishedDate
    case createdDate

    var description: String {
        switch self {
        case .publishedDate:
            return String(localized: "publishedDate")
        case .createdDate:
            return String(localized: "createdDate")
        }
    }

    var systemName: String {
        switch self {
        case .publishedDate:
            return "calendar"
        case .createdDate:
            return "plus"
        }
    }
}
