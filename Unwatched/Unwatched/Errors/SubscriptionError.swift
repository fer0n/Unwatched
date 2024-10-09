//
//  SubscriptionError.swift
//  Unwatched
//

import SwiftUI

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
            return String(localized: "notSupported")
        case .failedGettingChannelIdFromUsername(let message):
            let msg = """
            Failed to get channel ID from username.
            Try adding the RSS feed directly (instead of the channel URL).
            \(message != nil ? "Error: \(message!)" : "" )")
            """
            return String(localized: "failedGettingChannelIdFromUsername\(msg)")
        case .failedGettingVideoInfo:
            return String(localized: "failedGettingVideoInfo")
        case .httpRequestFailed(let message):
            return String(localized: "HTTP request failed: \(message)")
        case .notAnUrl(let noUrl):
            return String(localized: "Couldn't convert to URL: \(noUrl)")
        case .noInfoFoundToSubscribeTo:
            return String(localized: "noInfoFoundToSubscribeTo")
        case .couldNotSubscribe(let message):
            return String(localized: "Could not subscribe: \(message)")
        case .noInfoFoundToUnsibscribe:
            return String(localized: "noInfoFoundToUnsibscribe")
        }
    }
}
