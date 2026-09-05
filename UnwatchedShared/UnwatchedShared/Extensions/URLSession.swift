//
//  URLSession.swift
//  UnwatchedShared
//

import Foundation

public extension URLCache {
    /// Response cache for all of the app's sessions: memory only, nothing on disk.
    ///
    /// Every response worth keeping is already persisted by the app itself (`CachedImage`,
    /// cached transcripts and derived chapters, `PodcastEpisodeCache`, the scrubber's sheet
    /// cache), so CFNetwork's on-disk cache only wrote those bytes a second time – it was
    /// ~50% of the app's disk writes in the 1.8.10 field report, ahead of SwiftData itself.
    /// The memory capacity still covers the case this actually helps with: the same URL being
    /// requested twice while the app is running, e.g. two feed refreshes inside YouTube's
    /// 15 minute `max-age`.
    static let memoryOnly = URLCache(memoryCapacity: 16 * 1024 * 1024, diskCapacity: 0)
}

public extension URLSession {
    /// Use instead of `URLSession.shared` for every request the app makes: same behaviour,
    /// except responses never reach the disk (see `URLCache.memoryOnly`).
    static let app: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = .memoryOnly
        return URLSession(configuration: config)
    }()

    /// Empties the on-disk cache that `URLSession.shared` filled up in versions before the
    /// switch to `URLSession.app`. Nothing writes to it any more, so this only has to run
    /// until every install has done it once.
    static func purgeLegacyDiskCache() {
        URLCache.shared.removeAllCachedResponses()
    }
}
