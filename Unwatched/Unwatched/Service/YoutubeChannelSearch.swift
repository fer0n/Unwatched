//
//  YoutubeChannelSearch.swift
//  Unwatched
//

import Foundation
import OSLog
import UnwatchedShared

struct YoutubeChannelSearchResult: Identifiable, Hashable, Sendable {
    var channelId: String
    var title: String
    /// The `@handle`, as shown on the search page
    var userName: String?
    /// Human readable subscriber count, e.g. "25.5M subscribers"
    var subscriberCount: String?
    var thumbnailUrl: URL?

    var id: String { channelId }
}

/// Channel search backed by YouTube's search results page.
///
/// The Data API's `search` endpoint costs 100 quota units per request, which the shared API key
/// can't sustain for type-ahead search; the results page is free and carries the same channel data.
enum YoutubeChannelSearch {
    /// `sp` filters the search to channels only; without it the page is mostly video results
    private static let channelsOnlyFilter = "EgIQAg%3D%3D"

    /// Sent so the request isn't answered with the consent interstitial instead of results
    private static let consentCookie = "SOCS=CAI;"

    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        + "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

    static func search(_ query: String) async throws -> [YoutubeChannelSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              let url = URL(
                string: "https://www.youtube.com/results?search_query=\(encoded)"
                    + "&sp=\(channelsOnlyFilter)&hl=en"
              ) else {
            throw SubscriptionError.notAnUrl(trimmed)
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue(consentCookie, forHTTPHeaderField: "Cookie")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
            Log.warning("channelSearch: response wasn't utf8")
            return []
        }
        return parse(html)
    }

    static func parse(_ html: String) -> [YoutubeChannelSearchResult] {
        guard let json = extractYtInitialData(html),
              let root = try? JSONSerialization.jsonObject(with: Data(json.utf8)) else {
            Log.warning("channelSearch: couldn't extract ytInitialData")
            return []
        }

        var renderers = [[String: Any]]()
        collectChannelRenderers(root, into: &renderers)

        var seen = Set<String>()
        return renderers.compactMap { renderer -> YoutubeChannelSearchResult? in
            guard let channelId = renderer["channelId"] as? String,
                  let title = simpleText(renderer["title"]),
                  seen.insert(channelId).inserted else {
                return nil
            }
            // YouTube puts handle and subscriber count in either field, so they're told apart
            // by content rather than by key
            let texts = [simpleText(renderer["subscriberCountText"]), simpleText(renderer["videoCountText"])]
                .compactMap { $0 }
            return YoutubeChannelSearchResult(
                channelId: channelId,
                title: title,
                userName: texts.first { $0.hasPrefix("@") }?.dropFirst().description,
                subscriberCount: texts.first { !$0.hasPrefix("@") },
                thumbnailUrl: thumbnailUrl(renderer["thumbnail"])
            )
        }
    }

    /// Returns the `var ytInitialData = {…}` object literal by scanning for its matching closing brace.
    private static func extractYtInitialData(_ html: String) -> String? {
        guard let marker = html.range(of: "ytInitialData"),
              let start = html[marker.upperBound...].firstIndex(of: "{") else {
            return nil
        }

        var depth = 0
        var scanner = StringLiteralScanner()

        for index in html[start...].indices {
            let char = html[index]
            guard scanner.isStructural(char) else {
                continue
            }
            if char == "{" {
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0 {
                    return String(html[start...index])
                }
            }
        }
        return nil
    }

    /// Tracks whether the scan sits inside a JSON string literal, so a quoted brace can't throw
    /// the nesting depth off
    private struct StringLiteralScanner {
        private var inString = false
        private var isEscaped = false

        /// Returns true when the character is JSON structure rather than string content
        mutating func isStructural(_ char: Character) -> Bool {
            if isEscaped {
                isEscaped = false
                return false
            }
            if inString {
                if char == "\\" {
                    isEscaped = true
                } else if char == "\"" {
                    inString = false
                }
                return false
            }
            if char == "\"" {
                inString = true
                return false
            }
            return true
        }
    }

    private static func collectChannelRenderers(_ value: Any, into result: inout [[String: Any]]) {
        if let dict = value as? [String: Any] {
            if let renderer = dict["channelRenderer"] as? [String: Any] {
                result.append(renderer)
            }
            for nested in dict.values {
                collectChannelRenderers(nested, into: &result)
            }
        } else if let array = value as? [Any] {
            for nested in array {
                collectChannelRenderers(nested, into: &result)
            }
        }
    }

    private static func simpleText(_ value: Any?) -> String? {
        guard let dict = value as? [String: Any] else {
            return nil
        }
        if let text = dict["simpleText"] as? String, !text.isEmpty {
            return text
        }
        guard let runs = dict["runs"] as? [[String: Any]] else {
            return nil
        }
        let text = runs.compactMap { $0["text"] as? String }.joined()
        return text.isEmpty ? nil : text
    }

    private static func thumbnailUrl(_ value: Any?) -> URL? {
        guard let dict = value as? [String: Any],
              let thumbnails = dict["thumbnails"] as? [[String: Any]],
              let best = thumbnails.last,
              var urlString = best["url"] as? String else {
            return nil
        }
        // YouTube returns protocol relative urls here
        if urlString.hasPrefix("//") {
            urlString = "https:" + urlString
        }
        return URL(string: urlString)
    }
}
