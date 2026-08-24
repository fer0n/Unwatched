import Foundation
import SwiftData

@Model
public final class Chapter: ChapterData, CustomStringConvertible {

    public var title: String?
    public var startTime: Double = 0
    public var endTime: Double?
    public var video: Video?
    public var mergedChapterVideo: Video?
    public var duration: Double?
    public var isActive = true
    public var category: ChapterCategory?
    public var link: URL?
    public var imageUrl: URL?

    public var persistentId: PersistentIdentifier? {
        persistentModelID
    }

    public var videoId: String? {
        video?.youtubeId ?? mergedChapterVideo?.youtubeId
    }

    public init(
        title: String?,
        time: Double,
        duration: Double? = nil,
        endTime: Double? = nil,
        isActive: Bool? = nil,
        category: ChapterCategory? = nil,
        link: URL? = nil,
        imageUrl: URL? = nil
    ) {
        self.title = title
        self.startTime = time
        self.duration = duration
        self.endTime = endTime
        self.isActive = isActive ?? true
        self.category = category
        self.link = link
        self.imageUrl = imageUrl
    }

    public static func getDummy() -> Chapter {
        return Chapter(title: "My Chapter", time: 0, duration: 20)
    }

    public var toExport: SendableChapter {
        SendableChapter(
            title: title,
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            isActive: isActive,
            category: category,
            link: link,
            imageUrl: imageUrl,
            videoId: videoId,
            persistentId: persistentId
        )
    }

    public var description: String {
        "\(startTime)-\(endTime, default: "nil"): \(title ?? category?.description ?? "-")"
    }
}

public struct SendableChapter: ChapterData, Sendable, CustomStringConvertible, Hashable, Codable {
    /// `videoId` is the cache key and gets stamped back on read; `persistentId` refers to a row
    /// in a different store and would be meaningless once decoded.
    private enum CodingKeys: String, CodingKey {
        case title, startTime, endTime, duration, isActive, category, link, imageUrl
    }

    public var title: String?
    public var startTime: Double
    public var endTime: Double?
    public var duration: Double?
    public var isActive: Bool = true
    public var category: ChapterCategory?
    public var link: URL?

    /// Artwork for this chapter alone — a podcast's `podcast:chapters` `img`, a Podlove marker's `image`, or the
    /// picture in the episode file's own chapter frame.
    public var imageUrl: URL?

    public var videoId: String?
    public var persistentId: PersistentIdentifier?

    /// The generated chapter covering a subscription's skipped intro, see `ChapterService.applySkipIntro`.
    public var isIntro: Bool = false

    /// The counterpart at the end, see `ChapterService.applySkipOutro` and `Video.keepOutro`.
    public var isOutro: Bool = false

    public var description: String {
        "\(startTime)-\(endTime, default: "nil"): \(title ?? category?.description ?? "-")"
    }

    public var getChapter: Chapter {
        Chapter(
            title: title,
            time: startTime,
            duration: duration,
            endTime: endTime,
            isActive: isActive,
            category: category,
            link: link,
            imageUrl: imageUrl
        )
    }

    public init(
        _ startTime: Double,
        to endTime: Double? = nil,
        _ title: String? = nil,
        category: ChapterCategory? = nil,
        link: URL? = nil,
        imageUrl: URL? = nil
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.title = title
        self.category = category
        self.link = link
        self.imageUrl = imageUrl
    }

    public init(
        title: String? = nil,
        startTime: Double,
        endTime: Double? = nil,
        duration: Double? = nil,
        isActive: Bool? = nil,
        category: ChapterCategory? = nil,
        link: URL? = nil,
        imageUrl: URL? = nil,
        videoId: String? = nil,
        persistentId: PersistentIdentifier? = nil,
        isIntro: Bool = false,
        isOutro: Bool = false
    ) {
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.isActive = isActive ?? true
        self.category = category
        self.link = link
        self.imageUrl = imageUrl
        self.videoId = videoId
        self.persistentId = persistentId
        self.isIntro = isIntro
        self.isOutro = isOutro
    }
}
