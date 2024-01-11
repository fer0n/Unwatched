import Foundation
import SwiftData

@Model
final class Chapter {
    var title: String
    var startTime: Double
    var endTime: Double?
    var video: Video?
    var duration: Double?
    var isActive = true

    init(title: String, time: Double, duration: Double?, endTime: Double? = nil) {
        self.title = title
        self.startTime = time
        self.duration = duration
        self.endTime = endTime
    }
}

struct SendableChapter: Sendable, CustomStringConvertible {
    var title: String
    var startTime: Double
    var endTime: Double?
    var duration: Double?

    var description: String {
        "\(startTime): \(title)"
    }

    var getChapter: Chapter {
        Chapter(title: title, time: startTime, duration: duration, endTime: endTime)
    }
}
