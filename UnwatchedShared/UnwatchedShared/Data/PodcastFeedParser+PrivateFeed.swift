//
//  PodcastFeedParser+PrivateFeed.swift
//  UnwatchedShared
//

import Foundation

extension PodcastFeedParser {
    // read from the raw data: a parse with an episode limit can stop before a trailing tag
    static func isPrivateFeed(_ data: Data) -> Bool {
        outsideItems(of: data).contains {
            String(bytes: $0, encoding: .utf8)?.contains(#/(?i)<itunes:block>\s*yes\s*</itunes:block>/#) == true
        }
    }

    private static func outsideItems(of data: Data) -> [Data] {
        let beforeItems = data.range(of: Data("<item".utf8)).map { data[..<$0.lowerBound] } ?? data
        let afterItems = data.range(of: Data("</item>".utf8), options: .backwards).map { data[$0.upperBound...] }
        return [beforeItems, afterItems ?? Data()]
    }
}
