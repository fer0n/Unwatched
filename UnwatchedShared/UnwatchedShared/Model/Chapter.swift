import Foundation
import SwiftData

@Model
public final class Chapter: ChapterData {

    public var title: String?
    public var startTime: Double = 0
    public var endTime: Double?
    public var video: Video?
    public var mergedChapterVideo: Video?
    public var duration: Double?
    public var isActive = true
    public var category: ChapterCategory?

    public init(
        title: String?,
        time: Double,
        duration: Double? = nil,
        endTime: Double? = nil,
        isActive: Bool? = nil,
        category: ChapterCategory? = nil
    ) {
        self.title = title
        self.startTime = time
        self.duration = duration
        self.endTime = endTime
        self.isActive = isActive ?? true
        self.category = category
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
            isActive: isActive
        )
    }

}

public struct SendableChapter: ChapterData, Sendable, CustomStringConvertible, Hashable {
    public var title: String?
    public var startTime: Double
    public var endTime: Double?
    public var duration: Double?
    public var isActive: Bool = true
    public var category: ChapterCategory?

    public var description: String {
        "\(startTime)-\(endTime ?? -1): \(title ?? category?.description ?? "-")"
    }

    public var getChapter: Chapter {
        Chapter(
            title: title,
            time: startTime,
            duration: duration,
            endTime: endTime,
            isActive: isActive,
            category: category
        )
    }

    public init(
        title: String? = nil,
        startTime: Double,
        endTime: Double? = nil,
        duration: Double? = nil,
        isActive: Bool? = nil,
        category: ChapterCategory? = nil
    ) {
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.isActive = isActive ?? true
        self.category = category
    }
}
