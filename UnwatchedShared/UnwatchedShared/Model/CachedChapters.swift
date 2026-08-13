//
//  CachedChapters.swift
//  UnwatchedShared
//

import Foundation
import SwiftData

/// Chapters parsed from a video description, cached in the local (never synced) store.
///
/// Purely derived data: it can be thrown away at any point and re-parsed from
/// `Video.videoDescription`, which is what happens on tvOS, where the local store lives in
/// `Library/Caches` and the system may purge it.
@Model public final class CachedChapters {
    @Attribute(.unique) public var youtubeId: String
    public var data: Data

    /// Digest of the description and duration these were parsed from, so an updated
    /// description invalidates the entry instead of showing stale chapters.
    public var sourceHash: String

    public var updatedDate: Date

    public init(youtubeId: String, data: Data, sourceHash: String, updatedDate: Date = .now) {
        self.youtubeId = youtubeId
        self.data = data
        self.sourceHash = sourceHash
        self.updatedDate = updatedDate
    }
}
