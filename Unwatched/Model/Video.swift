//
//  Video.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model
final class Video: CustomStringConvertible {
    @Attribute(.unique) var youtubeId: String
    var title: String
    var url: URL
    var thumbnailUrl: URL?
    var publishedDate: Date?
    var duration: Double?

    var status: VideoStatus?
    var watched = false
    var subscription: Subscription?
    var youtubeChannelId: String?
    private var _feedTitle: String?

    var feedTitle: String? {
        get {
            subscription?.title ?? _feedTitle
        }
        set {
            _feedTitle = newValue
        }
    }

    var remainingTime: Double? {
        guard let duration = duration else { return nil }
        return duration - elapsedSeconds
    }

    var elapsedSeconds: Double = 0

    init(title: String,
         url: URL,
         youtubeId: String,
         thumbnailUrl: URL? = nil,
         publishedDate: Date? = nil,
         youtubeChannelId: String? = nil,
         feedTitle: String? = nil,
         duration: Double? = nil) {
        self.title = title
        self.url = url
        self.youtubeId = youtubeId
        self.youtubeChannelId = youtubeChannelId
        self.thumbnailUrl = thumbnailUrl
        self.publishedDate = publishedDate
        self._feedTitle = feedTitle
        self.duration = duration
    }

    // specify what is being printed when you print an instance of this class directly
    var description: String {
        return "Video: \(title) (\(url))"
    }

    // Preview data
    static let dummy = Video(
        title: "Virtual Reality OasisResident Evil 4 Remake Is 10x BETTER In VR!",
        url: URL(string: "https://www.youtube.com/watch?v=_7vP9vsnYPc")!,
        youtubeId: "_7vP9vsnYPc",
        thumbnailUrl: URL(string: "https://i4.ytimg.com/vi/_7vP9vsnYPc/hqdefault.jpg")!,
        publishedDate: Date())
}

struct SendableVideo: Sendable {
    var youtubeId: String
    var title: String
    var url: URL
    var thumbnailUrl: URL?
    var youtubeChannelId: String?
    var feedTitle: String?
    var duration: Double?

    var publishedDate: Date?
    var status: VideoStatus?
    var watched = false

    func getVideo(
        title: String? = nil,
        url: URL? = nil,
        youtubeId: String? = nil,
        thumbnailUrl: URL? = nil,
        publishedDate: Date? = nil,
        youtubeChannelId: String? = nil,
        feedTitle: String? = nil,
        duration: TimeInterval? = nil
    ) -> Video {
        Video(
            title: title ?? self.title,
            url: url ?? self.url,
            youtubeId: youtubeId ?? self.youtubeId,
            thumbnailUrl: thumbnailUrl ?? self.thumbnailUrl,
            publishedDate: publishedDate ?? self.publishedDate,
            youtubeChannelId: youtubeChannelId ?? self.youtubeChannelId,
            feedTitle: feedTitle ?? self.feedTitle,
            duration: duration ?? self.duration
        )
    }
}
