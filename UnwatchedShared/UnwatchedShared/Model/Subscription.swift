//
//  Subscription.swift
//  Unwatched
//

import Foundation
import SwiftData

public protocol SubscriptionData: Hashable {
    var displayTitle: String { get }
    var youtubeChannelId: String? { get }
    var youtubePlaylistId: String? { get }
    var link: URL? { get }
    /// A podcast show rather than a YouTube channel/playlist. Its `link` is the RSS feed.
    var isPodcast: Bool { get }
    /// How many refreshes in a row this feed has failed, see `Subscription.hasFeedIssue`.
    var failedFetchCount: Int { get }
    var lastFetchErrorMessage: String? { get }
    /// The show's cover, which an episode without an image of its own falls back to (see
    /// `VideoData.displayThumbnailUrl`).
    var thumbnailUrl: URL? { get }
}

public extension SubscriptionData {
    /// Whether the feed has failed often enough in a row to be worth telling the user about.
    var hasFeedIssue: Bool {
        failedFetchCount >= Const.subscriptionFailureThreshold
    }

    /// Identifies the channel rather than its row, so it survives a backup round trip and dedupe.
    var subscriptionKey: String? {
        youtubeChannelId ?? youtubePlaylistId ?? link?.absoluteString
    }
}

@Model
public final class Subscription: SubscriptionData, CustomStringConvertible, Exportable {
    public typealias ExportType = SendableSubscription

    @Relationship(deleteRule: .nullify, inverse: \Video.subscription)
    public var videos: [Video]? = []

    public var link: URL?

    public var tags: [Tag]? = []

    public var title: String = "-"
    public var author: String?
    public var subscribedDate: Date?
    public var filterText: String = ""
    public var allowOnMatch: Bool = false

    public var _videoPlacement: Int? = VideoPlacement.defaultPlacement.rawValue
    public var videoPlacement: VideoPlacement {
        get {
            if let raw = _videoPlacement {
                VideoPlacement(rawValue: raw) ?? VideoPlacement.defaultPlacement
            } else {
                VideoPlacement.defaultPlacement
            }
        }
        set {
            _videoPlacement = newValue.rawValue
        }
    }

    public var isArchived: Bool = false

    public var isPodcast: Bool = false

    // workaround: SwiftData filter don't work with enums; migration issues if non-nill
    public var _shortsSetting: Int? = ShortsSetting.defaultSetting.rawValue
    public var shortsSetting: ShortsSetting {
        get {
            if let raw = _shortsSetting {
                ShortsSetting(rawValue: raw) ?? ShortsSetting.defaultSetting
            } else {
                ShortsSetting.defaultSetting
            }
        }
        set {
            _shortsSetting = newValue.rawValue
        }
    }

    public var customSpeedSetting: Double?
    public var customAspectRatio: Double?
    public var skipIntroSeconds: Double?
    public var skipOutroSeconds: Double?
    public var mostRecentVideoDate: Date?

    public var failedFetchCount: Int = 0
    public var lastFetchFailedDate: Date?
    public var lastFetchErrorMessage: String?

    /// Chapter titles this channel skips automatically, normalized by `ChapterService.autoSkipKey`.
    public var autoSkipChapterTitles: [String]?

    public var youtubeChannelId: String?
    public var youtubePlaylistId: String?
    public var youtubeUserName: String?

    public var thumbnailUrl: URL?

    /// A podcast's author is the hosts or the publisher, and it is shown on its own line
    /// wherever there's room — appended here it turns "Accidental Tech Podcast" into
    /// "Accidental Tech Podcast - Marco Arment, Casey Liss, John Siracusa" in every list row.
    static func getDisplayTitle(_ title: String, _ author: String?, isPodcast: Bool = false) -> String {
        guard let author, !isPodcast else {
            return title
        }
        return "\(title) - \(author)"
    }

    public var displayTitle: String {
        Subscription.getDisplayTitle(title, author, isPodcast: isPodcast)
    }

    public var description: String {
        return title
    }

    public init(videos: [Video] = [],
                link: URL?,

                title: String,
                author: String? = nil,
                subscribedDate: Date? = .now,
                filterText: String = "",
                allowOnMatch: Bool = false,
                videoPlacement: VideoPlacement = .defaultPlacement,
                isArchived: Bool = false,
                isPodcast: Bool = false,

                customSpeedSetting: Double? = nil,
                customAspectRatio: Double? = nil,
                skipIntroSeconds: Double? = nil,
                skipOutroSeconds: Double? = nil,
                mostRecentVideoDate: Date? = nil,
                autoSkipChapterTitles: [String]? = nil,
                youtubeChannelId: String? = nil,
                youtubePlaylistId: String? = nil,
                youtubeUserName: String? = nil,
                thumbnailUrl: URL? = nil) {
        self.videos = videos
        self.link = link
        self.title = title
        self.author = author
        self.subscribedDate = subscribedDate
        self.filterText = filterText
        self.allowOnMatch = allowOnMatch
        self.videoPlacement = videoPlacement
        self.isArchived = isArchived
        self.isPodcast = isPodcast

        self.customSpeedSetting = customSpeedSetting
        self.customAspectRatio = customAspectRatio
        self.skipIntroSeconds = skipIntroSeconds
        self.skipOutroSeconds = skipOutroSeconds
        self.mostRecentVideoDate = mostRecentVideoDate
        self.autoSkipChapterTitles = autoSkipChapterTitles
        self.youtubeChannelId = youtubeChannelId
        self.youtubePlaylistId = youtubePlaylistId
        self.youtubeUserName = youtubeUserName
        self.thumbnailUrl = thumbnailUrl
    }

    public var toExport: SendableSubscription? {
        SendableSubscription(
            persistentId: self.persistentModelID,
            videosIds: videos?.map { $0.persistentModelID.hashValue } ?? [],
            link: link,
            title: title,
            author: author,
            subscribedDate: subscribedDate,
            filterText: filterText,
            allowOnMatch: allowOnMatch,
            videoPlacement: videoPlacement,
            isArchived: isArchived,
            isPodcast: isPodcast,
            customSpeedSetting: customSpeedSetting,
            customAspectRatio: customAspectRatio,
            skipIntroSeconds: skipIntroSeconds,
            skipOutroSeconds: skipOutroSeconds,
            mostRecentVideoDate: mostRecentVideoDate,
            failedFetchCount: failedFetchCount,
            lastFetchFailedDate: lastFetchFailedDate,
            lastFetchErrorMessage: lastFetchErrorMessage,
            autoSkipChapterTitles: autoSkipChapterTitles,
            youtubeChannelId: youtubeChannelId,
            youtubePlaylistId: youtubePlaylistId,
            youtubeUserName: youtubeUserName,
            thumbnailUrl: thumbnailUrl
        )
    }
}

public extension Subscription {
    func autoSkips(_ chapterTitle: String?) -> Bool {
        guard let key = ChapterService.autoSkipKey(chapterTitle) else { return false }
        return autoSkipChapterTitles?.contains(key) == true
    }

    /// Remembers, or forgets, that this channel's chapters with this title are skipped.
    func setAutoSkip(_ chapterTitle: String?, _ skip: Bool) {
        guard let key = ChapterService.autoSkipKey(chapterTitle),
              autoSkips(chapterTitle) != skip else {
            return
        }
        var titles = autoSkipChapterTitles ?? []
        if skip {
            titles.append(key)
        } else {
            titles.removeAll { $0 == key }
        }
        autoSkipChapterTitles = titles.isEmpty ? nil : titles
    }
}
