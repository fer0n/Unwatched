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
        let title = title ?? self.title
        let description = videoDescription ?? self.videoDescription

        var newChapters = chapters
        if chapters.isEmpty, let desc = self.videoDescription {
            newChapters = VideoCrawler.extractChapters(from: desc, videoDuration: duration)
        }
        let ytShortsInfo = VideoCrawler.isYtShort(title, description: description)
        print("ytShortsInfo: \(title)", ytShortsInfo)

        return Video(
            title: title,
            url: url ?? self.url,
            youtubeId: youtubeId ?? self.youtubeId,
            thumbnailUrl: thumbnailUrl ?? self.thumbnailUrl,
            publishedDate: publishedDate ?? self.publishedDate,
            youtubeChannelId: youtubeChannelId ?? self.youtubeChannelId,
            duration: duration ?? self.duration,
            videoDescription: description,
            chapters: newChapters.map { $0.getChapter },
            isYtShort: ytShortsInfo.isShort,
            isLikelyYtShort: ytShortsInfo.isLikelyShort
        )
    }
}
