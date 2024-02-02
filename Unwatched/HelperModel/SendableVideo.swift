//
//  SendableVideo.swift
//  Unwatched
//

import Foundation
import SwiftData

struct SendableVideo: Sendable, Codable {
    var persistendId: Int?
    var youtubeId: String
    var title: String
    var url: URL?
    var thumbnailUrl: URL?
    var youtubeChannelId: String?
    var feedTitle: String?
    var duration: Double?
    var elapsedSeconds: Double = 0
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
            elapsedSeconds: self.elapsedSeconds,
            videoDescription: description,
            chapters: newChapters.map { $0.getChapter },
            isYtShort: ytShortsInfo.isShort,
            isLikelyYtShort: ytShortsInfo.isLikelyShort
        )
    }

    init(
        persistendId: Int? = nil,
        youtubeId: String,
        title: String,
        url: URL?,
        thumbnailUrl: URL? = nil,
        youtubeChannelId: String? = nil,
        feedTitle: String? = nil,
        duration: Double? = nil,
        elapsedSeconds: Double = 0,
        chapters: [SendableChapter] = [SendableChapter](),
        publishedDate: Date? = nil,
        watched: Bool = false,
        videoDescription: String? = nil
    ) {
        self.persistendId = persistendId
        self.youtubeId = youtubeId
        self.title = title
        self.url = url
        self.thumbnailUrl = thumbnailUrl
        self.youtubeChannelId = youtubeChannelId
        self.feedTitle = feedTitle
        self.duration = duration
        self.elapsedSeconds = elapsedSeconds
        self.chapters = chapters
        self.publishedDate = publishedDate
        self.watched = watched
        self.videoDescription = videoDescription
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: SendableVideoCodingKeys.self)

        persistendId = try container.decodeIfPresent(Int.self, forKey: .persistendId)
        youtubeId = try container.decode(String.self, forKey: .youtubeId)
        title = try container.decode(String.self, forKey: .title)
        url = try container.decode(URL.self, forKey: .url)
        thumbnailUrl = try container.decodeIfPresent(URL.self, forKey: .thumbnailUrl)
        youtubeChannelId = try container.decodeIfPresent(String.self, forKey: .youtubeChannelId)
        duration = try container.decodeIfPresent(Double.self, forKey: .duration)
        elapsedSeconds = try container.decodeIfPresent(Double.self, forKey: .elapsedSeconds) ?? 0
        publishedDate = try container.decodeIfPresent(Date.self, forKey: .publishedDate)
        watched = try container.decodeIfPresent(Bool.self, forKey: .watched) ?? false
        videoDescription = try container.decodeIfPresent(String.self, forKey: .videoDescription)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: SendableVideoCodingKeys.self)

        try container.encodeIfPresent(persistendId, forKey: .persistendId)
        try container.encode(youtubeId, forKey: .youtubeId)
        try container.encode(title, forKey: .title)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(thumbnailUrl, forKey: .thumbnailUrl)
        try container.encodeIfPresent(youtubeChannelId, forKey: .youtubeChannelId)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(elapsedSeconds, forKey: .elapsedSeconds)
        try container.encodeIfPresent(publishedDate, forKey: .publishedDate)
        try container.encode(watched, forKey: .watched)
        try container.encodeIfPresent(videoDescription, forKey: .videoDescription)
    }
}

// MARK: - SendableVideoCodingKeys
enum SendableVideoCodingKeys: String, CodingKey {
    case persistendId
    case youtubeId
    case title
    case url
    case thumbnailUrl
    case youtubeChannelId
    case duration
    case elapsedSeconds
    case publishedDate
    case watched
    case videoDescription
}
