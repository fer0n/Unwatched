//
//  ShareMarkers.swift
//  UnwatchedShared
//

import Foundation

/// `#u=ab12cd34&t=754` on a shared podcast url: which episode, and where to start.
public enum ShareMarkers {
    public static let episodeIdKey = "u"
    public static let legacyEpisodeIdKey = "unw"
    public static let startKey = "t"
    private static let keys: Set = [episodeIdKey, legacyEpisodeIdKey, startKey]

    /// Nil unless every fragment item is one of ours, so a page's own anchor is left alone.
    public static func markers(in url: URL) -> [String: Substring]? {
        guard let fragment = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment,
              !fragment.isEmpty else {
            return nil
        }
        var markers = [String: Substring]()
        for item in fragment.split(separator: "&") {
            let pair = item.split(separator: "=", maxSplits: 1)
            guard pair.count == 2, keys.contains(String(pair[0])), !pair[1].isEmpty else { return nil }
            markers[String(pair[0])] = pair[1]
        }
        return markers
    }

    public static func startTime(in url: URL) -> Double? {
        markers(in: url)?[startKey].flatMap { UInt($0) }.map(Double.init)
    }

    public static func adding(_ key: String, _ value: String, to url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.fragment == nil || markers(in: url) != nil else {
            return url
        }
        let marker = "\(key)=\(value)"
        components.fragment = components.fragment.map { "\($0)&\(marker)" } ?? marker
        return components.url ?? url
    }

    public static func removing(from url: URL) -> URL {
        guard markers(in: url) != nil,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.fragment = nil
        return components.url ?? url
    }
}
