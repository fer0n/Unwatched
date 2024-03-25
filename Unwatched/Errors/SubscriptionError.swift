//
//  SubscriptionError.swift
//  Unwatched
//

import Foundation

enum SubscriptionError: LocalizedError {
    case notSupported
    case failedGettingChannelIdFromUsername(_ message: String?)
    case failedGettingVideoInfo
    case httpRequestFailed(_ message: String)
    case notAnUrl(_ noUrl: String)
    case noInfoFoundToSubscribeTo
    case noInfoFoundToUnsibscribe
    case couldNotSubscribe(_ message: String)

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return NSLocalizedString("notSupported",
                                     comment: "No Supported Error")
        case .failedGettingChannelIdFromUsername(let message):
            let msg = """
            Failed to get channel ID from username.
            Try adding the RSS feed directly (instead of the channel URL).
            \(message != nil ? "Error: \(message!)" : "" )")
            """
            return NSLocalizedString(msg, comment: "Failed Getting Channel ID Error")
        case .failedGettingVideoInfo:
            return NSLocalizedString("failedGettingVideoInfo",
                                     comment: "Failed Getting Video Info Error")
        case .httpRequestFailed(let message):
            return NSLocalizedString("HTTP request failed: \(message)",
                                     comment: "Failed Getting Video Info Error")
        case .notAnUrl(let noUrl):
            return NSLocalizedString("Couldn't convert to URL: \(noUrl)", comment: "Couldn't convert to URL")
        case .noInfoFoundToSubscribeTo:
            return NSLocalizedString("noInfoFoundToSubscribeTo", comment: "No info found to subscribe to")
        case .couldNotSubscribe(let message):
            return NSLocalizedString("Could not subscribe: \(message)", comment: "Could not subscribe")
        case .noInfoFoundToUnsibscribe:
            return NSLocalizedString("noInfoFoundToUnsibscribe", comment: "noInfoFoundToUnsibscribe")
        }
    }
}
