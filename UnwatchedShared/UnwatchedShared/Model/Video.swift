//
//  Video.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model
public final class Video: VideoData, CustomStringConvertible, Exportable {
    public typealias ExportType = SendableVideo

    @Relationship(deleteRule: .cascade, inverse: \InboxEntry.video)
    public var inboxEntry: InboxEntry?

    @Relationship(deleteRule: .cascade, inverse: \QueueEntry.video)
    public var queueEntry: QueueEntry?

    @Relationship(deleteRule: .cascade, inverse: \Chapter.video)
    public var chapters: [Chapter]? = []

    @Relationship(deleteRule: .cascade, inverse: \Chapter.mergedChapterVideo)
    public var mergedChapters: [Chapter]? = []

    public var tags: [Tag]? = []

    /// This video's identity, and what queue entries, chapters, stats and the image cache are all keyed by — a
    /// YouTube id for a video, a `pod-…` hash of the RSS guid for a podcast episode (see `PodcastService.episodeId`).
    public var youtubeId: String = UUID().uuidString

    public var title: String = "-"
    public var url: URL?

    public var thumbnailUrl: URL?
    public var publishedDate: Date?
    public var deferDate: Date?
    public var updatedDate: Date?
    public var duration: Double?
    public var apiUpdatedDate: Date?
    public var noDuration: Bool?
    public var elapsedSeconds: Double?
    public var videoDescription: String?
    public var watchedDate: Date?
    public var subscription: Subscription?
    public var youtubeChannelId: String?
    public var isYtShort: Bool?
    public var bookmarkedDate: Date?

    public var mediaUrl: URL?
    public var isAudioOnly: Bool?
    /// Set once the episode's enclosure is on disk; see `PodcastDownloadManager`.
    public var downloadedDate: Date?
    /// Podcasting 2.0 `podcast:chapters` JSON, fetched the first time the episode plays.
    public var chaptersUrl: URL?

    public var createdDate: Date?
    public var isNew: Bool = false

    /// The user re-enabled this video's skipped intro by hand.
    public var keepIntro: Bool?

    /// The same for the skipped outro, see `Subscription.skipOutroSeconds`.
    public var keepOutro: Bool?

    /// Bumped whenever this video's chapters change without SwiftData noticing — see `chaptersDidChange`.
    @Transient
    public var chapterRevision: Int = 0

    public var subscriptionData: (any SubscriptionData)? {
        return subscription
    }

    public var sponserBlockUpdateDate: Date?

    // MARK: Computed Properties
    public var persistentId: PersistentIdentifier? {
        persistentModelID
    }

    /// The `Chapter` rows this video has, if any. Most videos have none — see
    /// `sortedChapterData`, which is what readers want. Rows are for the code that edits them.
    public var sortedChapters: [Chapter] {
        Video.getSortedChapters(mergedChapters, chapters)
    }

    /// Every chapter of this video, whether it's backed by a row or parsed from the description.
    public var sortedChapterData: [SendableChapter] {
        // the edits the rows themselves don't announce, see `chapterRevision`
        _ = chapterRevision
        // the row check comes first because it's the cheap one: `getSortedChapters` sorts and
        // reads the key-value store, and this runs inside view bodies
        let computed: [SendableChapter] = {
            guard hasChapterRows else {
                return derivedChapters
            }
            let stored = Video.getSortedChapters(mergedChapters, chapters)
            return stored.isEmpty ? derivedChapters : stored.map(\.toExport)
        }()
        let withoutAutoSkipped = ChapterService.applyAutoSkip(
            to: computed,
            titles: subscription?.autoSkipChapterTitles
        )
        let withoutIntro = ChapterService.applySkipIntro(
            withoutAutoSkipped,
            skipIntroSeconds: subscription?.skipIntroSeconds,
            videoDuration: duration,
            videoId: youtubeId,
            keepIntro: keepIntro == true
        )
        return ChapterService.applySkipOutro(
            withoutIntro,
            skipOutroSeconds: subscription?.skipOutroSeconds,
            videoDuration: duration,
            videoId: youtubeId,
            keepOutro: keepOutro == true
        )
    }

    /// Every chapter, in the order they play — see `ChapterService.inPlaybackOrder`. Anything that
    /// reasons about the timeline (the current chapter, markers, the scrubber) wants `sortedChapterData`.
    public var orderedChapterData: [SendableChapter] {
        ChapterService.inPlaybackOrder(sortedChapterData)
    }

    /// Whether the user has dragged this video's chapters into an order of their own.
    public var hasCustomChapterOrder: Bool {
        Video.getSortedChapters(mergedChapters, chapters).contains { $0.order != nil }
    }

    /// Both row sets: what an edit reaches for when it has to touch every row this video owns.
    public var allChapterRows: [Chapter] {
        (chapters ?? []) + (mergedChapters ?? [])
    }

    /// This video's own chapters, excluding any SponsorBlock merge — the input the merge is built
    /// from, and what an edit materializes into rows.
    public var ownChapterData: [SendableChapter] {
        guard !(chapters?.isEmpty ?? true) else {
            return derivedChapters
        }
        let stored = Video.getSortedChapters(nil, chapters)
        return stored.isEmpty ? derivedChapters : stored.map(\.toExport)
    }

    private var hasChapterRows: Bool {
        !(chapters?.isEmpty ?? true) || !(mergedChapters?.isEmpty ?? true)
    }

    /// Cached rather than stored as rows.
    public var derivedChapters: [SendableChapter] {
        let cached: [SendableChapter]? = isPodcast
            ? ChapterService.fetchedChapters(youtubeId: youtubeId, duration: duration)
            : nil
        let parsed = cached ?? ChapterService.derivedChapters(
            youtubeId: youtubeId,
            videoDescription: videoDescription,
            duration: duration
        )
        return ChapterService.applySkipFilter(to: Video.getSortedChapters(nil, parsed))
    }

    public var hasInboxEntry: Bool? {
        inboxEntry != nil
    }

    public static func getSortedChapters<T: ChapterData>(
        _ mergedChapters: [T]?,
        _ chapters: [T]?
    ) -> [T] {
        var result = [T]()

        // the setting is only read when there's a merge to choose between: derived chapters come
        // through here with no merged set at all, on the app's main chapter read path
        if (mergedChapters?.count ?? 0) > 1,
           NSUbiquitousKeyValueStore.default.bool(forKey: Const.mergeSponsorBlockChapters) {
            result = mergedChapters ?? []
        } else if (chapters?.count ?? 0) > 1 {
            result = chapters ?? []
        }
        // for `Chapter`, startTime is a SwiftData read that traps if the row goes away mid-sort
        return result
            .map { (startTime: $0.startTime, chapter: $0) }
            .sorted { $0.startTime < $1.startTime }
            .map(\.chapter)
    }

    public var remainingTime: Double? {
        guard let duration = duration else { return nil }
        return duration - (elapsedSeconds ?? 0)
    }

    public var hasFinished: Bool? {
        guard let duration = duration else {
            return nil
        }
        return duration - 10 < (elapsedSeconds ?? 0)
    }

    public var description: String {
        return "Video: \(title) (\(url?.absoluteString ?? ""))"
    }

    public var queueEntryData: QueueEntryData? {
        queueEntry
    }

    public var toExport: SendableVideo? {
        SendableVideo(
            persistentId: self.persistentModelID,
            youtubeId: youtubeId,
            title: title,
            url: url,
            thumbnailUrl: thumbnailUrl,
            youtubeChannelId: youtubeChannelId,
            duration: duration,
            noDuration: noDuration,
            elapsedSeconds: elapsedSeconds,
            publishedDate: publishedDate,
            updatedDate: updatedDate,
            watchedDate: watchedDate,
            deferDate: deferDate,
            isYtShort: isYtShort,
            videoDescription: videoDescription,
            bookmarkedDate: bookmarkedDate,
            mediaUrl: mediaUrl,
            isAudioOnly: isAudioOnly,
            chaptersUrl: chaptersUrl,
            createdDate: createdDate,
            hasInboxEntry: inboxEntry != nil,
            queueEntry: queueEntry?.toExport,
            isNew: isNew,
            )
    }

    /// Tells everything reading `sortedChapterData` that this video's chapters changed.
    public func chaptersDidChange() {
        chapterRevision &+= 1
    }

    public var toExportWithSubscription: SendableVideo? {
        var video = toExport
        video?.subscription = subscription?.toExport
        return video
    }

    public init(title: String,
                url: URL?,
                youtubeId: String,
                thumbnailUrl: URL? = nil,
                publishedDate: Date? = nil,
                updatedDate: Date? = nil,
                youtubeChannelId: String? = nil,
                duration: Double? = nil,
                noDuration: Bool? = nil,
                elapsedSeconds: Double? = nil,
                videoDescription: String? = nil,
                watchedDate: Date? = nil,
                deferDate: Date? = nil,
                isYtShort: Bool? = nil,
                bookmarkedDate: Date? = nil,
                mediaUrl: URL? = nil,
                isAudioOnly: Bool? = nil,
                chaptersUrl: URL? = nil,
                createdDate: Date? = .now,
                isNew: Bool = false,
                ) {
        self.title = title
        self.url = url
        self.youtubeId = youtubeId
        self.youtubeChannelId = youtubeChannelId
        self.thumbnailUrl = thumbnailUrl
        self.publishedDate = publishedDate
        self.updatedDate = updatedDate
        self.duration = duration
        self.noDuration = noDuration
        self.elapsedSeconds = elapsedSeconds
        self.videoDescription = videoDescription
        self.watchedDate = watchedDate
        self.deferDate = deferDate
        self.isYtShort = isYtShort
        self.bookmarkedDate = bookmarkedDate
        self.mediaUrl = mediaUrl
        self.isAudioOnly = isAudioOnly
        self.chaptersUrl = chaptersUrl
        self.createdDate = createdDate
        self.isNew = isNew
    }
}
