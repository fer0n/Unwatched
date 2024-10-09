//
//  VideoCrawlerError.swift
//  Unwatched
//

import SwiftUI

enum VideoCrawlerError: LocalizedError {
    case subscriptionInfoNotFound
    case invalidUrl
    case failedToParse

    var errorDescription: String? {
        switch self {
        case .subscriptionInfoNotFound:
            return String(localized: "subscriptionInfoNotFound")
        case .invalidUrl:
            return String(localized: "invalidUrl")
        case .failedToParse:
            return String(localized: "failedToParse")
        }
    }
}
