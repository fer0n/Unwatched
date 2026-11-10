//
//  PodcastFeedPrefix.swift
//  UnwatchedShared
//

import CryptoKit
import Foundation

/// Counts the items of a feed's byte stream that the parser would keep as episodes.
public struct PodcastEpisodeEndCounter {
    private var enclosure = ByteMatcher("<enclosure")
    private var itemEnd = ByteMatcher("</item>")
    private var hasEnclosure = false
    private var count = 0

    public init() {}

    public mutating func consume(_ byte: UInt8) -> Int {
        if enclosure.completes(with: byte) {
            hasEnclosure = true
        }
        if itemEnd.completes(with: byte) {
            if hasEnclosure { count += 1 }
            hasEnclosure = false
        }
        return count
    }
}

/// Only for patterns whose first byte doesn't repeat within them.
struct ByteMatcher {
    private let pattern: [UInt8]
    private var matched = 0

    init(_ pattern: String) {
        self.pattern = Array(pattern.utf8)
    }

    mutating func completes(with byte: UInt8) -> Bool {
        if byte == pattern[matched] {
            matched += 1
            if matched == pattern.count {
                matched = 0
                return true
            }
        } else {
            matched = byte == pattern[0] ? 1 : 0
        }
        return false
    }
}

/// Remembers what a feed's full document said, for parsing one that was cut off.
enum PodcastFeedPrivacy {
    private static let key = "podcastFeedPrivacy"

    static func isPrivate(_ feedUrl: URL) -> Bool? {
        stored[id(feedUrl)]
    }

    static func remember(_ isPrivate: Bool, for feedUrl: URL) {
        var all = stored
        all[id(feedUrl)] = isPrivate
        UserDefaults.standard.set(all, forKey: key)
    }

    private static var stored: [String: Bool] {
        UserDefaults.standard.dictionary(forKey: key) as? [String: Bool] ?? [:]
    }

    /// Hashed: private feed URLs carry the member's token.
    private static func id(_ feedUrl: URL) -> String {
        SHA256.hash(data: Data(feedUrl.absoluteString.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
    }
}
