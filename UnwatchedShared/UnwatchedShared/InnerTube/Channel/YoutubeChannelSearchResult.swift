//
//  YoutubeChannelSearchResult.swift
//  UnwatchedShared
//

import Foundation

public struct YoutubeChannelSearchResult: Identifiable, Hashable, Sendable {
    public var channelId: String
    public var title: String
    /// The `@handle`, without the `@`
    public var userName: String?
    /// e.g. "25.5M subscribers"
    public var subscriberCount: String?
    public var thumbnailUrl: URL?

    public var id: String { channelId }

    public init(
        channelId: String,
        title: String,
        userName: String? = nil,
        subscriberCount: String? = nil,
        thumbnailUrl: URL? = nil
    ) {
        self.channelId = channelId
        self.title = title
        self.userName = userName
        self.subscriberCount = subscriberCount
        self.thumbnailUrl = thumbnailUrl
    }
}
