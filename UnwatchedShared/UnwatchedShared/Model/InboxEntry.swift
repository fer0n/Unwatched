//
//  InboxEntry.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model
public final class InboxEntry: CustomStringConvertible, Exportable, HasVideo {
    public typealias ExportType = SendableInboxEntry

    public var video: Video? {
        didSet {
            date = video?.publishedDate
        }
    }
    // workaround: sorting via optional relationship "video.publishedDate" lead to crash
    public var date: Date?

    public init(_ video: Video?, _ videoDate: Date? = nil) {
        self.video = video
        self.date = video?.publishedDate
    }

    public var description: String {
        return "InboxEntry: \(video?.title ?? "no title")"
    }

    public var toExport: SendableInboxEntry? {
        if let videoId = video?.persistentModelID.hashValue {
            return SendableInboxEntry(videoId: videoId)
        }
        return nil
    }
}

public struct SendableInboxEntry: Codable, ModelConvertable {
    public typealias ModelType = InboxEntry
    public var videoId: Int

    public var toModel: InboxEntry {
        return InboxEntry(nil)
    }
}
