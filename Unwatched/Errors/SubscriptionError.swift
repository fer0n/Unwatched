//
//  SubscriptionError.swift
//  Unwatched
//

import Foundation

enum SubscriptionError: LocalizedError {
    case notSupported
    case failedGettingChannelIdFromUsername
    case failedGettingVideoInfo

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return NSLocalizedString("The operation is not supported",
                                     comment: "No Supported Error")
        case .failedGettingChannelIdFromUsername:
            let message = """
            Failed to get channel ID from username.
            Try adding the RSS feed directly (instead of the channel URL).
            """
            return NSLocalizedString(message, comment: "Failed Getting Channel ID Error")
        case .failedGettingVideoInfo:
            return NSLocalizedString("Failed to get video info",
                                     comment: "Failed Getting Video Info Error")
        }
    }
}
