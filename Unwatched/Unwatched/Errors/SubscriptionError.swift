//
//  SubscriptionError.swift
//  Unwatched
//

import SwiftUI

enum SubscriptionError: Error, CustomLocalizedStringResourceConvertible {
    case notSupported
    case failedGettingChannelIdFromUsername(_ message: String?)
    case failedGettingVideoInfo
    case httpRequestFailed(_ message: String)
    case notAnUrl(_ noUrl: String)
    case noInfoFoundToSubscribeTo
    case noInfoFoundToUnsubscribe
    case couldNotSubscribe(_ message: String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notSupported:
            return "notSupported"
        case .failedGettingChannelIdFromUsername(let message):
            let msg = """
            Failed to get channel ID from username.
            Try adding the RSS feed directly (instead of the channel URL).
            \(message != nil ? "Error: \(message!)" : "" )")
            """
            return "failedGettingChannelIdFromUsername\(msg)"
        case .failedGettingVideoInfo:
            return "failedGettingVideoInfo"
        case .httpRequestFailed(let message):
            return "HTTP request failed: \(message)"
        case .notAnUrl(let noUrl):
            return "Couldn't convert to URL: \(noUrl)"
        case .noInfoFoundToSubscribeTo:
            return "noInfoFoundToSubscribeTo"
        case .couldNotSubscribe(let message):
            return "Could not subscribe: \(message)"
        case .noInfoFoundToUnsubscribe:
            return "noInfoFoundToUnsibscribe"
        }
    }

}
