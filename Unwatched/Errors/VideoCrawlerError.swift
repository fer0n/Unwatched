//
//  VideoCrawlerError.swift
//  Unwatched
//

import Foundation

enum VideoCrawlerError: LocalizedError {
    case subscriptionInfoNotFound
    case invalidUrl
    case failedToParse

    var errorDescription: String? {
        switch self {
        case .subscriptionInfoNotFound:
            return NSLocalizedString("Subscription information not found", comment: "Subscription Info Not Found Error")
        case .invalidUrl:
            return NSLocalizedString("Invalid URL", comment: "Invalid URL Error")
        case .failedToParse:
            return NSLocalizedString("Failed to parse the data", comment: "Failed To Parse Error")
        }
    }
}
