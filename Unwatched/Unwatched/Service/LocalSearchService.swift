//
//  LocalSearchService.swift
//  Unwatched
//

import Foundation
import SwiftData
import UnwatchedShared

/// The stored data the Search tab found for a query, one list per source.
struct LocalSearchResults: Sendable {
    var subscriptions = [SendableSubscription]()
    var bookmarks = [SendableVideo]()
    var videos = [SendableVideo]()

    var isEmpty: Bool {
        subscriptions.isEmpty && bookmarks.isEmpty && videos.isEmpty
    }
}

/// Searches what's already in the app (subscriptions, bookmarks, the rest of the library)
/// so the Search tab can show local hits above the YouTube results.
///
/// A SwiftData predicate can't express "contains every word, in any order", so candidates
/// are narrowed with a single `localizedStandardContains` on the query's longest word and
/// the remaining words are matched and scored in memory. Only clear matches survive: every
/// word has to appear somewhere in the title (or the channel name, for videos).
enum LocalSearchService {
    /// Below this, matches are too noisy to be useful.
    static let minQueryLength = 2

    private static let maxSubscriptions = 3
    private static let maxVideos = 5
    /// How many rows a fetch pulls in before scoring picks the best ones.
    private static let candidateLimit = 100

    static func search(query: String, sources: Set<SearchSource>) async -> LocalSearchResults {
        let query = query.folded
        let tokens = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard query.count >= minQueryLength,
              let longestToken = tokens.max(by: { $0.count < $1.count }) else {
            return LocalSearchResults()
        }

        var results = LocalSearchResults()

        if sources.contains(.subscriptions) {
            results.subscriptions = Array(
                await subscriptions(longestToken, query, tokens).prefix(maxSubscriptions)
            )
        }
        if sources.contains(.bookmarks) {
            results.bookmarks = Array(
                await videos(longestToken, query, tokens, bookmarkedOnly: true).prefix(maxVideos)
            )
        }
        if sources.contains(.library) {
            // Bookmarks have their own section — don't repeat them here when it's shown.
            let alreadyShown = Set(results.bookmarks.map(\.youtubeId))
            results.videos = Array(
                await videos(longestToken, query, tokens, bookmarkedOnly: false)
                    .filter { !alreadyShown.contains($0.youtubeId) }
                    .prefix(maxVideos)
            )
        }

        return results
    }

    private static func subscriptions(
        _ fetchToken: String,
        _ query: String,
        _ tokens: [String]
    ) async -> [SendableSubscription] {
        let subs = await SubscriptionService.getActiveSubscriptions(
            fetchToken,
            [SortDescriptor<Subscription>(\.mostRecentVideoDate, order: .reverse)]
        )
        return rank(subs, query, tokens) {
            ($0.displayTitle, $0.youtubeUserName)
        }
    }

    private static func videos(
        _ fetchToken: String,
        _ query: String,
        _ tokens: [String],
        bookmarkedOnly: Bool
    ) async -> [SendableVideo] {
        let filter: Predicate<Video> = bookmarkedOnly
            ? #Predicate<Video> {
                $0.bookmarkedDate != nil && $0.title.localizedStandardContains(fetchToken)
            }
            : #Predicate<Video> {
                $0.title.localizedStandardContains(fetchToken)
            }
        let sort = bookmarkedOnly
            ? [SortDescriptor<Video>(\.bookmarkedDate, order: .reverse)]
            : [SortDescriptor<Video>(\.publishedDate, order: .reverse)]

        let videos = await VideoService.getSendableVideos(filter, nil, sort, 0, candidateLimit)
        return rank(videos, query, tokens) {
            ($0.title, $0.subscription?.displayTitle ?? $0.feedTitle)
        }
    }

    private struct Ranked<Item> {
        let score: Int
        /// Position in the fetch, used as the tiebreaker between equal scores.
        let index: Int
        let item: Item
    }

    /// Drops everything that doesn't match all query words and orders the rest by match
    /// quality, keeping the fetch order (most recent first) as the tiebreaker.
    private static func rank<Item>(
        _ items: [Item],
        _ query: String,
        _ tokens: [String],
        text: (Item) -> (title: String, subtitle: String?)
    ) -> [Item] {
        items.enumerated()
            .compactMap { index, item -> Ranked<Item>? in
                let (title, subtitle) = text(item)
                guard let score = score(title, subtitle, query, tokens) else { return nil }
                return Ranked(score: score, index: index, item: item)
            }
            .sorted { $0.score == $1.score ? $0.index < $1.index : $0.score > $1.score }
            .map(\.item)
    }

    /// True when every word of `query` appears in `title` — the same bar `search` uses
    /// for subscriptions/videos, reused so a channel mined from a YouTube video result
    /// (see `SearchVM+Local.youtubeChannelResults`) only surfaces on a genuine match.
    static func matchesQuery(_ title: String, query: String) -> Bool {
        let query = query.folded
        let tokens = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard query.count >= minQueryLength, !tokens.isEmpty else { return false }
        return score(title, nil, query, tokens) != nil
    }

    /// `nil` when not every query word is present, otherwise higher is a better match:
    /// the full query beats scattered words, and the title beats the channel name.
    private static func score(
        _ title: String,
        _ subtitle: String?,
        _ query: String,
        _ tokens: [String]
    ) -> Int? {
        let title = title.folded
        let haystack = [title, subtitle?.folded].compactMap { $0 }.joined(separator: " ")
        guard tokens.allSatisfy({ haystack.contains($0) }) else { return nil }

        var score = 0
        if title.hasPrefix(query) {
            score += 8
        } else if title.contains(query) {
            score += 4
        } else if haystack.contains(query) {
            score += 2
        }
        score += tokens.filter { title.contains($0) }.count
        return score
    }
}

private extension String {
    /// Lowercased and accent-stripped so matching ignores case and diacritics.
    var folded: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
