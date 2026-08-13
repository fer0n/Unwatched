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

    public var createdDate: Date?
    public var isNew: Bool = false

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
    ///
    /// Rows win when they exist: they're either a SponsorBlock merge or something the user
    /// edited, and both describe the video better than a fresh parse would.
    public var sortedChapterData: [SendableChapter] {
        // the row check comes first because it's the cheap one: `getSortedChapters` sorts and
        // reads the key-value store, and this runs inside view bodies
        guard hasChapterRows else {
            return derivedChapters
        }
        let stored = Video.getSortedChapters(mergedChapters, chapters)
        return stored.isEmpty ? derivedChapters : stored.map(\.toExport)
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

    /// Parsed from the description rather than stored as rows. Only videos whose chapters have
    /// been edited keep `Chapter` rows, and those take precedence.
    ///
    /// Goes through `getSortedChapters` like stored chapters do: the parse comes back in
    /// description order, which is usually but not always chronological.
    public var derivedChapters: [SendableChapter] {
        let parsed = ChapterService.derivedChapters(
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
        return result.sorted(by: { $0.startTime < $1.startTime })
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
            createdDate: createdDate,
            hasInboxEntry: inboxEntry != nil,
            queueEntry: queueEntry?.toExport,
            isNew: isNew,
            )
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
                chapters: [Chapter] = [],
                watchedDate: Date? = nil,
                deferDate: Date? = nil,
                isYtShort: Bool? = nil,
                bookmarkedDate: Date? = nil,
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
        self.chapters = chapters
        self.watchedDate = watchedDate
        self.deferDate = deferDate
        self.isYtShort = isYtShort
        self.bookmarkedDate = bookmarkedDate
        self.createdDate = createdDate
        self.isNew = isNew
    }
}
