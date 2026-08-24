//
//  ChapterService+Derived.swift
//  UnwatchedShared
//

import CryptoKit
import Foundation
import OSLog
import SwiftData

public extension ChapterService {

    /// In-memory layer in front of `CachedChapters`, same arrangement as
    /// `ImageService.decodedImageCache` in front of `CachedImage`.
    static let derivedChapterCache = DerivedChapterCache()

    /// Chapters for a video, parsed from its description.
    static func derivedChapters(
        youtubeId: String,
        videoDescription: String?,
        duration: Double?
    ) -> [SendableChapter] {
        // This is the read path for every chapter the app shows, so it runs inside view bodies:
        // check the memory cache against the description itself before hashing it.
        if let cached = derivedChapterCache[youtubeId],
           cached.matches(videoDescription, duration) {
            return cached.chapters
        }

        // Nothing to parse and nothing that could have been stored — `store` only ever runs past
        // this point. Memoized like any other result: without it, a video whose description
        // hasn't arrived yet would open a `ModelContext` and hit the local store on *every* read,
        // and this gets called several times per scrub tick.
        guard let videoDescription else {
            derivedChapterCache[youtubeId] = DerivedChapters(
                source: nil, duration: duration, chapters: []
            )
            return []
        }

        let hash = sourceHash(videoDescription, duration)

        if let stored = loadCached(youtubeId: youtubeId, hash: hash) {
            derivedChapterCache[youtubeId] = DerivedChapters(
                source: videoDescription, duration: duration, chapters: stored
            )
            return stored
        }

        var chapters = dedupedByStartTime(extractChapters(from: videoDescription, videoDuration: duration))
        for index in chapters.indices {
            chapters[index].videoId = youtubeId
        }

        derivedChapterCache[youtubeId] = DerivedChapters(
            source: videoDescription, duration: duration, chapters: chapters
        )
        store(chapters, youtubeId: youtubeId, hash: hash)
        return chapters
    }

    /// Chapters that were fetched rather than parsed: a podcast episode's, from the feed's inline Podlove markers,
    /// its `podcast:chapters` file, or the episode's own ID3 frames.
    static func fetchedChapters(youtubeId: String, duration: Double?) -> [SendableChapter]? {
        if let cached = derivedChapterCache[youtubeId] {
            // a memoized parse means there's nothing fetched for this one; the store already said so
            guard cached.isFetched else { return nil }
            return updateDurationAndEndTime(in: cached.chapters, videoDuration: duration)
        }
        guard let stored = loadCached(youtubeId: youtubeId, hash: fetchedSourceHash) else {
            return nil
        }
        derivedChapterCache[youtubeId] = DerivedChapters(
            source: nil, duration: nil, chapters: stored, isFetched: true
        )
        return updateDurationAndEndTime(in: stored, videoDuration: duration)
    }

    /// Caches what was fetched for a podcast episode, replacing whatever was cached for it before.
    static func cachePodcastChapters(_ chapters: [SendableChapter], youtubeId: String) {
        var chapters = chapters.sorted { $0.startTime < $1.startTime }
        for index in chapters.indices {
            chapters[index].videoId = youtubeId
        }
        derivedChapterCache[youtubeId] = DerivedChapters(
            source: nil, duration: nil, chapters: chapters, isFetched: true
        )
        store(chapters, youtubeId: youtubeId, hash: fetchedSourceHash)
    }

    /// Marks a cache entry as fetched rather than parsed.
    private static var fetchedSourceHash: String { "fetched" }

    /// Drops both cache layers for a video, e.g.
    static func invalidateDerivedChapters(youtubeId: String) {
        derivedChapterCache[youtubeId] = nil

        cacheWriteQueue.sync {
            let context = ModelContext(DataProvider.shared.localCacheContainer)
            var fetch = FetchDescriptor<CachedChapters>(predicate: #Predicate {
                $0.youtubeId == youtubeId
            })
            fetch.fetchLimit = 1
            guard let existing = try? context.fetch(fetch).first else { return }
            context.delete(existing)
            try? context.save()
        }
    }

    /// Drops the whole derived-chapter cache, for the "delete everything" paths — same role as
    /// `ImageService.deleteAllImages`.
    static func deleteAllDerivedChapters() -> Task<(), Error> {
        Task {
            let context = ModelContext(DataProvider.shared.localCacheContainer)
            let entries = try context.fetch(FetchDescriptor<CachedChapters>())
            for entry in entries {
                context.delete(entry)
            }
            derivedChapterCache.removeAll()
            try context.save()
        }
    }

    /// Sheds entries for videos nothing has looked at in a while, mirroring
    /// `ImageService.cleanupImages` — an entry is written per video whose chapters get read and
    /// never removed when the video itself goes, so the store would only ever grow. Losing one
    /// costs a re-parse, nothing more.
    static func cleanupDerivedChapters(olderThanDays days: Int) {
        Task.detached {
            let context = ModelContext(DataProvider.shared.localCacheContainer)
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now

            let fetch = FetchDescriptor<CachedChapters>(predicate: #Predicate {
                $0.updatedDate < cutoffDate
            })
            guard let entries = try? context.fetch(fetch), !entries.isEmpty else { return }

            for entry in entries {
                derivedChapterCache[entry.youtubeId] = nil
                context.delete(entry)
            }
            Log.info("cleanupDerivedChapters: \(entries.count) entries older than \(days) days")
            try? context.save()
        }
    }

    // MARK: - private

    /// A start time identifies a chapter: it's what `chapterId` — and view identity with it — is
    /// built from. Descriptions do list the same timestamp twice though, and nothing in the parse
    /// dedupes, which would leave two chapters sharing one id inside a `ForEach`. The last of a
    /// run wins: it's the one whose end time reaches the next distinct chapter.
    private static func dedupedByStartTime(_ chapters: [SendableChapter]) -> [SendableChapter] {
        var lastIndex = [Double: Int]()
        for (index, chapter) in chapters.enumerated() {
            lastIndex[chapter.startTime] = index
        }
        guard lastIndex.count < chapters.count else { return chapters }
        return chapters.enumerated()
            .filter { lastIndex[$0.element.startTime] == $0.offset }
            .map(\.element)
    }

    /// Deliberately not `hashValue`: Swift seeds string hashing per process, so it wouldn't
    /// match across launches and every entry would look stale.
    private static func sourceHash(_ videoDescription: String?, _ duration: Double?) -> String {
        let input = "\(videoDescription ?? "")|\(duration ?? 0)"
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private static func loadCached(youtubeId: String, hash: String) -> [SendableChapter]? {
        let context = ModelContext(DataProvider.shared.localCacheContainer)
        var fetch = FetchDescriptor<CachedChapters>(predicate: #Predicate {
            $0.youtubeId == youtubeId
        })
        fetch.fetchLimit = 1

        guard let entry = try? context.fetch(fetch).first, entry.sourceHash == hash else {
            return nil
        }
        guard var chapters = try? JSONDecoder().decode([SendableChapter].self, from: entry.data) else {
            Log.error("loadCached: couldn't decode chapters for \(youtubeId)")
            return nil
        }
        for index in chapters.indices {
            chapters[index].videoId = youtubeId
        }
        return chapters
    }

    /// Serial, and shared with `invalidateDerivedChapters`: writes are made off the caller because
    /// reads happen inside view bodies, and an invalidate that overtook a store in flight would
    /// leave the entry it was meant to remove.
    private static let cacheWriteQueue = DispatchQueue(label: "com.pentlandFirth.derivedChapterCache")

    private static func store(_ chapters: [SendableChapter], youtubeId: String, hash: String) {
        guard let data = try? JSONEncoder().encode(chapters) else {
            Log.error("store: couldn't encode chapters for \(youtubeId)")
            return
        }

        cacheWriteQueue.async {
            let context = ModelContext(DataProvider.shared.localCacheContainer)
            var fetch = FetchDescriptor<CachedChapters>(predicate: #Predicate {
                $0.youtubeId == youtubeId
            })
            fetch.fetchLimit = 1

            if let existing = try? context.fetch(fetch).first {
                existing.data = data
                existing.sourceHash = hash
                existing.updatedDate = .now
            } else {
                context.insert(
                    CachedChapters(youtubeId: youtubeId, data: data, sourceHash: hash)
                )
            }
            try? context.save()
        }
    }
}

public struct DerivedChapters: Sendable {
    /// What these were parsed from, kept whole rather than hashed so a cache hit costs a
    /// comparison instead of a digest — see `ChapterService.derivedChapters`.
    public let source: String?
    public let duration: Double?
    public let chapters: [SendableChapter]

    /// Fetched for a podcast episode instead of parsed from a description — see `ChapterService.fetchedChapters`.
    public let isFetched: Bool

    public init(
        source: String?,
        duration: Double?,
        chapters: [SendableChapter],
        isFetched: Bool = false
    ) {
        self.source = source
        self.duration = duration
        self.chapters = chapters
        self.isFetched = isFetched
    }

    public func matches(_ description: String?, _ duration: Double?) -> Bool {
        !isFetched && source == description && self.duration == duration
    }
}

public final class DerivedChapterCache: @unchecked Sendable {
    private let cache = NSCache<NSString, CacheBox>()

    public init(countLimit: Int = 500) {
        cache.countLimit = countLimit
    }

    public subscript(key: String) -> DerivedChapters? {
        get { cache.object(forKey: key as NSString)?.value }
        set {
            guard let newValue else {
                cache.removeObject(forKey: key as NSString)
                return
            }
            cache.setObject(CacheBox(newValue), forKey: key as NSString)
        }
    }

    public func removeAll() {
        cache.removeAllObjects()
    }

    /// `NSCache` needs a class
    private final class CacheBox {
        let value: DerivedChapters
        init(_ value: DerivedChapters) { self.value = value }
    }
}
