//
//  UnwatchedSchemaV1.swift
//  Unwatched
//

import SwiftData
import SwiftUI

enum UnwatchedSchemaV1p2: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 2, 0)

    static var models: [any PersistentModel.Type] {
        [
            Video.self,
            Subscription.self,
            QueueEntry.self,
            InboxEntry.self,
            Chapter.self
        ]
    }

    @Model
    final class Video: CustomStringConvertible, CachedImageHolder {
        @Relationship(deleteRule: .cascade, inverse: \InboxEntry.video) var inboxEntry: InboxEntry?
        @Relationship(deleteRule: .cascade, inverse: \QueueEntry.video) var queueEntry: QueueEntry?
        @Relationship(deleteRule: .cascade, inverse: \Chapter.video) var chapters: [Chapter]? = []
        @Relationship(deleteRule: .cascade, inverse: \Chapter.mergedChapterVideo) var mergedChapters: [Chapter]? = []
        var youtubeId: String = UUID().uuidString

        var title: String = "-"
        var url: URL?

        var thumbnailUrl: URL?
        var publishedDate: Date?
        var updatedDate: Date?
        var duration: Double?
        var elapsedSeconds: Double?
        var videoDescription: String?
        var watchedDate: Date?
        var subscription: Subscription?
        var youtubeChannelId: String?
        var isYtShort: Bool = false
        var bookmarkedDate: Date?
        var clearedInboxDate: Date?
        var createdDate: Date?

        var sponserBlockUpdateDate: Date?

        // MARK: Computed Properties
        var sortedChapters: [Chapter] {
            var result = [Chapter]()

            let settingOn = UserDefaults.standard.bool(forKey: Const.mergeSponsorBlockChapters)
            if (mergedChapters?.count ?? 0) > 1 && settingOn {
                result = mergedChapters ?? []
            } else if (chapters?.count ?? 0) > 1 {
                result = chapters ?? []
            }
            return result.sorted(by: { $0.startTime < $1.startTime })
        }

        var remainingTime: Double? {
            guard let duration = duration else { return nil }
            return duration - (elapsedSeconds ?? 0)
        }

        var hasFinished: Bool? {
            guard let duration = duration else {
                return nil
            }
            return duration - 10 < (elapsedSeconds ?? 0)
        }

        var description: String {
            return "Video: \(title) (\(url?.absoluteString ?? ""))"
        }

        init(title: String,
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
             isYtShort: Bool = false,
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
}
