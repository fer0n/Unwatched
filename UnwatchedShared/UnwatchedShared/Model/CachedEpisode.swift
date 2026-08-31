//
//  CachedEpisode.swift
//  UnwatchedShared
//

import Foundation
import SwiftData

/// A podcast episode as it appears in its feed, kept in the local (never synced) store.
///
/// Only episodes the user has interacted with become `Video` rows and reach iCloud; the rest of a
/// show's catalogue lives here and is re-derived from the feed, which can always serve it again.
@Model public final class CachedEpisode {
    @Attribute(.unique) public var episodeId: String
    public var feedUrl: URL
    public var title: String
    public var publishedDate: Date?
    public var duration: Double?
    public var thumbnailUrl: URL?
    public var mediaUrl: URL?
    public var episodeUrl: URL?
    public var episodeDescription: String?
    public var chaptersUrl: URL?
    public var isAudioOnly: Bool?
    public var updatedDate: Date

    public init(
        episodeId: String,
        feedUrl: URL,
        title: String,
        publishedDate: Date? = nil,
        duration: Double? = nil,
        thumbnailUrl: URL? = nil,
        mediaUrl: URL? = nil,
        episodeUrl: URL? = nil,
        episodeDescription: String? = nil,
        chaptersUrl: URL? = nil,
        isAudioOnly: Bool? = nil,
        updatedDate: Date = .now
    ) {
        self.episodeId = episodeId
        self.feedUrl = feedUrl
        self.title = title
        self.publishedDate = publishedDate
        self.duration = duration
        self.thumbnailUrl = thumbnailUrl
        self.mediaUrl = mediaUrl
        self.episodeUrl = episodeUrl
        self.episodeDescription = episodeDescription
        self.chaptersUrl = chaptersUrl
        self.isAudioOnly = isAudioOnly
        self.updatedDate = updatedDate
    }
}
