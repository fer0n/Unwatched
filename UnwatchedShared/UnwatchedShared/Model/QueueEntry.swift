//
//  QueueEntry.swift
//  Unwatched
//

import Foundation
import SwiftData


@Model
public final class QueueEntry: CustomStringConvertible, Exportable, HasVideo {
    public typealias ExportType = SendableQueueEntry

    public var video: Video?
    public var order: Int = Int.max

    public init(video: Video?, order: Int) {
        self.video = video
        self.order = order
    }

    public var description: String {
        return "\(video?.title ?? "not found") at (\(order))"
    }

    public var toExport: SendableQueueEntry? {
        if let video = video {
            return SendableQueueEntry(videoId: video.persistentModelID.hashValue, order: order)
        }
        return nil
    }
}

public struct SendableQueueEntry: Codable, ModelConvertable {
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
}
