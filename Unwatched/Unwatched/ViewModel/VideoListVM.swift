//
//  VideoListVM.swift
//  Unwatched
//

import SwiftData
import UnwatchedShared
import SwiftUI
import OSLog

@Observable class VideoListVM: TransactionVM<Video> {
    @ObservationIgnored private(set) var initialBatchSize: Int
    @ObservationIgnored private var pageSize: Int = 100

    @MainActor
    var videos = [SendableVideo]()

    @ObservationIgnored @MainActor
    private var cachedEpisodeMatches = [SendableVideo]()

    /// Paging offset for the stored rows alone: `videos` can also hold cached episodes.
    @ObservationIgnored @MainActor
    private var loadedVideoCount = 0

    @MainActor
    var isLoading = true

    var filter: Predicate<Video>?
    var manualFilter: (@Sendable (Video) -> Bool)?
    private var sort: [SortDescriptor<Video>] = []

    init(listId: String, initialBatchSize: Int = 50) {
        self.initialBatchSize = initialBatchSize
        super.init(listId: listId)
    }

    @MainActor
    var hasNoVideos: Bool {
        videos.isEmpty && !isLoading
    }

    @MainActor
    func setSearchText(_ searchText: String) {
        filter = VideoListView.getVideoFilter(searchText: searchText)
        Task {
            cachedEpisodeMatches = await loadCachedEpisodeMatches(searchText)
            await updateData(force: true)
        }
    }

    /// Podcast episodes only exist as `Video` rows once the user acts on one, so a library search
    /// has to look through `PodcastEpisodeCache` as well to find the rest of a show's catalogue.
    @MainActor
    private func loadCachedEpisodeMatches(_ searchText: String) async -> [SendableVideo] {
        guard !searchText.isEmpty else { return [] }
        let matches = await Task.detached {
            PodcastEpisodeCache.search(searchText, limit: Const.podcastEpisodeSearchLimit)
        }.value
        guard !matches.isEmpty else { return [] }

        let shows = podcastShowsByFeedUrl()
        return matches.compactMap { match in
            guard let show = shows[match.feedUrl] else { return nil }
            var episode = match.episode
            episode.subscription = show
            return episode
        }
    }

    @MainActor
    private func podcastShowsByFeedUrl() -> [URL: SendableSubscription] {
        let fetch = FetchDescriptor<Subscription>(predicate: #Predicate { $0.isPodcast == true })
        let subs = (try? DataProvider.mainContext.fetch(fetch)) ?? []
        var result = [URL: SendableSubscription]()
        for sub in subs {
            if let link = sub.link {
                result[link] = sub.toExport
            }
        }
        return result
    }

    @MainActor
    private func mergeCachedEpisodes() {
        guard !cachedEpisodeMatches.isEmpty else { return }
        var known = Set(videos.map(\.youtubeId))
        var merged = videos
        for episode in cachedEpisodeMatches where !known.contains(episode.youtubeId) {
            known.insert(episode.youtubeId)
            merged.append(episode)
        }
        videos = merged.sorted {
            ($0.publishedDate ?? .distantPast) > ($1.publishedDate ?? .distantPast)
        }
    }

    @MainActor
    private func fetchVideos(skip: Int = 0, limit: Int? = nil) async {
        Log.info("VideoListVM: fetchVideos")
        isLoading = true
        defer {
            isLoading = false
        }
        let newVideos = await VideoService.getSendableVideos(
            filter,
            manualFilter,
            sort,
            skip,
            limit ?? initialBatchSize
        )

        loadedVideoCount = skip == 0 ? newVideos.count : loadedVideoCount + newVideos.count
        withAnimation {
            if skip != 0 {
                videos.append(contentsOf: newVideos)
            } else {
                videos = newVideos
            }
            mergeCachedEpisodes()
        }
    }

    @MainActor
    func setSorting(_ sorting: [SortDescriptor<Video>], refresh: Bool = false) {
        sort = sorting
        if refresh {
            Task {
                await updateData(force: true)
            }
        }
    }

    @MainActor
    func updateVideo(_ video: SendableVideo) {
        if let id = video.persistentId {
            updateVideos([id])
        }
    }

    @MainActor
    func updateVideos(_ ids: Set<PersistentIdentifier>) {
        Log.info("updateVideos: \(ids.count)")
        let modelContext = DataProvider.mainContext
        for persistentId in ids {
            guard let updatedVideo: Video = modelContext.existingModel(for: persistentId) else {
                Log.warning("updateVideo failed: no model found; removing video")
                withAnimation {
                    if let index = videos.firstIndex(where: { $0.persistentId == persistentId }) {
                        removeVideo(at: index)
                    }
                }
                return
            }

            withAnimation {
                if let index = videos.firstIndex(where: { $0.persistentId == persistentId }) {
                    if let filter, !((try? filter.evaluate(updatedVideo)) ?? false) {
                        removeVideo(at: index)
                    } else if let sendable = updatedVideo.toExportWithSubscription {
                        videos[index] = sendable
                    }
                } else {
                    // item not found in list, update all
                    Task {
                        await updateData(force: true)
                    }
                    return
                }
            }
        }
    }

    @MainActor
    private func removeVideo(at index: Int) {
        if videos[index].persistentId != nil {
            loadedVideoCount -= 1
        }
        videos.remove(at: index)
    }

    @MainActor
    func updateData(force: Bool = false) async {
        var loaded = false
        if videos.isEmpty || force {
            await fetchVideos()
            loaded = true
        }
        let ids = await modelsHaveChangesUpdateToken()
        if loaded {
            return
        }
        if let ids {
            updateVideos(ids)
        } else {
            await fetchVideos()
        }
    }

    @MainActor
    func loadMoreContentIfNeeded(currentItem: SendableVideo) {
        let thresholdIndex = videos.index(videos.endIndex, offsetBy: -5)
        if videos.firstIndex(of: currentItem) == thresholdIndex {
            loadMoreContent()
        }
    }

    @MainActor
    private func loadMoreContent() {
        guard !isLoading else {
            return
        }
        isLoading = true
        defer {
            isLoading = false
        }

        if manualFilter != nil {
            Log.warning("loadMoreContent: manualFilter is set, skipping pagination")
            return
        }

        let skip = loadedVideoCount
        let limit = pageSize

        Task {
            await fetchVideos(skip: skip, limit: limit)
        }
    }
}
