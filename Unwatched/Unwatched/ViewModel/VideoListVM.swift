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
    @ObservationIgnored private var allVideos = [SendableVideo]()
    @ObservationIgnored private var allFilteredVideos = [SendableVideo]()

    var videos = [SendableVideo]()
    var isLoading = true
    private var isSearching = false

    var filter: Predicate<Video>?
    private var sort: [SortDescriptor<Video>] = []

    var hasNoVideos: Bool {
        videos.isEmpty && !isLoading
    }

    func setSearchText(_ searchText: String) {
        isSearching = !searchText.isEmpty
        let newVideos: [SendableVideo]
        if !searchText.isEmpty {
            allFilteredVideos = allVideos.filter({
                $0.title.localizedStandardContains(searchText)
            })
            newVideos = allFilteredVideos
        } else {
            allFilteredVideos = []
            newVideos = allVideos
        }
        withAnimation {
            setInitialBatch(newVideos)
        }
    }

    private func fetchVideos() async {
        Logger.log.info("VideoListVM: fetchVideos")
        isLoading = true
        guard let container = container else {
            isLoading = false
            Logger.log.info("fetchVideos: No container found")
            return
        }
        allVideos = await VideoService.getSendableVideos(container, filter, sort)

        withAnimation {
            setInitialBatch(allVideos)
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
            if let index = allVideos.firstIndex(where: { $0.persistentId == persistentId }) {
                allVideos[index] = sendable
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

    func setInitialBatch(_ newVideos: [SendableVideo]) {
        let endIndex = min(newVideos.count, initialBatchSize)
        videos = Array(newVideos[0..<endIndex])
    }

    private func loadMoreContent() {
        guard !isLoading else {
            return
        }
        isLoading = true

        let currentAllVideos = isSearching ? allFilteredVideos : allVideos

        let currentCount = videos.count
        let endIndex = min(currentCount + pageSize, currentAllVideos.count)

        guard currentCount < endIndex else {
            isLoading = false
            return
        }

        let nextBatch = Array(currentAllVideos[currentCount..<endIndex])
        videos.append(contentsOf: nextBatch)
        isLoading = false
    }
}
