//
//  SearchVM.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

/// Drives the Search tab: runs InnerTube searches, paginates, and exposes results
/// as `SendableVideo`s so they render in the standard `VideoListItem` rows.
@Observable
@MainActor
final class SearchVM {
    var query: String = ""
    var results: [SendableVideo] = []
    private(set) var suggestions: [String] = []
    private(set) var recentSearches: [String] = []
    private(set) var isSearching = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?
    /// The query that produced the current `results` (used to ignore stale responses).
    private(set) var activeQuery: String = ""

    /// Matches from data already stored in the app, shown above the YouTube results
    /// (see `SearchVM+Local`).
    var localResults = LocalSearchResults()
    var enabledSources = SearchSource.loadEnabled()

    var hasSearched: Bool { !activeQuery.isEmpty }

    var hasAnyResults: Bool { !results.isEmpty || !localResults.isEmpty }

    /// Upload-date filter for the search. Changing it re-runs the active search so
    /// results update immediately (mirrors YouTube's "Upload date" search filter).
    var uploadDate: SearchFilter.UploadDate {
        get { filter.uploadDate }
        set {
            guard filter.uploadDate != newValue else { return }
            filter.uploadDate = newValue
            rerunActiveSearch()
        }
    }

    var channelAvatarURLs: [String: URL] = [:]

    let api = InnerTubeAPI()
    private var filter = SearchFilter.default
    private var nextPageToken: String?
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored var localTask: Task<Void, Never>?
    @ObservationIgnored var avatarTask: Task<Void, Never>?
    @ObservationIgnored private var suggestionsTask: Task<Void, Never>?
    /// Prefix → suggestions cache, with an insertion-ordered key list for simple LRU eviction.
    @ObservationIgnored private var suggestionCache: [String: [String]] = [:]
    @ObservationIgnored private var suggestionCacheOrder: [String] = []

    private static let recentSearchesKey = "recentSearches"
    private static let maxRecentSearches = 20
    private static let maxSuggestions = 10
    private static let maxSuggestionCacheEntries = 100

    init() {
        loadRecentSearches()
    }

    func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recordRecentSearch(trimmed)

        searchTask?.cancel()
        errorMessage = nil
        activeQuery = trimmed

        suggestionsTask?.cancel()
        suggestions = []

        searchLocal()

        guard enabledSources.contains(.youtube) else {
            withAnimation {
                results = []
            }
            nextPageToken = nil
            isSearching = false
            isLoadingMore = false
            return
        }
        isSearching = true

        searchTask = Task {
            do {
                let page = try await api.search(query: trimmed, filter: filter)
                if Task.isCancelled { return }
                withAnimation {
                    results = page.videos.map(Self.sendable(from:))
                    nextPageToken = page.nextPageToken
                    isSearching = false
                }
                Signal.log("Search.Submitted", parameters: ["resultCount": Signal.bucket(results.count)])
                refreshAllStatuses()
                loadYoutubeChannelAvatarsIfNeeded()
            } catch is CancellationError {
                // superseded by a newer query — leave state to the newer task
            } catch {
                if Task.isCancelled { return }
                Log.error("search failed: \(error)")
                results = []
                nextPageToken = nil
                errorMessage = String(localized: "searchFailed")
                isSearching = false
            }
        }
    }

    /// Re-runs the search for the currently active query (e.g. after a filter change),
    /// leaving the search field text untouched.
    func rerunActiveSearch() {
        guard hasSearched else { return }
        query = activeQuery
        search()
    }

    /// Fetches the next page when the user scrolls near the end of the list. Triggers on
    /// any of the last few results rather than strictly the last one — `youtubeResults`
    /// may have dropped the tail as a duplicate of a local hit.
    func loadMoreIfNeeded(currentItem: SendableVideo) {
        guard let index = results.firstIndex(where: { $0.youtubeId == currentItem.youtubeId }),
              index >= results.count - 3 else { return }
        guard let token = nextPageToken, !isLoadingMore, !isSearching else { return }
        let queryAtStart = activeQuery
        isLoadingMore = true

        Task {
            do {
                let page = try await api.search(query: queryAtStart, continuationToken: token, filter: filter)
                if Task.isCancelled || queryAtStart != activeQuery { return }
                let existing = Set(results.map(\.youtubeId))
                let new = page.videos
                    .filter { !existing.contains($0.id) }
                    .map(Self.sendable(from:))
                withAnimation {
                    results.append(contentsOf: new)
                    nextPageToken = page.nextPageToken
                    isLoadingMore = false
                }
                refreshAllStatuses()
                loadYoutubeChannelAvatarsIfNeeded()
            } catch {
                Log.error("search loadMore failed: \(error)")
                isLoadingMore = false
            }
        }
    }

    // MARK: - Recent searches (persisted, newest-first, deduped)

    private func loadRecentSearches() {
        if let data = UserDefaults.standard.data(forKey: Self.recentSearchesKey),
           let list = try? JSONDecoder().decode([String].self, from: data) {
            recentSearches = list
        }
    }

    private func recordRecentSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recentSearches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > Self.maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(Self.maxRecentSearches))
        }
        persistRecentSearches()
    }

    func removeRecentSearch(_ query: String) {
        recentSearches.removeAll { $0 == query }
        persistRecentSearches()
    }

    func clearRecentSearches() {
        recentSearches = []
        persistRecentSearches()
    }

    private func persistRecentSearches() {
        let data = try? JSONEncoder().encode(recentSearches)
        UserDefaults.standard.set(data, forKey: Self.recentSearchesKey)
    }

    /// Fetches autocomplete suggestions for the current query (debounced). Skips when
    /// the query is empty or already matches the active search.
    ///
    /// An exact prefix we've fetched before is served instantly from cache. Otherwise we
    /// optimistically filter the closest cached prefix's suggestions for immediate feedback
    /// while the debounced network request fetches the real (refined) list.
    func updateSuggestions() {
        suggestionsTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            suggestions = []
            return
        }
        if let cached = suggestionCache[trimmed] {
            suggestions = cached
            return
        }
        // Show cached suggestions from the last-typed prefix, filtered to the new query, so
        // forward typing (e.g. "swif" → "swift") updates instantly instead of blanking.
        if let optimistic = optimisticSuggestions(for: trimmed) {
            suggestions = optimistic
        }
        suggestionsTask = Task {
            try? await Task.sleep(for: .milliseconds(120))
            if Task.isCancelled { return }
            let results = (try? await api.fetchSearchSuggestions(query: trimmed)) ?? []
            if Task.isCancelled || trimmed != query.trimmingCharacters(in: .whitespacesAndNewlines) {
                return
            }
            let limited = Array(results.prefix(Self.maxSuggestions))
            cacheSuggestions(limited, for: trimmed)
            suggestions = limited
        }
    }

    /// Filters the longest cached prefix of `query` down to suggestions that still match,
    /// giving instant (network-free) feedback while the real request is in flight.
    private func optimisticSuggestions(for query: String) -> [String]? {
        let lowerQuery = query.lowercased()
        let match = suggestionCacheOrder
            .filter { lowerQuery.hasPrefix($0.lowercased()) }
            .max(by: { $0.count < $1.count })
        guard let prefix = match, let cached = suggestionCache[prefix] else { return nil }
        let filtered = cached.filter { $0.lowercased().hasPrefix(lowerQuery) }
        return filtered.isEmpty ? nil : filtered
    }

    private func cacheSuggestions(_ suggestions: [String], for query: String) {
        if suggestionCacheOrder.count >= Self.maxSuggestionCacheEntries,
           let oldest = suggestionCacheOrder.first {
            suggestionCache.removeValue(forKey: oldest)
            suggestionCacheOrder.removeFirst()
        }
        suggestionCache[query] = suggestions
        suggestionCacheOrder.append(query)
    }

    func clear() {
        searchTask?.cancel()
        suggestionsTask?.cancel()
        localTask?.cancel()
        avatarTask?.cancel()
        localResults = LocalSearchResults()
        query = ""
        activeQuery = ""
        results = []
        suggestions = []
        nextPageToken = nil
        errorMessage = nil
        isSearching = false
        isLoadingMore = false
        channelAvatarURLs = [:]
    }

    // MARK: - Mapping

    nonisolated static func sendable(from video: ITVideo) -> SendableVideo {
        let channelTitle = video.channelTitle.isEmpty ? nil : video.channelTitle
        // Attach a lightweight subscription so the row shows the channel name.
        let subscription: SendableSubscription? = (channelTitle != nil || video.channelId != nil)
            ? SendableSubscription(
                title: channelTitle ?? "",
                youtubeChannelId: video.channelId
            )
            : nil
        return SendableVideo(
            youtubeId: video.id,
            title: video.title,
            url: URL(string: "https://www.youtube.com/watch?v=\(video.id)"),
            thumbnailUrl: video.thumbnailURL ?? video.highQualityThumbnailURL,
            youtubeChannelId: video.channelId,
            feedTitle: channelTitle,
            duration: video.duration,
            publishedDate: video.publishedAt,
            isYtShort: video.isShort,
            subscription: subscription,
            isNew: false
        )
    }
}
