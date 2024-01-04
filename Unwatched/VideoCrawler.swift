//
//  VideoCrawler.swift
//  Unwatched
//

import Foundation

class VideoCrawler {
    static func loadVideosFromRSS(feedUrl: String) async throws -> [Video] {
        guard let url = URL(string: feedUrl) else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        let parser = XMLParser(data: data)
        let rssParserDelegate = RSSParserDelegate()
        parser.delegate = rssParserDelegate

        guard parser.parse() else {
            throw NSError(domain: "com.example", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse XML"])
        }

        return rssParserDelegate.videos
    }
}
