//
//  WatchEntry.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model
final class WatchEntry: CustomStringConvertible, Exportable, HasVideo {
    typealias ExportType = SendableWatchEntry

    var video: Video?
    var date: Date?

    init(video: Video?, date: Date? = .now) {
        self.video = video
        self.date = date
    }

    var description: String {
        return "watched: \(video?.title ?? ""), \(date?.formatted ?? "")"
    }

    var toExport: SendableWatchEntry? {
        if let videoId = video?.persistentModelID.hashValue {
            return SendableWatchEntry(videoId: videoId, date: date)
        }
        return nil
    }
}

struct SendableWatchEntry: Codable, ModelConvertable {
    typealias ModelType = WatchEntry

    var videoId: Int
    var date: Date?

    var toModel: WatchEntry {
        return WatchEntry(video: nil, date: date)
    }
}
