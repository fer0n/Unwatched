//
//  OnboardingViewModel+Search.swift
//  Unwatched
//

import Foundation
import OSLog
import UnwatchedShared

extension OnboardingViewModel {
    private static let searchDebounce: Duration = .milliseconds(400)
    /// Podcasts are a supplement to channel search, not its focus, so their share of the list is capped
    private static let podcastResultLimit = 8

    /// Debounced so typing doesn't fire a request per keystroke. `isSearching` flips right away,
    /// hiding the previous query's results for the whole debounce + fetch.
    func searchDebounced() async {
        guard !searchText.isEmpty else {
            await search()
            return
        }
        guard searchText != loadedQuery else {
            return
        }
        isSearching = true
        try? await Task.sleep(for: Self.searchDebounce)
        guard !Task.isCancelled else { return }
        await search()
    }

    /// Runs the current query again after it failed
    func retrySearch() async {
        loadedQuery = nil
        await search()
    }

    private func search() async {
        let raw = searchText
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            searchState = .idle
            isSearching = false
            loadedQuery = nil
            return
        }
        isSearching = true
        searchState = .idle
        didSearch = true

        async let channelSearch = Self.searchChannels(query)
        async let podcastSearch = Self.searchPodcasts(query)
        let (channels, podcasts) = await (channelSearch, podcastSearch)
        guard !Task.isCancelled else { return }

        if channels == nil, podcasts == nil {
            searchResults = []
            searchState = .failed
        } else {
            searchResults = Self.merge(channels ?? [], podcasts ?? [], query: query)
            searchState = searchResults.isEmpty ? .noResults : .idle
        }
        isSearching = false
        loadedQuery = raw
    }

    /// `nil` on failure, so one source being down doesn't hide the other's results — only a
    /// failure on both sides reads as `.failed`
    private static func searchChannels(_ query: String) async -> [YoutubeChannelSearchResult]? {
        do {
            return try await YoutubeChannelSearch.search(query)
        } catch {
            Log.error("channelSearch failed: \(error)")
            Signal.error("onboardingChannelSearchFailed")
            return nil
        }
    }

    private static func searchPodcasts(_ query: String) async -> [SendableSubscription]? {
        do {
            // filtered before the cap, so loose directory matches don't crowd out the good ones
            let found = try await PodcastSearchService.search(query)
                .filter { PodcastSearchService.isGoodMatch($0, query: query) }
            return Array(found.prefix(podcastResultLimit))
        } catch {
            Log.error("podcastSearch failed: \(error)")
            return nil
        }
    }

    /// Each source ranks its own results, with no relevance score shared between them; title
    /// closeness to the query is the only common measure, and each source's own order breaks ties.
    private static func merge(
        _ channels: [YoutubeChannelSearchResult],
        _ podcasts: [SendableSubscription],
        query: String
    ) -> [OnboardingSearchResult] {
        let results = channels.map(OnboardingSearchResult.channel)
            + podcasts.map(OnboardingSearchResult.podcast)
        return Dictionary(grouping: results) { matchRank($0.title, query) }
            .sorted { $0.key > $1.key }
            .flatMap(\.value)
    }

    private static func matchRank(_ title: String, _ query: String) -> Int {
        let title = title.folded
        let query = query.folded
        if title == query { return 3 }
        if title.hasPrefix(query) { return 2 }
        if title.contains(query) { return 1 }
        return 0
    }
}
