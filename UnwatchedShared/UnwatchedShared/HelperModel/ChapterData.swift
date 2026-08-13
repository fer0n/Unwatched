//
//  ChapterData.swift
//  UnwatchedShared
//

import Foundation
import SwiftData

/// Everything a view needs to render a chapter, whether it's a persisted `Chapter` or a
/// `SendableChapter` derived from the video description.
public protocol ChapterData {
    var title: String? { get }
    var startTime: Double { get }
    var endTime: Double? { get }
    var duration: Double? { get }
    var isActive: Bool { get }
    var category: ChapterCategory? { get }
    var link: URL? { get }

    /// The youtubeId of the video this chapter belongs to
    var videoId: String? { get }

    /// `nil` for chapters that only exist in memory. Use `chapterId` for view identity —
    /// most chapters aren't backed by a row.
    var persistentId: PersistentIdentifier? { get }
}

public extension ChapterData {
    /// Chapter origin isn't the video directly
    var isExternal: Bool {
        category?.isExternal ?? false
    }

    var hasPriority: Bool {
        category?.hasPriority ?? false
    }

    /// View identity. Stable across re-parsing and across a chapter being materialized into a
    /// `Chapter` row, so views don't churn when either happens. A start time is unique within a
    /// video, so pairing it with the video id is enough to stay unique across videos too.
    var chapterId: String {
        "\(videoId ?? "-")-\(startTime)"
    }
}
