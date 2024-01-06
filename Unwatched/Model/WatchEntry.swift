//
//  WatchEntry.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model
final class WatchEntry: CustomStringConvertible {
    var video: Video
    var date: Date

    init(video: Video, date: Date = .now) {
        self.video = video
        self.date = date
    }

    var description: String {
        return "watched: \(video.title), \(date.formatted)"
    }
}
