//
//  Tag+Defaults.swift
//  Unwatched
//

import Foundation
import UnwatchedShared

extension Tag {
    static func videosTag(order: Int) -> Tag {
        Tag(
            name: String(localized: "defaultTagVideos"),
            order: order,
            symbol: "rectangle.stack.fill",
            mode: .untagged
        )
    }

    static func podcastsTag(order: Int) -> Tag {
        Tag(
            name: String(localized: "defaultTagPodcasts"),
            order: order,
            symbol: "headphones",
            mode: .include,
            podcasts: .all,
            suggestVideos: true
        )
    }

    /// Skips `Int.max`, the model's default, which a restored tag can still carry.
    static func nextOrder(after tags: [Tag]) -> Int {
        let highest = tags.map(\.order).filter { $0 != Int.max }.max() ?? -1
        return min(highest, Int.max - 1) + 1
    }
}
