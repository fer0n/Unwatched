//
//  VideoCrawlerError.swift
//  UnwatchedShared
//

import SwiftUI

public enum VideoCrawlerError: LocalizedError {
    case subscriptionInfoNotFound
    case invalidUrl
    case failedToParse

    public var errorDescription: String? {
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
