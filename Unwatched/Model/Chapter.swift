import Foundation
import SwiftData

@Model
final class Chapter {

    var title: String?
    var startTime: Double = 0
    var endTime: Double?
    var video: Video?
    var mergedChapterVideo: Video?
    var duration: Double?
    var isActive = true
    var category: ChapterCategory?

    var titleText: String? {
        title ?? category?.translated
    }

    var titleTextForced: String {
        titleText ?? video?.title ?? mergedChapterVideo?.title ?? "-"
    }

    init(
        title: String?,
        time: Double,
        duration: Double? = nil,
        endTime: Double? = nil,
        category: ChapterCategory? = nil
    ) {
        self.title = title
        self.startTime = time
        self.duration = duration
        self.endTime = endTime
        self.category = category
    }

    static func getDummy() -> Chapter {
        return Chapter(title: "My Chapter", time: 0, duration: 20)
    }

    var toExport: SendableChapter {
        SendableChapter(
            title: title,
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            isActive: isActive
        )
    }

}

struct SendableChapter: Sendable, CustomStringConvertible {
    var title: String?
    var startTime: Double
    var endTime: Double?
    var duration: Double?
    var isActive: Bool?
    var category: ChapterCategory?

    var description: String {
        "\(startTime)-\(endTime ?? -1): \(title ?? category?.description ?? "-")"
    }

    var getChapter: Chapter {
        Chapter(title: title, time: startTime, duration: duration, endTime: endTime, category: category)
    }
}
