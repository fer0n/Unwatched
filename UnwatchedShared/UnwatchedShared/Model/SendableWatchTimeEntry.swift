//
//  SendableWatchStat.swift
//  Unwatched
//

import Foundation

public struct SendableWatchTimeEntry: Sendable, Identifiable, Codable {
    public var id: String { "\(date)-\(channelId)" }
    public let date: Date
    public let channelId: String
    public let channelName: String
    public let watchTime: TimeInterval
    
    public init(
        date: Date,
        channelId: String,
        channelName: String,
        watchTime: TimeInterval
    ) {
        self.date = date
        self.channelId = channelId
        self.channelName = channelName
        self.watchTime = watchTime
    }

    enum CodingKeys: String, CodingKey {
        case date
        case channelId
        case watchTime
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(Date.self, forKey: .date)
        channelId = try container.decode(String.self, forKey: .channelId)
        watchTime = try container.decode(TimeInterval.self, forKey: .watchTime)
        channelName = ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(channelId, forKey: .channelId)
        try container.encode(watchTime, forKey: .watchTime)
    }
}
