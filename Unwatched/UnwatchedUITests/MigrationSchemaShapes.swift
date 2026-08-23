//
//  MigrationSchemaShapes.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData
import UnwatchedShared

// swiftlint:disable line_length

/// Recorded shapes of every shipped schema version. These describe stores that already exist on
/// disk, so a change here is only ever correct when a genuinely new version is appended — editing
/// an existing entry means some installed store can no longer be matched to its stamped version.
///
/// To append a new version, temporarily re-add the recorder that produced this (see git history
/// for `testRecordShapes`) rather than hand-editing.
extension MigrationTests {
    static let expectedShapes: [String: [String: [String]]] = [
        "1.0.0": [
            "CachedImage": ["createdOn", "imageData", "imageUrl", "subscription", "video"],
            "Chapter": ["category", "duration", "endTime", "isActive", "mergedChapterVideo", "startTime", "title", "video"],
            "InboxEntry": ["date", "video"],
            "QueueEntry": ["order", "video"],
            "Subscription": ["author", "cachedImage", "customAspectRatio", "customSpeedSetting", "isArchived", "link", "mostRecentVideoDate", "placeVideosIn", "subscribedDate", "thumbnailUrl", "title", "videos", "youtubeChannelId", "youtubePlaylistId", "youtubeUserName"],
            "Video": ["bookmarkedDate", "cachedImage", "chapters", "clearedInboxDate", "createdDate", "duration", "elapsedSeconds", "inboxEntry", "isYtShort", "mergedChapters", "publishedDate", "queueEntry", "sponserBlockUpdateDate", "subscription", "thumbnailUrl", "title", "updatedDate", "url", "videoDescription", "watchEntries", "watched", "youtubeChannelId", "youtubeId"],
            "WatchEntry": ["date", "video"]
        ],
        "1.1.0": [
            "Chapter": ["category", "duration", "endTime", "isActive", "mergedChapterVideo", "startTime", "title", "video"],
            "InboxEntry": ["date", "video"],
            "QueueEntry": ["order", "video"],
            "Subscription": ["author", "customAspectRatio", "customSpeedSetting", "isArchived", "link", "mostRecentVideoDate", "placeVideosIn", "subscribedDate", "thumbnailUrl", "title", "videos", "youtubeChannelId", "youtubePlaylistId", "youtubeUserName"],
            "Video": ["bookmarkedDate", "chapters", "clearedInboxDate", "createdDate", "duration", "elapsedSeconds", "inboxEntry", "isYtShort", "mergedChapters", "publishedDate", "queueEntry", "sponserBlockUpdateDate", "subscription", "thumbnailUrl", "title", "updatedDate", "url", "videoDescription", "watchEntries", "watched", "youtubeChannelId", "youtubeId"],
            "WatchEntry": ["date", "video"]
        ],
        "1.2.0": [
            "Chapter": ["category", "duration", "endTime", "isActive", "mergedChapterVideo", "startTime", "title", "video"],
            "InboxEntry": ["date", "video"],
            "QueueEntry": ["order", "video"],
            "Subscription": ["author", "customAspectRatio", "customSpeedSetting", "isArchived", "link", "mostRecentVideoDate", "placeVideosIn", "subscribedDate", "thumbnailUrl", "title", "videos", "youtubeChannelId", "youtubePlaylistId", "youtubeUserName"],
            "Video": ["bookmarkedDate", "chapters", "clearedInboxDate", "createdDate", "duration", "elapsedSeconds", "inboxEntry", "isYtShort", "mergedChapters", "publishedDate", "queueEntry", "sponserBlockUpdateDate", "subscription", "thumbnailUrl", "title", "updatedDate", "url", "videoDescription", "watchedDate", "youtubeChannelId", "youtubeId"]
        ],
        "1.3.0": [
            "Chapter": ["category", "duration", "endTime", "isActive", "mergedChapterVideo", "startTime", "title", "video"],
            "InboxEntry": ["date", "video"],
            "QueueEntry": ["order", "video"],
            "Subscription": ["author", "customAspectRatio", "customSpeedSetting", "isArchived", "link", "mostRecentVideoDate", "placeVideosIn", "subscribedDate", "thumbnailUrl", "title", "videos", "youtubeChannelId", "youtubePlaylistId", "youtubeUserName"],
            "Video": ["bookmarkedDate", "chapters", "clearedInboxDate", "createdDate", "duration", "elapsedSeconds", "inboxEntry", "isYtShort", "mergedChapters", "publishedDate", "queueEntry", "sponserBlockUpdateDate", "subscription", "thumbnailUrl", "title", "updatedDate", "url", "videoDescription", "watchedDate", "youtubeChannelId", "youtubeId"]
        ],
        "1.4.0": [
            "Chapter": ["category", "duration", "endTime", "isActive", "mergedChapterVideo", "startTime", "title", "video"],
            "InboxEntry": ["date", "video"],
            "QueueEntry": ["order", "video"],
            "Subscription": ["_shortsSetting", "author", "customAspectRatio", "customSpeedSetting", "isArchived", "link", "mostRecentVideoDate", "placeVideosIn", "subscribedDate", "thumbnailUrl", "title", "videos", "youtubeChannelId", "youtubePlaylistId", "youtubeUserName"],
            "Video": ["bookmarkedDate", "chapters", "clearedInboxDate", "createdDate", "duration", "elapsedSeconds", "inboxEntry", "isYtShort", "mergedChapters", "publishedDate", "queueEntry", "sponserBlockUpdateDate", "subscription", "thumbnailUrl", "title", "updatedDate", "url", "videoDescription", "watchedDate", "youtubeChannelId", "youtubeId"]
        ],
        "1.5.0": [
            "Chapter": ["category", "duration", "endTime", "isActive", "mergedChapterVideo", "startTime", "title", "video"],
            "InboxEntry": ["date", "video"],
            "QueueEntry": ["order", "video"],
            "Subscription": ["_shortsSetting", "author", "customAspectRatio", "customSpeedSetting", "isArchived", "link", "mostRecentVideoDate", "placeVideosIn", "subscribedDate", "thumbnailUrl", "title", "videos", "youtubeChannelId", "youtubePlaylistId", "youtubeUserName"],
            "Video": ["bookmarkedDate", "chapters", "clearedInboxDate", "createdDate", "deferDate", "duration", "elapsedSeconds", "inboxEntry", "isYtShort", "mergedChapters", "publishedDate", "queueEntry", "sponserBlockUpdateDate", "subscription", "thumbnailUrl", "title", "updatedDate", "url", "videoDescription", "watchedDate", "youtubeChannelId", "youtubeId"]
        ],
        "1.6.0": [
            "Chapter": ["category", "duration", "endTime", "isActive", "mergedChapterVideo", "startTime", "title", "video"],
            "InboxEntry": ["date", "video", "youtubeId"],
            "QueueEntry": ["order", "video", "youtubeId"],
            "Subscription": ["_shortsSetting", "author", "customAspectRatio", "customSpeedSetting", "isArchived", "link", "mostRecentVideoDate", "placeVideosIn", "subscribedDate", "thumbnailUrl", "title", "videos", "youtubeChannelId", "youtubePlaylistId", "youtubeUserName"],
            "Video": ["bookmarkedDate", "chapters", "clearedInboxDate", "createdDate", "deferDate", "duration", "elapsedSeconds", "inboxEntry", "isYtShort", "mergedChapters", "publishedDate", "queueEntry", "sponserBlockUpdateDate", "subscription", "thumbnailUrl", "title", "updatedDate", "url", "videoDescription", "watchedDate", "youtubeChannelId", "youtubeId"]
        ],
        "1.7.0": [
            "Chapter": ["category", "duration", "endTime", "isActive", "mergedChapterVideo", "startTime", "title", "video"],
            "InboxEntry": ["date", "video", "youtubeId"],
            "QueueEntry": ["order", "video", "youtubeId"],
            "Subscription": ["_shortsSetting", "_videoPlacement", "author", "customAspectRatio", "customSpeedSetting", "isArchived", "link", "mostRecentVideoDate", "subscribedDate", "thumbnailUrl", "title", "videos", "youtubeChannelId", "youtubePlaylistId", "youtubeUserName"],
            "Video": ["bookmarkedDate", "chapters", "clearedInboxDate", "createdDate", "deferDate", "duration", "elapsedSeconds", "inboxEntry", "isYtShort", "mergedChapters", "publishedDate", "queueEntry", "sponserBlockUpdateDate", "subscription", "thumbnailUrl", "title", "updatedDate", "url", "videoDescription", "watchedDate", "youtubeChannelId", "youtubeId"]
        ],
        "1.8.0": [
            "Chapter": ["category", "duration", "endTime", "isActive", "link", "mergedChapterVideo", "startTime", "title", "video"],
            "InboxEntry": ["date", "video", "youtubeId"],
            "QueueEntry": ["order", "video", "youtubeId"],
            "Subscription": ["_shortsSetting", "_videoPlacement", "author", "customAspectRatio", "customSpeedSetting", "isArchived", "link", "mostRecentVideoDate", "subscribedDate", "thumbnailUrl", "title", "videos", "youtubeChannelId", "youtubePlaylistId", "youtubeUserName"],
            "Video": ["bookmarkedDate", "chapters", "clearedInboxDate", "createdDate", "deferDate", "duration", "elapsedSeconds", "inboxEntry", "isYtShort", "mergedChapters", "publishedDate", "queueEntry", "sponserBlockUpdateDate", "subscription", "thumbnailUrl", "title", "updatedDate", "url", "videoDescription", "watchedDate", "youtubeChannelId", "youtubeId"]
        ],
        "1.9.0": [
            "Chapter": ["category", "duration", "endTime", "isActive", "link", "mergedChapterVideo", "startTime", "title", "video"],
            "InboxEntry": ["date", "video", "youtubeId"],
            "QueueEntry": ["order", "video", "youtubeId"],
            "Subscription": ["_shortsSetting", "_videoPlacement", "author", "customAspectRatio", "customSpeedSetting", "isArchived", "link", "mostRecentVideoDate", "subscribedDate", "thumbnailUrl", "title", "videos", "youtubeChannelId", "youtubePlaylistId", "youtubeUserName"],
            "Video": ["bookmarkedDate", "chapters", "clearedInboxDate", "createdDate", "deferDate", "duration", "elapsedSeconds", "inboxEntry", "isNew", "isYtShort", "mergedChapters", "publishedDate", "queueEntry", "sponserBlockUpdateDate", "subscription", "thumbnailUrl", "title", "updatedDate", "url", "videoDescription", "watchedDate", "youtubeChannelId", "youtubeId"]
        ],
        "1.10.0": [
            "Chapter": ["category", "duration", "endTime", "isActive", "link", "mergedChapterVideo", "startTime", "title", "video"],
            "InboxEntry": ["date", "video", "youtubeId"],
            "QueueEntry": ["order", "video", "youtubeId"],
            "Subscription": ["_shortsSetting", "_videoPlacement", "author", "customAspectRatio", "customSpeedSetting", "isArchived", "link", "mostRecentVideoDate", "subscribedDate", "thumbnailUrl", "title", "videos", "youtubeChannelId", "youtubePlaylistId", "youtubeUserName"],
            "Video": ["bookmarkedDate", "chapters", "createdDate", "deferDate", "duration", "elapsedSeconds", "inboxEntry", "isNew", "isYtShort", "mergedChapters", "publishedDate", "queueEntry", "sponserBlockUpdateDate", "subscription", "thumbnailUrl", "title", "updatedDate", "url", "videoDescription", "watchedDate", "youtubeChannelId", "youtubeId"]
        ],
        "1.11.0": [
            "Chapter": ["category", "duration", "endTime", "isActive", "link", "mergedChapterVideo", "startTime", "title", "video"],
            "InboxEntry": ["date", "video", "youtubeId"],
            "QueueEntry": ["order", "video", "youtubeId"],
            "Subscription": ["_shortsSetting", "_videoPlacement", "author", "customAspectRatio", "customSpeedSetting", "filterText", "isArchived", "link", "mostRecentVideoDate", "subscribedDate", "thumbnailUrl", "title", "videos", "youtubeChannelId", "youtubePlaylistId", "youtubeUserName"],
            "Video": ["bookmarkedDate", "chapters", "createdDate", "deferDate", "duration", "elapsedSeconds", "inboxEntry", "isNew", "isYtShort", "mergedChapters", "publishedDate", "queueEntry", "sponserBlockUpdateDate", "subscription", "thumbnailUrl", "title", "updatedDate", "url", "videoDescription", "watchedDate", "youtubeChannelId", "youtubeId"]
        ],
        "1.12.0": [
            "Chapter": ["category", "duration", "endTime", "isActive", "link", "mergedChapterVideo", "startTime", "title", "video"],
            "InboxEntry": ["date", "video", "youtubeId"],
            "QueueEntry": ["order", "video", "youtubeId"],
            "Subscription": ["_shortsSetting", "_videoPlacement", "author", "customAspectRatio", "customSpeedSetting", "filterText", "isArchived", "link", "mostRecentVideoDate", "subscribedDate", "thumbnailUrl", "title", "videos", "youtubeChannelId", "youtubePlaylistId", "youtubeUserName"],
            "Video": ["apiUpdatedDate", "bookmarkedDate", "chapters", "createdDate", "deferDate", "duration", "elapsedSeconds", "inboxEntry", "isNew", "isYtShort", "mergedChapters", "noDuration", "publishedDate", "queueEntry", "sponserBlockUpdateDate", "subscription", "thumbnailUrl", "title", "updatedDate", "url", "videoDescription", "watchedDate", "youtubeChannelId", "youtubeId"]
        ],
        "1.13.0": [
            "Chapter": ["category", "duration", "endTime", "isActive", "link", "mergedChapterVideo", "startTime", "title", "video"],
            "InboxEntry": ["date", "video", "youtubeId"],
            "QueueEntry": ["order", "video", "youtubeId"],
            "Subscription": ["_shortsSetting", "_videoPlacement", "allowOnMatch", "author", "customAspectRatio", "customSpeedSetting", "filterText", "isArchived", "link", "mostRecentVideoDate", "subscribedDate", "thumbnailUrl", "title", "videos", "youtubeChannelId", "youtubePlaylistId", "youtubeUserName"],
            "Video": ["apiUpdatedDate", "bookmarkedDate", "chapters", "createdDate", "deferDate", "duration", "elapsedSeconds", "inboxEntry", "isNew", "isYtShort", "mergedChapters", "noDuration", "publishedDate", "queueEntry", "sponserBlockUpdateDate", "subscription", "thumbnailUrl", "title", "updatedDate", "url", "videoDescription", "watchedDate", "youtubeChannelId", "youtubeId"]
        ],
        "1.14.0": [
            "Chapter": ["category", "duration", "endTime", "isActive", "link", "mergedChapterVideo", "startTime", "title", "video"],
            "InboxEntry": ["date", "video", "youtubeId"],
            "QueueEntry": ["order", "video", "youtubeId"],
            "Subscription": ["_shortsSetting", "_videoPlacement", "allowOnMatch", "author", "customAspectRatio", "customSpeedSetting", "filterText", "isArchived", "link", "mostRecentVideoDate", "subscribedDate", "thumbnailUrl", "title", "videos", "youtubeChannelId", "youtubePlaylistId", "youtubeUserName"],
            "Video": ["apiUpdatedDate", "bookmarkedDate", "chapters", "createdDate", "deferDate", "duration", "elapsedSeconds", "inboxEntry", "isNew", "isYtShort", "mergedChapters", "noDuration", "publishedDate", "queueEntry", "sponserBlockUpdateDate", "subscription", "thumbnailUrl", "title", "updatedDate", "url", "videoDescription", "watchedDate", "youtubeChannelId", "youtubeId"],
            "WatchTimeEntry": ["channelId", "date", "watchTime"]
        ],
        "1.15.0": [
            "Chapter": ["category", "duration", "endTime", "isActive", "link", "mergedChapterVideo", "startTime", "title", "video"],
            "InboxEntry": ["date", "video", "youtubeId"],
            "QueueEntry": ["order", "video", "youtubeId"],
            "Subscription": ["_shortsSetting", "_videoPlacement", "allowOnMatch", "author", "customAspectRatio", "customSpeedSetting", "filterText", "isArchived", "link", "mostRecentVideoDate", "subscribedDate", "tags", "thumbnailUrl", "title", "videos", "youtubeChannelId", "youtubePlaylistId", "youtubeUserName"],
            "Tag": ["_mode", "createdDate", "name", "order", "quickSwitch", "subscriptions", "symbol", "videos"],
            "Video": ["apiUpdatedDate", "bookmarkedDate", "chapters", "createdDate", "deferDate", "duration", "elapsedSeconds", "inboxEntry", "isNew", "isYtShort", "mergedChapters", "noDuration", "publishedDate", "queueEntry", "sponserBlockUpdateDate", "subscription", "tags", "thumbnailUrl", "title", "updatedDate", "url", "videoDescription", "watchedDate", "youtubeChannelId", "youtubeId"],
            "WatchTimeEntry": ["channelId", "date", "watchTime"]
        ]
    ]

    static let expectedCacheShapes: [String: [String: [String]]] = [
        "1.0.0": [
            "CachedImage": ["createdOn", "imageData", "imageUrl"]
        ],
        "1.1.0": [
            "CachedImage": ["createdOn", "imageData", "imageUrl"]
        ],
        "1.2.0": [
            "CachedImage": ["colorHex", "createdOn", "imageData", "imageUrl"]
        ],
        "2.0.0": [
            "CachedImage": ["colorHex", "createdOn", "imageData", "imageUrl"],
            "Transcript": ["data", "youtubeId"]
        ],
        "2.1.0": [
            "CachedImage": ["colorHex", "createdOn", "imageData", "imageUrl", "lastAccessedOn"],
            "Transcript": ["data", "youtubeId"]
        ],
        "2.2.0": [
            "CachedImage": ["colorHex", "createdOn", "imageData", "imageUrl", "lastAccessedOn"],
            "Transcript": ["data", "youtubeId"],
            "CachedChapters": ["data", "sourceHash", "updatedDate", "youtubeId"]
        ]
    ]
}

// swiftlint:enable line_length
