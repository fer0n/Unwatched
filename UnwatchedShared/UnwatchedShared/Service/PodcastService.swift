//
//  PodcastService.swift
//  UnwatchedShared
//

import AVFoundation
import CryptoKit
import Foundation
import OSLog

public struct PodcastFeed: Sendable {
    public let subscription: SendableSubscription
    public let episodes: [SendableVideo]
    public let showDescription: String
}

public enum PodcastService {
    /// Podcast episodes reuse `youtubeId` as their stable identity — it's what queue entries, chapters and stats are
    /// keyed by.
    public static func episodeId(guid: String) -> String {
        let digest = Insecure.SHA1.hash(data: Data(guid.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "pod-" + hex.prefix(24)
    }

    public static func isPodcastEpisodeId(_ id: String) -> Bool {
        id.hasPrefix("pod-")
    }

    public static func loadFeed(_ feedUrl: URL, limitEpisodes: Int? = nil) async throws -> PodcastFeed {
        let url = secureUrl(feedUrl) ?? feedUrl
        let data = try await VideoCrawler.fetchFeedData(url)
        return try parseFeed(data, feedUrl: url, limitEpisodes: limitEpisodes)
    }

    /// App Transport Security refuses cleartext HTTP, and podcast directories are still full of `http://` URLs —
    /// Apple's own search hands back one for shows whose site has served TLS for years.
    public static func secureUrl(_ url: URL?) -> URL? {
        guard let url, url.scheme?.lowercased() == "http" else {
            return url
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        return components?.url ?? url
    }

    public static func secureUrl(string: String?) -> URL? {
        secureUrl(string.flatMap(URL.init(string:)))
    }

    public static func parseFeed(
        _ data: Data,
        feedUrl: URL,
        limitEpisodes: Int? = nil
    ) throws -> PodcastFeed {
        let parser = PodcastFeedParser.parse(data, limitEpisodes: limitEpisodes)
        guard var subscription = parser.subscriptionInfo else {
            throw VideoCrawlerError.subscriptionInfoNotFound
        }
        subscription.link = feedUrl
        return PodcastFeed(
            subscription: subscription,
            episodes: parser.episodes,
            showDescription: parser.showDescription
        )
    }

    // MARK: - Chapters

    /// Fetches a `podcast:chapters` JSON document.
    public static func fetchChapters(_ url: URL, duration: Double?) async -> [SendableChapter]? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard response.isSuccessfulHttp else { return nil }
            let document = try JSONDecoder().decode(ChaptersDocument.self, from: data)
            let chapters = document.chapters
                .filter { $0.toc ?? true }
                .sorted { $0.startTime < $1.startTime }
                .map {
                    SendableChapter(
                        title: $0.title,
                        startTime: $0.startTime,
                        endTime: $0.endTime,
                        link: $0.url.flatMap(URL.init(string:)),
                        imageUrl: secureUrl(string: $0.img)
                    )
                }
            guard chapters.count > 1 else { return nil }
            return ChapterService.updateDurationAndEndTime(in: chapters, videoDuration: duration)
        } catch {
            Log.warning("podcast chapters failed to load: \(error.localizedDescription)")
            return nil
        }
    }

    /// Chapters carried inside the episode file as ID3 `CHAP` frames.
    public static func embeddedChapters(
        _ mediaUrl: URL,
        duration: Double?,
        episodeId: String
    ) async -> [SendableChapter]? {
        let asset = AVURLAsset(url: mediaUrl)
        do {
            let groups = try await asset.loadChapterMetadataGroups(
                bestMatchingPreferredLanguages: Locale.preferredLanguages
            )
            var chapters = [SendableChapter]()
            for group in groups {
                let title = try await AVMetadataItem
                    .metadataItems(from: group.items, filteredByIdentifier: .commonIdentifierTitle)
                    .first?
                    .load(.stringValue)
                let start = group.timeRange.start.seconds
                guard start.isFinite else { continue }
                let end = group.timeRange.end.seconds
                let artwork = try? await AVMetadataItem
                    .metadataItems(from: group.items, filteredByIdentifier: .commonIdentifierArtwork)
                    .first?
                    .load(.dataValue)
                var imageUrl: URL?
                if let artwork {
                    imageUrl = await ChapterImageStore.store(artwork, videoId: episodeId, startTime: start)
                }
                chapters.append(
                    SendableChapter(
                        title: title,
                        startTime: start,
                        endTime: end.isFinite ? end : nil,
                        imageUrl: imageUrl
                    )
                )
            }
            if chapters.count > 1 {
                return ChapterService.updateDurationAndEndTime(
                    in: chapters.sorted { $0.startTime < $1.startTime },
                    videoDuration: duration
                )
            }
        } catch {
            Log.info("embedded chapter groups unavailable: \(error.localizedDescription)")
        }

        // AVFoundation only reads chapter tracks (MPEG-4).
        guard let tagged = await ID3ChapterReader.chapters(from: mediaUrl, episodeId: episodeId) else {
            return nil
        }
        return ChapterService.updateDurationAndEndTime(in: tagged, videoDuration: duration)
    }

    /// The inline Podlove markers an item carries, re-read from the feed.
    public static func inlineChapters(feedUrl: URL, episodeId: String) async -> [SendableChapter]? {
        let data: Data
        do {
            let url = secureUrl(feedUrl) ?? feedUrl
            data = try await VideoCrawler.fetchFeedData(url)
        } catch {
            Log.warning("podcast chapters feed failed to load: \(error.localizedDescription)")
            return nil
        }

        let parser = PodcastFeedParser.parse(data)
        guard let episode = parser.episodes.first(where: { $0.youtubeId == episodeId }),
              episode.chapters.count > 1 else {
            return nil
        }
        return episode.chapters
    }

    // MARK: - Transcripts

    /// The transcript a show publishes for an episode, if it publishes one.
    public static func fetchTranscript(feedUrl: URL, episodeId: String) async -> PodcastTranscriptLookup {
        let data: Data
        do {
            let url = secureUrl(feedUrl) ?? feedUrl
            data = try await VideoCrawler.fetchFeedData(url)
        } catch {
            Log.warning("podcast transcript feed failed to load: \(error.localizedDescription)")
            return .unreachable
        }

        let parser = PodcastFeedParser.parse(data)
        guard let sources = parser.transcriptSources[episodeId],
              let source = PodcastTranscriptSource.best(from: sources) else {
            Log.info("no podcast:transcript for \(episodeId)")
            return .notPublished
        }
        guard let entries = await fetchTranscript(source) else {
            return .unreachable
        }
        return .found(entries)
    }

    public static func fetchTranscript(_ source: PodcastTranscriptSource) async -> [TranscriptEntry]? {
        do {
            let (data, response) = try await URLSession.shared.data(from: source.url)
            guard response.isSuccessfulHttp else {
                Log.warning("podcast transcript unavailable")
                return nil
            }
            let entries = PodcastTranscriptParser.parse(data, format: source.format)
            return entries.isEmpty ? nil : entries
        } catch {
            Log.warning("podcast transcript failed to load: \(error.localizedDescription)")
            return nil
        }
    }

    private struct ChaptersDocument: Decodable {
        let chapters: [Entry]

        struct Entry: Decodable {
            let startTime: Double
            let endTime: Double?
            let title: String?
            let url: String?
            let img: String?
            let toc: Bool?
        }
    }
}
