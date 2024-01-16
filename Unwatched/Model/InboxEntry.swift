//
//  InboxEntry.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model
final class InboxEntry: CustomStringConvertible {
    var video: Video?

    init(video: Video) {
        self.video = video
    }

    var description: String {
        return "InboxEntry: \(video?.title ?? "no title")"
    }
}
