//
//  PodcastSearchService.swift
//  UnwatchedShared
//

import Foundation
import OSLog

/// Podcast directory search, backed by the public iTunes Search API (no key, no quota sign-up).
public enum PodcastSearchService {
    private static let searchUrl = "https://itunes.apple.com/search"
    private static let lookupUrl = "https://itunes.apple.com/lookup"

    public static func search(_ term: String, limit: Int = 25) async throws -> [SendableSubscription] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var components = URLComponents(string: searchUrl)
        components?.queryItems = [
            URLQueryItem(name: "media", value: "podcast"),
            URLQueryItem(name: "entity", value: "podcast"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "term", value: trimmed)
        ]
        guard let url = components?.url else {
            throw SubscriptionError.notSupported
        }
        return try await fetchResults(url)
    }

    /// Resolves an Apple Podcasts share link (`podcasts.apple.com/…/id123`) to its feed.
    public static func lookup(collectionId: String) async throws -> SendableSubscription? {
        var components = URLComponents(string: lookupUrl)
        components?.queryItems = [URLQueryItem(name: "id", value: collectionId)]
        guard let url = components?.url else { return nil }
        return try await fetchResults(url).first
    }

    /// The show id in an Apple Podcasts show or episode link.
    public static func collectionId(from url: URL) -> String? {
        guard let host = url.host()?.lowercased(),
              host == "podcasts.apple.com" || host == "itunes.apple.com" else {
            return nil
        }
        let last = url.lastPathComponent
        guard last.hasPrefix("id") else { return nil }
        let id = last.dropFirst(2)
        return !id.isEmpty && id.allSatisfy(\.isNumber) ? String(id) : nil
    }

    /// The directory answers loosely — a one-word query comes back with shows that merely
    /// mention it. Keeps the ones whose title or author actually reflects the query.
    public static func isGoodMatch(_ sub: SendableSubscription, query: String) -> Bool {
        let query = query.folded
        guard !query.isEmpty else { return true }
        let title = sub.title.folded
        let author = (sub.author ?? "").folded
        if title.contains(query) || author.contains(query) {
            return true
        }
        let words = query
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .filter { $0.count > 2 }
        guard !words.isEmpty else { return false }
        let matched = words.filter { title.contains($0) || author.contains($0) }.count
        return matched * 2 >= words.count
    }

    private static func fetchResults(_ url: URL) async throws -> [SendableSubscription] {
        let (data, response) = try await URLSession.app.data(from: url)
        guard response.isSuccessfulHttp else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        // the directory lists a show once per storefront it's in, and they share a feed: searching "mkbhd" came back
        // with the same podcast twice
        var seen = Set<URL>()
        return decoded.results.compactMap(\.subscription).filter { show in
            guard let link = show.link else { return true }
            return seen.insert(link).inserted
        }
    }

    private struct SearchResponse: Decodable {
        let results: [Result]

        struct Result: Decodable {
            let collectionName: String?
            let trackName: String?
            let artistName: String?
            let feedUrl: String?
            let artworkUrl600: String?
            let artworkUrl100: String?
            let releaseDate: String?

            var subscription: SendableSubscription? {
                guard let feedUrl, let link = URL(string: feedUrl),
                      let title = collectionName ?? trackName else {
                    return nil
                }
                return SendableSubscription(
                    link: PodcastService.secureUrl(link),
                    title: title,
                    author: artistName == title ? nil : artistName,
                    isPodcast: true,
                    mostRecentVideoDate: releaseDate.flatMap { try? Date($0, strategy: .iso8601) },
                    thumbnailUrl: PodcastService.secureUrl(string: artworkUrl600 ?? artworkUrl100)
                )
            }
        }
    }
}
