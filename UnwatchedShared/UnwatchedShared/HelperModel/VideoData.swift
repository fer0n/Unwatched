//
//  VideoData.swift
//  UnwatchedShared
//

import SwiftData

public protocol VideoData {
    var title: String { get }
    var elapsedSeconds: Double? { get }
    var duration: Double? { get }
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

    var sortedChapterData: [ChapterData] { get }
    var subscriptionData: (any SubscriptionData)? { get }
    var hasInboxEntry: Bool? { get }
}
