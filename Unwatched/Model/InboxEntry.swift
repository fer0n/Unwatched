//
//  InboxEntry.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model
final class InboxEntry: CustomStringConvertible, Exportable, HasVideo {
    typealias ExportType = SendableInboxEntry

    var video: Video? {
        didSet {
            date = video?.publishedDate ?? .now
        }
    }
    // workaround: sorting via optional relationship "video.publishedDate" lead to crashh
    var date: Date?

    init(_ video: Video?, _ videoDate: Date? = nil) {
        self.video = video
        self.date = video?.publishedDate ?? .now
    }

    var description: String {
        return "InboxEntry: \(video?.title ?? "no title")"
    }

    var toExport: SendableInboxEntry? {
        if let videoId = video?.persistentModelID.hashValue {
            return SendableInboxEntry(videoId: videoId)
        }
        return nil
    }
}

struct SendableInboxEntry: Codable, ModelConvertable {
    typealias ModelType = InboxEntry
    var videoId: Int

    var toModel: InboxEntry {
        return InboxEntry(nil)
    }
}
