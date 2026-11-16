//
//  YtVideoInfo.swift
//  UnwatchedShared
//

import Foundation

public struct ContentDetails: Codable {
    let duration: String?
}

public struct YtVideoInfo: Codable {
    public struct Item: Codable {
        let snippet: YtVideoSnippet
        let contentDetails: ContentDetails
    }
    let items: [Item]
}

public struct YtVideoDurations: Codable {
    public struct Item: Codable {
        let contentDetails: ContentDetails
        let liveStreamingDetails: LiveStreamingDetails?
        let id: String
    }

    /// Only present for premieres and live streams.
    public struct LiveStreamingDetails: Codable {
        let scheduledStartTime: String?
        let actualStartTime: String?

        var upcomingStart: Date? {
            guard actualStartTime == nil else { return nil }
            return scheduledStartTime.flatMap { try? Date($0, strategy: .iso8601) }
        }
    }
    let items: [Item]
}

public struct YtVideoSnippet: Codable {
    public struct High: Codable {
        let url: String
    }
    public struct Thumbnails: Codable {
        let high: High?
    }
    let title: String
    let thumbnails: Thumbnails
    let channelTitle: String
    let channelId: String
    let publishedAt: String
    let description: String
}
