//
//  QueueEntry.swift
//  Unwatched
//

import Foundation
import SwiftData

public protocol QueueEntryData {
    var order: Int { get }
}

@Model
public final class QueueEntry: QueueEntryData, CustomStringConvertible, Exportable, HasVideo {
    public typealias ExportType = SendableQueueEntry

    public var video: Video?
    public var order: Int = Int.max

    // workaround: since iOS 18, connection to video is sometimes lost, somehow related to sync.
    // This is used to repair that connection.
    public var youtubeId: String?

    public init(video: Video?, order: Int) {
        self.youtubeId = video?.youtubeId
        self.video = video
        self.order = order
    }

    /// Use instead of `video.queueEntry`, which traps once another context deletes the entry.
    public static func descriptor(for videoId: PersistentIdentifier) -> FetchDescriptor<QueueEntry> {
        var descriptor = FetchDescriptor<QueueEntry>(predicate: #Predicate { $0.video?.persistentModelID == videoId })
        descriptor.fetchLimit = 1
        return descriptor
    }

    public var description: String {
        return "\(video?.title ?? "not found") at (\(order))"
    }

    public var toExport: SendableQueueEntry? {
        if let video = video {
            return SendableQueueEntry(
                videoId: video.persistentModelID.hashValue,
                order: order
            )
        }
        return nil
    }
}

public struct SendableQueueEntry: QueueEntryData, Sendable, Codable, ModelConvertable, Hashable {
    public typealias ModelType = QueueEntry

    public var videoId: Int
    public var order: Int

    public var toModel: QueueEntry {
        QueueEntry(video: nil, order: order)
    }
}

public protocol ModelConvertable where ModelType: PersistentModel & HasVideo {
    associatedtype ModelType

    var toModel: ModelType { get }
    var videoId: Int { get set }
}

public protocol HasVideo {
    var video: Video? { get set }
    var youtubeId: String? { get }
}
