//
//  SendableChannelStatistics.swift
//  UnwatchedShared
//

import Foundation

public struct SendableChannelStatistics: Codable, Sendable {
    public let channelId: String
    public let entries: [Entry]

    public init(channelId: String, entries: [Entry]) {
        self.channelId = channelId
        self.entries = entries
    }

    public struct Entry: Codable, Sendable {
        public let date: Date
        public let time: TimeInterval

        public init(date: Date, time: TimeInterval) {
            self.date = date
            self.time = time
        }
    }
}
