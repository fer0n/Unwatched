//
//  SubscriptionError.swift
//  Unwatched
//

import Foundation

enum SubscriptionError: LocalizedError {
    case noSupported
    case failedGettingChannelIdFromUsername

    var errorDescription: String? {
        switch self {
        case .noSupported:
            return NSLocalizedString("The operation is not supported",
                                     comment: "No Supported Error")
        case .failedGettingChannelIdFromUsername:
            let message = """
            Failed to get channel ID from username.
            Try adding the RSS feed directly (instead of the channel URL).
            """
            return NSLocalizedString(message, comment: "Failed Getting Channel ID Error")
        }
    }
}
