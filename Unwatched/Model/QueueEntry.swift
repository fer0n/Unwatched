//
//  QueueEntry.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model
final class QueueEntry: CustomStringConvertible, Exportable, HasVideo {
    typealias ExportType = SendableQueueEntry

    var video: Video?
    var order: Int = Int.max

    init(video: Video?, order: Int) {
        self.video = video
        self.order = order
    }

    var description: String {
        return "\(video?.title ?? "not found") at (\(order))"
    }

    var toExport: SendableQueueEntry? {
        if let video = video {
            return SendableQueueEntry(videoId: video.persistentModelID.hashValue, order: order)
        }
        return nil
    }
}

struct SendableQueueEntry: Codable, ModelConvertable {
    typealias ModelType = QueueEntry

    var videoId: Int
    var order: Int

    var toModel: QueueEntry {
        QueueEntry(video: nil, order: order)
    }
}

protocol ModelConvertable where ModelType: PersistentModel & HasVideo {
    associatedtype ModelType

    var toModel: ModelType { get }
    var videoId: Int { get set }
}

protocol HasVideo {
    var video: Video? { get set }
}

// protocol Exportable {
//    associatedtype ExportType
//
//    var toExport: ExportType? { get }
// }
