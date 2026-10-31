//
//  FeedFallbackService.swift
//  UnwatchedShared
//

import Foundation

/// A channel's new uploads from InnerTube, for while YouTube's RSS feeds are down.
public enum FeedFallbackService {
    static let feedLength = 15
    /// Covers the rounding of "1 day ago".
    static let relativeDateMargin: TimeInterval = 2 * 24 * 60 * 60

    /// Uploads that may be newer than `cutoff`, by their approximate date.
    public static func candidates(_ api: InnerTubeAPI, channelId: String, after cutoff: Date) async throws -> [ITVideo] {
        let page = try await api.fetchChannelVideos(channelId: channelId)
        return page.videos.prefix(feedLength).filter { video in
            guard !video.isUpcoming, !video.isLive, !video.isMembersOnly,
                  let approximate = video.publishedAt else { return false }
            return approximate > cutoff.addingTimeInterval(-relativeDateMargin)
        }
    }

    /// The candidates published after `cutoff` by their exact date. Ones that can't be dated are left out.
    public static func videos(
        _ api: InnerTubeAPI,
        from candidates: [ITVideo],
        channelId: String,
        feedTitle: String,
        after cutoff: Date
    ) async -> [SendableVideo] {
        await withTaskGroup(of: SendableVideo?.self) { group in
            for candidate in candidates {
                group.addTask {
                    guard let info = try? await api.fetchVideoInfo(videoId: candidate.id),
                          let publishedDate = info.publishedDate,
                          publishedDate > cutoff else { return nil }
                    return makeVideo(
                        candidate,
                        publishedDate: publishedDate,
                        description: info.videoDescription,
                        channelId: channelId,
                        feedTitle: feedTitle
                    )
                }
            }
            return await group
                .compactMap { $0 }
                .reduce(into: []) { $0.append($1) }
                .sorted { ($0.publishedDate ?? .distantPast) > ($1.publishedDate ?? .distantPast) }
        }
    }

    /// No `updatedDate`, so the first RSS refresh replaces the fields with the feed's.
    private static func makeVideo(
        _ candidate: ITVideo,
        publishedDate: Date,
        description: String?,
        channelId: String,
        feedTitle: String
    ) -> SendableVideo {
        let description = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        return SendableVideo(
            youtubeId: candidate.id,
            title: candidate.title,
            url: YoutubeUrlParser.watchUrl(youtubeId: candidate.id),
            thumbnailUrl: candidate.highQualityThumbnailURL,
            youtubeChannelId: channelId,
            feedTitle: feedTitle,
            duration: candidate.duration,
            chapters: ChapterService.extractChapters(from: description ?? "", videoDuration: nil),
            publishedDate: publishedDate,
            isYtShort: false,
            videoDescription: description
        )
    }
}
