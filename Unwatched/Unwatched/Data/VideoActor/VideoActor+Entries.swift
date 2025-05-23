//
//  VideoActor+Entries.swift
//  Unwatched
//

import SwiftData
import SwiftUI
import Observation
import OSLog
import UnwatchedShared

// Entries
extension VideoActor {
    static func moveQueueEntry(
        from source: IndexSet,
        to destination: Int,
        updateIsNew: Bool = false,
        modelContext: ModelContext
    ) throws {
        let fetchDescriptor = FetchDescriptor<QueueEntry>()
        let queue = try modelContext.fetch(fetchDescriptor)
        var orderedQueue = queue.sorted(by: { $0.order < $1.order })

        if updateIsNew {
            for sourceIndex in source {
                let queueEntry = orderedQueue[sourceIndex]
                if queueEntry.video?.isNew == true {
                    queueEntry.video?.isNew = false
                }
            }
        }

        orderedQueue.move(fromOffsets: source, toOffset: destination)

        for (index, queueEntry) in orderedQueue.enumerated() {
            queueEntry.order = index
        }
        try modelContext.save()
    }

    func getVideosFromSub(_ sub: Subscription, oldestDate: Date) -> [Video]? {
        let subId = sub.persistentModelID
        let past = Date.distantPast
        let fetch = FetchDescriptor<Video>(predicate: #Predicate {
            $0.subscription?.persistentModelID == subId &&
                ($0.publishedDate ?? past) >= oldestDate
        })
        return try? modelContext.fetch(fetch)
    }

    func getNewVideosAndUpdateExisting(sub: Subscription,
                                       videos: [SendableVideo]) async -> [SendableVideo] {
        let oldestDate = videos.compactMap { $0.publishedDate }.min() ?? .distantPast
        guard let subVideos = getVideosFromSub(sub, oldestDate: oldestDate) else {
            return videos
        }
        var subVideosDict = [String: Video]()
        for video in subVideos {
            subVideosDict[video.youtubeId] = video
        }

        var newVideos = [SendableVideo]()
        var imagesToBeDeleted = [URL]()
        for video in videos {
            if let oldVideo = subVideosDict[video.youtubeId] {
                if oldVideo.updatedDate != video.updatedDate {
                    if let url = updateVideoAndGetImageToDelete(oldVideo, video) {
                        imagesToBeDeleted.append(url)
                    }
                }
                if oldVideo.isYtShort == nil {
                    await detectShortAndAdjustEntries(oldVideo)
                }
            } else {
                newVideos.append(video)
            }
        }

        ImageService.deleteImages(imagesToBeDeleted)
        return newVideos
    }

    func detectShortAndAdjustEntries(_ video: Video) async {
        Logger.log.info("detectShortAndAdjustEntries: \(video.title)")
        let (isYtShort, _) = await VideoActor.isYtShort(video.thumbnailUrl)
        video.isYtShort = isYtShort
        if isYtShort == true && (video.subscription?.shortsSetting.shouldHide() ?? false) {
            VideoService.clearEntries(
                from: video,
                modelContext: modelContext
            )
        }
    }

    func updateVideoAndGetImageToDelete(_ video: Video, _ updatedVideo: SendableVideo) -> URL? {
        Logger.log.info("updateExistingVideo: \(video.title)")
        video.title = updatedVideo.title
        video.updatedDate = updatedVideo.updatedDate

        var deleteImage: URL?
        if video.thumbnailUrl != updatedVideo.thumbnailUrl
            && updatedVideo.thumbnailUrl != nil {
            deleteImage = video.thumbnailUrl
            video.thumbnailUrl = updatedVideo.thumbnailUrl
        }

        if video.videoDescription != updatedVideo.videoDescription {
            video.videoDescription = updatedVideo.videoDescription
            deleteOldChapters(from: video)
            let newChapters = updatedVideo.chapters.map {
                let chapter = $0.getChapter
                modelContext.insert(chapter)
                return chapter
            }
            video.chapters = newChapters
        }
        return deleteImage
    }

    private func deleteOldChapters(from video: Video) {
        for chapter in video.chapters ?? [] {
            modelContext.delete(chapter)
        }
        for chapter in video.mergedChapters ?? [] {
            modelContext.delete(chapter)
        }
        video.sponserBlockUpdateDate = nil
    }

    func getMostRecentDate(_ videos: [SendableVideo]) -> Date? {
        let dates = videos.compactMap { $0.publishedDate }
        if let mostRecentDate = dates.max() {
            return mostRecentDate
        }
        return nil
    }

    func updateRecentVideoDate(_ subscription: Subscription, _ date: Date?) {
        if let mostRecentDate = date, date != nil,
           date ?? .distantPast > subscription.mostRecentVideoDate ?? .distantPast {
            Logger.log.info("updateRecentVideoDate \(mostRecentDate)")
            subscription.mostRecentVideoDate = mostRecentDate
        }
    }

    func triageSubscriptionVideos(_ sub: Subscription,
                                  videos: [Video],
                                  defaultPlacement: DefaultVideoPlacement) -> Int {
        let isFirstTimeLoading = sub.mostRecentVideoDate == nil
        let limitVideos = isFirstTimeLoading ? Const.triageNewSubs : nil

        var videosToAdd = limitVideos == nil ? videos : Array(videos.prefix(limitVideos!))
        if let cutOffDate = sub.mostRecentVideoDate {
            videosToAdd = videosToAdd.filter { ($0.publishedDate ?? .distantPast) > cutOffDate }
        }

        var placement = sub.videoPlacement
        if sub.videoPlacement == .defaultPlacement {
            placement = defaultPlacement.videoPlacement
        }
        let hideShorts = sub.shortsSetting.shouldHide(
            defaultPlacement.hideShorts
        )

        let count = addSingleVideoTo(
            videosToAdd,
            videoPlacement: placement,
            hideShorts: hideShorts,
            isNew: true
        )
        return count
    }

    func handleVideoPlacement(_ videos: [Video], placement: VideoPlacement) {
        Logger.log.info("handleVideoPlacement")
        switch placement {
        case .inbox:
            addVideosTo(videos, placement: .inbox)
        case .queueNext:
            addVideosTo(videos, placement: .queue, index: 1)
        case .queueLast:
            addVideosTo(videos, placement: .queue, index: -1)
        default:
            break
        }
    }

    private func addSingleVideoTo(
        _ videos: [Video],
        videoPlacement: VideoPlacement,
        hideShorts: Bool,
        isNew: Bool,
        ) -> Int {
        var addedVideosCount = 0
        // check setting for ytShort, use individual setting in that case
        for video in videos {
            let placement: VideoPlacement = (video.isYtShort == true && hideShorts)
                ? VideoPlacement.nothing
                : videoPlacement
            if placement != .nothing {
                video.isNew = isNew
            }
            handleVideoPlacement([video], placement: placement)
            addedVideosCount += 1
        }
        return addedVideosCount
    }

    func addVideosTo(_ videos: [Video], placement: VideoPlacementArea, index: Int = 1) {
        if placement == .inbox {
            addVideosToInbox(videos)
        } else if placement == .queue {
            VideoActor.insertQueueEntries(
                at: index,
                videos: videos,
                modelContext: modelContext
            )
        } else {
            return
        }

        videos.forEach { video in
            if let sendable = video.toExport {
                let title = video.subscription?.title ?? ""
                newVideos.addVideo(sendable, for: title, in: placement)
            }
        }
    }

    private func addVideosToInbox(_ videos: [Video]) {
        for video in videos {
            let inboxEntry = InboxEntry(video)
            modelContext.insert(inboxEntry)
            video.inboxEntry = inboxEntry
            VideoActor.clearEntries(
                from: video,
                except: InboxEntry.self,
                modelContext: modelContext
            )
        }
    }

    func clearEntries(from videoId: PersistentIdentifier) throws {
        if let video = self[videoId, as: Video.self] {
            VideoActor.clearEntries(
                from: video,
                modelContext: modelContext,
                )
            try modelContext.save()
        } else {
            Logger.log.info("clearEntries: model not found")
        }
    }

    private static func clearEntries(from video: Video,
                                     except model: (any PersistentModel.Type)? = nil,
                                     modelContext: ModelContext) {
        if model != InboxEntry.self, let inboxEntry = video.inboxEntry {
            VideoService.deleteInboxEntry(inboxEntry, modelContext: modelContext)
        }
        if model != QueueEntry.self, let queueEntry = video.queueEntry {
            VideoService.deleteQueueEntry(queueEntry, modelContext: modelContext)
        }
    }

    func moveVideoToInbox(_ videoId: PersistentIdentifier) throws {
        if let video = self[videoId, as: Video.self] {
            VideoService.moveVideoToInbox(video, modelContext: modelContext)
            try modelContext.save()
        }
    }

    func addToBottomQueue(videoId: PersistentIdentifier) throws {
        if let video = self[videoId, as: Video.self] {
            try VideoActor.addToBottomQueue(video: video, modelContext: modelContext)
        }
    }

    static func addToBottomQueue(video: Video, modelContext: ModelContext) throws {
        var fetch = FetchDescriptor<QueueEntry>(sortBy: [SortDescriptor(\.order, order: .reverse)])
        fetch.fetchLimit = 1
        let entries = try? modelContext.fetch(fetch)

        var insertAt = 0
        if let entries = entries {
            if video.queueEntry != nil {
                insertAt = entries.first?.order ?? 0
            } else {
                insertAt = (entries.first?.order ?? 0) + 1
            }
        }
        VideoActor.insertQueueEntries(at: insertAt, videos: [video], modelContext: modelContext)
        try modelContext.save()
    }

    func insertQueueEntries(at startIndex: Int = 0, videoIds: [PersistentIdentifier]) throws {
        var videos = [Video]()
        for videoId in videoIds {
            if let video = self[videoId, as: Video.self] {
                videos.append(video)
            }
        }
        VideoActor.insertQueueEntries(
            at: startIndex,
            videos: videos,
            modelContext: modelContext
        )
        try modelContext.save()
    }

    static func insertQueueEntries(at startIndex: Int = 0, videos: [Video], modelContext: ModelContext) {
        do {
            let sort = SortDescriptor<QueueEntry>(\.order)
            let fetch = FetchDescriptor<QueueEntry>(sortBy: [sort])
            var queue = try modelContext.fetch(fetch)
            let queueWasEmpty = queue.isEmpty

            for (index, video) in videos.enumerated() {
                VideoActor.clearEntries(
                    from: video,
                    except: QueueEntry.self,
                    modelContext: modelContext
                )
                if let queueEntry = video.queueEntry {
                    queue.removeAll { $0 == queueEntry }
                }

                let queueEntry: QueueEntry
                if let existingQueueEntry = video.queueEntry {
                    queueEntry = existingQueueEntry
                } else {
                    let newQueueEntry = QueueEntry(video: video, order: 0)
                    modelContext.insert(newQueueEntry)
                    video.queueEntry = newQueueEntry
                    queueEntry = newQueueEntry
                }

                if queueWasEmpty || startIndex == -1 {
                    queue.append(queueEntry)
                } else {
                    let targetIndex = startIndex + index
                    if targetIndex >= queue.count {
                        queue.append(queueEntry)
                    } else {
                        queue.insert(queueEntry, at: targetIndex)
                    }
                }
            }
            for (index, queueEntry) in queue.enumerated() where queueEntry.order != index {
                queueEntry.order = index
            }
        } catch {
            Logger.log.error("insertQueueEntries: \(error)")
        }
    }

    func clearList(_ list: ClearList, _ direction: ClearDirection, index: Int?, date: Date?) throws {
        switch list {
        case .inbox:
            clearInbox(direction, date: date)
        case .queue:
            clearQueue(direction, index: index)
        @unknown default:
            Logger.log.warning("Clear list value not implemented")
        }
        try modelContext.save()
    }

    private func clearInbox(_ direction: ClearDirection, date: Date?) {
        let past = Date.distantPast
        let dateL = date ?? past
        var filter: Predicate<InboxEntry>
        if direction == .above {
            filter = #Predicate<InboxEntry> { $0.date ?? past > dateL }
        } else {
            filter = #Predicate<InboxEntry> { $0.date ?? past < dateL }
        }
        let fetch = FetchDescriptor<InboxEntry>(predicate: filter)
        let inboxEntries = try? modelContext.fetch(fetch)
        for entry in inboxEntries ?? [] {
            VideoService.deleteInboxEntry(entry, modelContext: modelContext)
        }
    }

    private func clearQueue(_ direction: ClearDirection, index: Int?) {
        var filter: Predicate<QueueEntry>
        if direction == .above {
            filter = #Predicate<QueueEntry> { $0.order < index ?? 0 }
        } else {
            filter = #Predicate<QueueEntry> { $0.order > index ?? 0 }
        }
        let fetch = FetchDescriptor<QueueEntry>(predicate: filter)
        let queueEntries = try? modelContext.fetch(fetch)
        for entry in queueEntries ?? [] {
            VideoService.deleteQueueEntry(entry, modelContext: modelContext)
        }
    }

    func setVideoWatched(_ videoId: PersistentIdentifier, watched: Bool = true) throws {
        if let video = self[videoId, as: Video.self] {
            VideoService.setVideoWatched(video, watched: watched, modelContext: modelContext)
            try modelContext.save()
        }
    }

    func consumeDeferredVideos() {
        let past = Date.distantFuture
        let now = Date.now
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { $0.deferDate != nil && $0.deferDate ?? past <= now })
        let videos = try? modelContext.fetch(fetch)

        Logger.log.info("consumeDeferredVideos: \(videos?.count ?? 0)")

        let defaultPlacement = getDefaultVideoPlacement()

        for video in videos ?? [] {
            video.deferDate = nil
            guard video.inboxEntry == nil, video.queueEntry == nil else {
                continue
            }

            let sub = video.subscription
            var placement = sub?.videoPlacement ?? .inbox
            if sub?.videoPlacement == .defaultPlacement {
                placement = defaultPlacement.videoPlacement
            }

            _ = addSingleVideoTo(
                [video],
                videoPlacement: placement,
                hideShorts: false,
                isNew: true,
                )
        }

        try? modelContext.save()
    }

    func inboxShortsCount() -> Int? {
        let fetch = FetchDescriptor<InboxEntry>(predicate: #Predicate { $0.video?.isYtShort == true })
        return try? modelContext.fetchCount(fetch)
    }
}
