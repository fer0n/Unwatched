//
//  VideoListVM.swift
//  Unwatched
//

import SwiftData
import UnwatchedShared
import SwiftUI
import OSLog

@Observable class VideoListVM: TransactionVM<Video> {
    var videos = [SendableVideo]()
    var isLoading = true

    var adjusted = [SendableVideo]()

    var manualFilter: ((SendableVideo) -> Bool)?
    var filter: Predicate<Video>?

    var sort: [SortDescriptor<Video>] = []

    var hasNoVideos: Bool {
        videos.isEmpty && !isLoading
    }

    private func fetchVideos() async {
        Logger.log.info("VideoListVM: fetchVideos")
        isLoading = true
        guard let container = container else {
            isLoading = false
            Logger.log.info("fetchVideos: No container found")
            return
        }
        let vids = await VideoService.getSendableVideos(container, filter, sort)
        withAnimation {
            videos = vids
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
            guard let updatedVideo = modelContext.model(for: persistentId) as? Video else {
                Logger.log.warning("updateVideo failed: no model found")
                return
            }

            if let index = videos.firstIndex(where: { $0.persistentId == persistentId }),
               let sendable = updatedVideo.toExportWithSubscription {
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
}
