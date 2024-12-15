//
//  InboxEntry.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model
public final class InboxEntry: CustomStringConvertible, Exportable, HasVideo {
    public typealias ExportType = SendableInboxEntry

    public var video: Video?
    
    // workaround: sorting via optional relationship "video.publishedDate" lead to crash
    // currently inactive, seems to be not necessary anymore
    public var date: Date?

    public init(_ video: Video?) {
        self.video = video
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
