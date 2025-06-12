//
//  VideoListVM.swift
//  Unwatched
//

import SwiftData
import UnwatchedShared
import SwiftUI
import OSLog

@Observable class VideoListVM: TransactionVM<Video> {
    @ObservationIgnored private(set) var initialBatchSize: Int = 150
    @ObservationIgnored private var pageSize: Int = 250

    @MainActor
    var videos = [SendableVideo]()

    @MainActor
    var isLoading = true

    var filter: Predicate<Video>?
    var manualFilter: (@Sendable (Video) -> Bool)?
    private var sort: [SortDescriptor<Video>] = []

    init(initialBatchSize: Int = 150) {
        self.initialBatchSize = initialBatchSize
    }

    @MainActor
    var hasNoVideos: Bool {
        videos.isEmpty && !isLoading
    }

    @MainActor
    func setSearchText(_ searchText: String) {
        filter = VideoListView.getVideoFilter(searchText: searchText)
        Task {
            await updateData(force: true)
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

        withAnimation {
            if skip != 0 {
                videos.append(contentsOf: newVideos)
            } else {
                videos = newVideos
            }
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
                        videos.remove(at: index)
                    }
                }
                return
            }

            withAnimation {
                if let index = videos.firstIndex(where: { $0.persistentId == persistentId }) {
                    if let filter, !((try? filter.evaluate(updatedVideo)) ?? false) {
                        videos.remove(at: index)
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

        let skip = videos.count
        let limit = pageSize

        Task {
            await fetchVideos(skip: skip, limit: limit)
        }
    }
}
