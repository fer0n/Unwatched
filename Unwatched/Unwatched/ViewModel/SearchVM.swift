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
    private(set) var results: [SendableVideo] = []
    private(set) var suggestions: [String] = []
    private(set) var recentSearches: [String] = []
    private(set) var isSearching = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?
    /// The query that produced the current `results` (used to ignore stale responses).
    private(set) var activeQuery: String = ""

    var hasSearched: Bool { !activeQuery.isEmpty }

    private let api = InnerTubeAPI()
    private var filter = SearchFilter.default
    private var nextPageToken: String?
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var suggestionsTask: Task<Void, Never>?

    private static let recentSearchesKey = "recentSearches"
    private static let maxRecentSearches = 20
    private static let maxResults = 10
    private static let maxSuggestions = 10

    init() {
        loadRecentSearches()
    }

    func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recordRecentSearch(trimmed)

        searchTask?.cancel()
        isSearching = true
        errorMessage = nil
        activeQuery = trimmed

        suggestionsTask?.cancel()
        suggestions = []

        searchTask = Task {
            do {
                let page = try await api.search(query: trimmed, filter: filter)
                if Task.isCancelled { return }
                withAnimation {
                    results = page.videos.prefix(Self.maxResults).map(Self.sendable(from:))
                    nextPageToken = page.nextPageToken
                    isSearching = false
                }
                refreshAllStatuses()
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

    /// Fetches the next page when the user scrolls near the end of the list.
    func loadMoreIfNeeded(currentItem: SendableVideo) {
        guard currentItem.youtubeId == results.last?.youtubeId else { return }
        guard results.count < Self.maxResults else { return }
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
                    .prefix(Self.maxResults - results.count)
                    .map(Self.sendable(from:))
                withAnimation {
                    results.append(contentsOf: new)
                    nextPageToken = page.nextPageToken
                    isLoadingMore = false
                }
                refreshAllStatuses()
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
    func updateSuggestions() {
        suggestionsTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != activeQuery else {
            suggestions = []
            return
        }
        suggestionsTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            if Task.isCancelled { return }
            let results = (try? await api.fetchSearchSuggestions(query: trimmed)) ?? []
            if Task.isCancelled || trimmed != query.trimmingCharacters(in: .whitespacesAndNewlines) {
                return
            }
            suggestions = Array(results.prefix(Self.maxSuggestions))
        }
    }

    /// Refreshes a single result's inbox/queue/watched status from the store after an
    /// action (e.g. adding to the queue). If the video has since been persisted, its
    /// `SendableVideo` is swapped for the stored one so `VideoListItem` shows the badge.
    func refreshStatus(for youtubeId: String) {
        guard let idx = results.firstIndex(where: { $0.youtubeId == youtubeId }) else { return }
        if let updated = Self.storedStatus(for: youtubeId) {
            withAnimation { results[idx] = updated }
        }
    }

    /// Overlays stored status onto all current results (e.g. items already in the
    /// queue/inbox, or after returning from playback).
    func refreshAllStatuses() {
        guard !results.isEmpty else { return }
        let stored = Self.storedStatuses(for: results.map(\.youtubeId))
        guard !stored.isEmpty else { return }
        var updated = results
        var didChange = false
        for index in updated.indices {
            if let match = stored[updated[index].youtubeId] {
                updated[index] = match
                didChange = true
            }
        }
        if didChange {
            withAnimation { results = updated }
        }
    }

    @MainActor private static func storedStatus(for youtubeId: String) -> SendableVideo? {
        let context = DataProvider.mainContext
        guard let video = VideoService.getVideo(for: youtubeId, modelContext: context) else {
            return nil
        }
        return video.toExportWithSubscription ?? video.toExport
    }

    /// Fetches stored status for many videos in a single query, keyed by `youtubeId`.
    @MainActor private static func storedStatuses(for youtubeIds: [String]) -> [String: SendableVideo] {
        let context = DataProvider.mainContext
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { youtubeIds.contains($0.youtubeId) })
        guard let videos = try? context.fetch(fetch) else { return [:] }
        return Dictionary(
            videos.compactMap { video -> (String, SendableVideo)? in
                guard let export = video.toExportWithSubscription ?? video.toExport else { return nil }
                return (video.youtubeId, export)
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func clear() {
        searchTask?.cancel()
        suggestionsTask?.cancel()
        query = ""
        activeQuery = ""
        results = []
        suggestions = []
        nextPageToken = nil
        errorMessage = nil
        isSearching = false
        isLoadingMore = false
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
