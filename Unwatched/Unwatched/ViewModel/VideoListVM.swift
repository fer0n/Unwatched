//
//  VideoListVM.swift
//  Unwatched
//

import SwiftData
import UnwatchedShared
import SwiftUI
import OSLog

@Observable class VideoListVM: TransactionVM<Video> {
    @ObservationIgnored private let initialBatchSize: Int = 150
    @ObservationIgnored private let pageSize: Int = 250

    var videos = [SendableVideo]()
    var isLoading = true

    var filter: Predicate<Video>?
    private var sort: [SortDescriptor<Video>] = []

    var hasNoVideos: Bool {
        videos.isEmpty && !isLoading
    }

    func setSearchText(_ searchText: String) {
        let hideShorts = UserDefaults.standard.bool(forKey: Const.hideShorts)
        filter = VideoListView.getVideoFilter(showShorts: !hideShorts, searchText: searchText)
        Task {
            await updateData(force: true)
        }
    }

    private func fetchVideos(skip: Int = 0, limit: Int? = nil) async {
        Logger.log.info("VideoListVM: fetchVideos")
        isLoading = true
        guard let container else {
            isLoading = false
            Logger.log.info("fetchVideos: No container found")
            return
        }
        let newVideos = await VideoService.getSendableVideos(
            container,
            filter,
            sort,
            skip,
            limit ?? initialBatchSize
        )

        withAnimation {
            if skip != 0 {
                videos.append(contentsOf: newVideos)
            } else {
                videos = newVideos
            }
            isLoading = false
        }
    }

    func setSorting(_ sorting: [SortDescriptor<Video>], refresh: Bool = false) {
        sort = sorting
        if refresh {
            Task {
                await updateData(force: true)
            }
        }
    }

    func updateVideo(_ video: SendableVideo) {
        if let id = video.persistentId {
            updateVideos([id])
        }
    }

    func updateVideos(_ ids: Set<PersistentIdentifier>) {
        Logger.log.info("updateVideos: \(ids.count)")
        guard let container = container else {
            Logger.log.warning("updateVideo failed")
            return
        }
        let modelContext = ModelContext(container)
        for persistentId in ids {
            guard let updatedVideo = modelContext.model(for: persistentId) as? Video,
                  let sendable = updatedVideo.toExportWithSubscription else {
                Logger.log.warning("updateVideo failed: no model found")
                return
            }

            if let index = videos.firstIndex(where: { $0.persistentId == persistentId }) {
                videos[index] = sendable
            }
        }
    }

    func updateData(force: Bool = false) async {
        var loaded = false
        if videos.isEmpty || force {
            await fetchVideos()
            loaded = true
        }
        let ids = modelsHaveChangesUpdateToken()
        if loaded {
            return
        }
        if let ids = ids {
            updateVideos(ids)
        } else {
            await fetchVideos()
        }
    }

    func loadMoreContentIfNeeded(currentItem: SendableVideo) {
        let thresholdIndex = videos.index(videos.endIndex, offsetBy: -5)
        if videos.firstIndex(of: currentItem) == thresholdIndex {
            loadMoreContent()
        }
    }

    private func loadMoreContent() {
        guard !isLoading else {
            return
        }
        isLoading = true

        let skip = videos.count
        let limit = pageSize

        Task {
            await fetchVideos(skip: skip, limit: limit)
        }
        isLoading = false
    }
}