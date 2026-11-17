//
//  PodcastEpisodeListVM.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared

/// Pages a show's episodes out of `PodcastEpisodeCache`, backfilling the full feed the first time
/// the list runs past what a refresh cached.
@Observable @MainActor final class PodcastEpisodeListVM {
    private(set) var episodes = [SendableVideo]()
    private(set) var isLoading = false
    private(set) var reachedEnd = false
    private(set) var hasLoadedFirstPage = false
    /// nil while not searching
    private(set) var searchResults: [SendableVideo]?
    private(set) var isSearching = false

    @ObservationIgnored private var feedUrl: URL?
    @ObservationIgnored private var show: SendableSubscription?
    @ObservationIgnored private var didSetUp = false
    @ObservationIgnored private var didBackfill = false
    /// Unstructured, so a cancelled search doesn't cancel the download
    @ObservationIgnored private var backfillTask: Task<Bool, Never>?
    @ObservationIgnored private var searchGeneration = 0
    @ObservationIgnored private var loadedIds = Set<String>()

    func setUp(feedUrl: URL?, show: SendableSubscription?) async {
        guard !didSetUp || self.feedUrl != feedUrl else { return }
        didSetUp = true
        self.feedUrl = feedUrl
        self.show = show
        episodes = []
        loadedIds = []
        reachedEnd = false
        didBackfill = false
        backfillTask = nil
        hasLoadedFirstPage = false
        await loadNextPage()
        hasLoadedFirstPage = true
    }

    /// Picks up episodes a refresh wrote to the cache while the list was already on screen.
    /// Re-reads every page the list has shown so far, so a new episode at the top doesn't push
    /// the last one out of view.
    func reloadLoadedPages() async {
        guard let feedUrl, !isLoading else { return }
        guard !episodes.isEmpty else {
            // nothing was in the cache when the list set up; the refresh may have filled it
            reachedEnd = false
            await loadNextPage()
            return
        }
        isLoading = true
        defer { isLoading = false }

        var collected = [SendableVideo]()
        var collectedIds = Set<String>()
        var skip = 0
        while true {
            let page = await fetchPage(feedUrl: feedUrl, skip: skip, limit: Const.podcastEpisodePageSize)
            guard !page.isEmpty else {
                reachedEnd = true
                break
            }
            collected.append(contentsOf: page)
            collectedIds.formUnion(page.map(\.youtubeId))
            skip += page.count
            if loadedIds.isSubset(of: collectedIds) {
                break
            }
        }

        loadedIds = collectedIds
        withAnimation {
            episodes = collected
        }
    }

    /// The first search backfills the full feed: a refresh only caches the newest few episodes.
    func search(_ text: String) async {
        searchGeneration &+= 1
        let generation = searchGeneration
        let text = text.trimmingCharacters(in: .whitespaces)
        guard let feedUrl, !text.isEmpty else {
            searchResults = nil
            isSearching = false
            return
        }
        isSearching = true
        defer {
            if searchGeneration == generation { isSearching = false }
        }
        await backfillOnce(feedUrl: feedUrl)
        let show = show
        let results = await Task.detached {
            PodcastEpisodeCache.episodes(feedUrl: feedUrl, show: show, matching: text)
        }.value
        guard !Task.isCancelled else { return }
        searchResults = results
    }

    func loadMoreIfNeeded(currentItem: SendableVideo) {
        guard !isLoading, !reachedEnd,
              let index = episodes.firstIndex(where: { $0.youtubeId == currentItem.youtubeId }),
              index >= episodes.count - 5 else {
            return
        }
        Task {
            await loadNextPage()
        }
    }

    private func loadNextPage() async {
        guard let feedUrl, !isLoading, !reachedEnd else { return }
        isLoading = true
        defer { isLoading = false }

        var page = await fetchPage(feedUrl: feedUrl, skip: episodes.count)
        if page.isEmpty && !didBackfill {
            await backfillOnce(feedUrl: feedUrl)
            page = await fetchPage(feedUrl: feedUrl, skip: episodes.count)
        }

        let unseen = page.filter { !loadedIds.contains($0.youtubeId) }
        guard !unseen.isEmpty else {
            reachedEnd = true
            return
        }
        for episode in unseen {
            loadedIds.insert(episode.youtubeId)
        }
        withAnimation {
            episodes.append(contentsOf: unseen)
        }
    }

    private func fetchPage(
        feedUrl: URL,
        skip: Int,
        limit: Int = Const.podcastEpisodePageSize
    ) async -> [SendableVideo] {
        let show = show
        return await Task.detached {
            PodcastEpisodeCache.episodes(
                feedUrl: feedUrl,
                show: show,
                skip: skip,
                limit: limit
            )
        }.value
    }

    /// A failed backfill is retried by the next search or page
    private func backfillOnce(feedUrl: URL) async {
        guard !didBackfill else { return }
        let task = backfillTask ?? Task {
            do {
                try await VideoCrawler.backfillPodcastEpisodes(feedUrl: feedUrl)
                return true
            } catch {
                Log.podcasts.error("backfillPodcastEpisodes: \(error)")
                return false
            }
        }
        backfillTask = task
        let succeeded = await task.value
        if succeeded {
            didBackfill = true
        } else if backfillTask == task {
            backfillTask = nil
        }
    }
}
