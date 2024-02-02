import Foundation
import SwiftData

@Model
final class Chapter {
    var title: String = ""
    var startTime: Double = 0
    var endTime: Double?
    var video: Video?
    var duration: Double?
    var isActive = true

    init(title: String, time: Double, duration: Double? = nil, endTime: Double? = nil) {
        self.title = title
        self.startTime = time
        self.duration = duration
        self.endTime = endTime
    }

    static func getDummy() -> Chapter {
        return Chapter(title: "My Chapter", time: 0, duration: 20)
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
