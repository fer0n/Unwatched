//
//  VideoData.swift
//  UnwatchedShared
//

import SwiftData

public protocol VideoData {
    var title: String { get }
    var elapsedSeconds: Double? { get }
    var duration: Double? { get }
    var noDuration: Bool? { get }
    var isYtShort: Bool? { get }
    var thumbnailUrl: URL? { get }
    var youtubeId: String { get }
    var publishedDate: Date? { get }
    var queueEntryData: QueueEntryData? { get }
    var bookmarkedDate: Date? { get }
    var watchedDate: Date? { get }
    var deferDate: Date? { get }
    var isNew: Bool { get }
    var url: URL? { get }
    var persistentId: PersistentIdentifier? { get }

    /// Direct stream URL.
    var mediaUrl: URL? { get }
    var isAudioOnly: Bool? { get }

    var sortedChapterData: [SendableChapter] { get }
    var subscriptionData: (any SubscriptionData)? { get }
    var channelTitle: String? { get }
    var hasInboxEntry: Bool? { get }
}

public extension VideoData {
    var isPodcast: Bool {
        mediaUrl != nil
    }

    /// "Playlist (Channel)" for a playlist's video, otherwise the subscription's title
    var channelDisplayTitle: String? {
        subscriptionData?.videoSourceTitle(channelTitle: channelTitle)
    }

    /// The playlist's title for a video that came in through one
    var playlistTitle: String? {
        subscriptionData?.youtubePlaylistId != nil ? subscriptionData?.title : nil
    }

    var uploaderTitle: String? {
        guard let subscriptionData else { return channelTitle }
        guard subscriptionData.youtubePlaylistId != nil else { return subscriptionData.displayTitle }
        return subscriptionData.playlistUploader(channelTitle: channelTitle)
    }

    /// The image to show for this video.
    var displayThumbnailUrl: URL? {
        thumbnailUrl ?? subscriptionData?.thumbnailUrl
    }
}
