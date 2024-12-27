//
//  Video.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model
public final class Video: CustomStringConvertible, Exportable, CachedImageHolder {
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
    public var updatedDate: Date?
    public var duration: Double?
    public var elapsedSeconds: Double?
    public var videoDescription: String?
    public var watchedDate: Date?
    public var subscription: Subscription?
    public var youtubeChannelId: String?
    public var isYtShort: Bool?
    public var bookmarkedDate: Date?
    public var clearedInboxDate: Date?
    public var createdDate: Date?

    public var sponserBlockUpdateDate: Date?

    // MARK: Computed Properties
    public var sortedChapters: [Chapter] {
        var result = [Chapter]()

        let settingOn = UserDefaults.standard.bool(forKey: Const.mergeSponsorBlockChapters)
        if (mergedChapters?.count ?? 0) > 1 && settingOn {
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

    public var toExport: SendableVideo? {
        SendableVideo(
            persistendId: self.persistentModelID.hashValue,
            youtubeId: youtubeId,
            title: title,
            url: url,
            thumbnailUrl: thumbnailUrl,
            youtubeChannelId: youtubeChannelId,
            duration: duration,
            elapsedSeconds: elapsedSeconds,
            publishedDate: publishedDate,
            updatedDate: updatedDate,
            watchedDate: watchedDate,
            isYtShort: isYtShort,
            videoDescription: videoDescription,
            bookmarkedDate: bookmarkedDate,
            clearedInboxDate: clearedInboxDate,
            createdDate: createdDate
        )
    }

    public init(title: String,
                url: URL?,
                youtubeId: String,
                thumbnailUrl: URL? = nil,
                publishedDate: Date? = nil,
                updatedDate: Date? = nil,
                youtubeChannelId: String? = nil,
                duration: Double? = nil,
                elapsedSeconds: Double? = nil,
                videoDescription: String? = nil,
                chapters: [Chapter] = [],
                watchedDate: Date? = nil,
                isYtShort: Bool? = nil,
                bookmarkedDate: Date? = nil,
                clearedInboxDate: Date? = nil,
                createdDate: Date? = .now) {
        self.title = title
        self.url = url
        self.youtubeId = youtubeId
        self.youtubeChannelId = youtubeChannelId
        self.thumbnailUrl = thumbnailUrl
        self.publishedDate = publishedDate
        self.updatedDate = updatedDate
        self.duration = duration
        self.elapsedSeconds = elapsedSeconds
        self.videoDescription = videoDescription
        self.chapters = chapters
        self.watchedDate = watchedDate
        self.bookmarkedDate = bookmarkedDate
        self.clearedInboxDate = clearedInboxDate
        self.createdDate = createdDate
        self.isYtShort = isYtShort
    }
}
