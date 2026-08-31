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

    @ObservationIgnored private var feedUrl: URL?
    @ObservationIgnored private var show: SendableSubscription?
    @ObservationIgnored private var didSetUp = false
    @ObservationIgnored private var didBackfill = false
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
        hasLoadedFirstPage = false
        await loadNextPage()
        hasLoadedFirstPage = true
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

        var page = await fetchPage(feedUrl: feedUrl)
        if page.isEmpty && !didBackfill {
            didBackfill = true
            await backfill(feedUrl: feedUrl)
            page = await fetchPage(feedUrl: feedUrl)
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

    private func fetchPage(feedUrl: URL) async -> [SendableVideo] {
        let show = show
        let skip = episodes.count
        return await Task.detached {
            PodcastEpisodeCache.episodes(
                feedUrl: feedUrl,
                show: show,
                skip: skip,
                limit: Const.podcastEpisodePageSize
            )
        }.value
    }

    private func backfill(feedUrl: URL) async {
        do {
            try await VideoCrawler.backfillPodcastEpisodes(feedUrl: feedUrl)
        } catch {
            Log.error("backfillPodcastEpisodes: \(error)")
        }
    }
}
