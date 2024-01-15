//
//  SendableVideo.swift
//  Unwatched
//

import Foundation

struct SendableVideo: Sendable {
    var youtubeId: String
    var title: String
    var url: URL
    var thumbnailUrl: URL?
    var youtubeChannelId: String?
    var feedTitle: String?
    var duration: Double?
    var chapters = [SendableChapter]()

    var publishedDate: Date?
    var status: VideoStatus?
    var watched = false

    var videoDescription: String?

    func getVideo(
        title: String? = nil,
        url: URL? = nil,
        youtubeId: String? = nil,
        thumbnailUrl: URL? = nil,
        publishedDate: Date? = nil,
        youtubeChannelId: String? = nil,
        feedTitle: String? = nil,
        duration: TimeInterval? = nil,
        videoDescription: String? = nil
    ) -> Video {
        var newChapters = chapters
        if chapters.isEmpty, let desc = self.videoDescription {
            newChapters = VideoCrawler.extractChapters(from: desc, videoDuration: duration)
        }

        return Video(
            title: title ?? self.title,
            url: url ?? self.url,
            youtubeId: youtubeId ?? self.youtubeId,
            thumbnailUrl: thumbnailUrl ?? self.thumbnailUrl,
            publishedDate: publishedDate ?? self.publishedDate,
            youtubeChannelId: youtubeChannelId ?? self.youtubeChannelId,
            feedTitle: feedTitle ?? self.feedTitle,
            duration: duration ?? self.duration,
            videoDescription: videoDescription ?? self.videoDescription,
            chapters: newChapters.map { $0.getChapter }
        )
    }
}
