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
            return NSLocalizedString("subscriptionInfoNotFound", comment: "Subscription Info Not Found Error")
        case .invalidUrl:
            return NSLocalizedString("invalidUrl", comment: "Invalid URL Error")
        case .failedToParse:
            return NSLocalizedString("failedToParse", comment: "Failed To Parse Error")
        }
    }
}
