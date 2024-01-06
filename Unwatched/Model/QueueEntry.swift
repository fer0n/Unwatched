//
//  QueueEntry.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model
final class QueueEntry: CustomStringConvertible {
    var video: Video
    var order: Int

    init(video: Video, order: Int) {
        self.video = video
        self.order = order
    }

    var description: String {
        return "\(video.title) at (\(order))"
    }
}
