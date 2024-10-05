//
//  VideoActor+Entries.swift
//  Unwatched
//

import SwiftData
import SwiftUI
import Observation
import OSLog

// Entries
extension VideoActor {
    static func moveQueueEntry(
        from source: IndexSet,
        to destination: Int,
        modelContext: ModelContext
    ) throws {
        let fetchDescriptor = FetchDescriptor<QueueEntry>()
        let queue = try modelContext.fetch(fetchDescriptor)
        var orderedQueue = queue.sorted(by: { $0.order < $1.order })
        orderedQueue.move(fromOffsets: source, toOffset: destination)

        for (index, queueEntry) in orderedQueue.enumerated() {
            queueEntry.order = index
        }
        try modelContext.save()
    }

    func moveVideoToInbox(_ videoId: PersistentIdentifier) throws {
        guard let video = modelContext.model(for: videoId) as? Video else {
            Logger.log.warning("moveVideoToInbox no video found")
            return
        }
        if video.inboxEntry != nil {
            VideoActor.clearEntries(
                from: video,
                except: InboxEntry.self,
                updateCleared: false,
                modelContext: modelContext
            )
        } else {
            VideoActor.clearEntries(
                from: video,
                updateCleared: false,
                modelContext: modelContext
            )
            let inboxEntry = InboxEntry(video)
            modelContext.insert(inboxEntry)
        }
        try modelContext.save()
    }

    func getNewVideosAndUpdateExisting(sub: Subscription,
                                       videos: [SendableVideo]) async -> [SendableVideo] {
        guard let subVideos = sub.videos else {
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
        if isYtShort == true && UserDefaults.standard.bool(forKey: Const.hideShorts) {
            VideoService.clearEntries(
                from: video,
                except: QueueEntry.self,
                updateCleared: false,
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

        var placement = sub.placeVideosIn
        if sub.placeVideosIn == .defaultPlacement {
            placement = defaultPlacement.videoPlacement
        }
        if defaultPlacement.hideShortsEverywhere {
            let count = addSingleVideoTo(
                videosToAdd,
                videoPlacement: placement,
                defaultPlacement: defaultPlacement
            )
            return count
        } else {
            addVideosTo(videos: videosToAdd, placement: placement, index: 1)
        }
        return videosToAdd.count
    }

    private func addSingleVideoTo(
        _ videos: [Video],
        videoPlacement: VideoPlacement,
        defaultPlacement: DefaultVideoPlacement
    ) -> Int {
        var addedVideosCount = 0
        // check setting for ytShort, use individual setting in that case
        for video in videos {
            let placement: VideoPlacement = (video.isYtShort == true && defaultPlacement.hideShortsEverywhere)
                ? VideoPlacement.nothing
                : videoPlacement
            addVideosTo(videos: [video], placement: placement, index: 1)
            addedVideosCount += 1
        }
        return addedVideosCount
    }

    func addVideosTo(videos: [Video], placement: VideoPlacement, index: Int = 1) {
        if placement == .inbox {
            addVideosToInbox(videos)
        } else if placement == .queue {
            VideoActor.insertQueueEntries(
                at: index,
                videos: videos,
                modelContext: modelContext
            )
            if !videos.isEmpty {
                let count = UserDefaults.standard.integer(forKey: Const.newQueueItemsCount)
                UserDefaults.standard.setValue(count + videos.count, forKey: Const.newQueueItemsCount)
            }
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
        if !videos.isEmpty {
            let count = UserDefaults.standard.integer(forKey: Const.newInboxItemsCount)
            UserDefaults.standard.setValue(count + videos.count, forKey: Const.newInboxItemsCount)
        }
        for video in videos {
            let inboxEntry = InboxEntry(video)
            modelContext.insert(inboxEntry)
            video.inboxEntry = inboxEntry
            VideoActor.clearEntries(
                from: video,
                except: InboxEntry.self,
                updateCleared: false,
                modelContext: modelContext
            )
        }
    }

    func clearEntries(from videoId: PersistentIdentifier, updateCleared: Bool = false) throws {
        if let video = modelContext.model(for: videoId) as? Video {
            VideoActor.clearEntries(
                from: video,
                updateCleared: updateCleared,
                modelContext: modelContext
            )
            try modelContext.save()
        } else {
            Logger.log.info("clearEntries: model not found")
        }
    }

    private static func clearEntries(from video: Video,
                                     except model: (any PersistentModel.Type)? = nil,
                                     updateCleared: Bool,
                                     modelContext: ModelContext) {
        if model != InboxEntry.self, let inboxEntry = video.inboxEntry {
            VideoActor.deleteInboxEntry(inboxEntry, updateCleared: updateCleared, modelContext: modelContext)
        }
        if model != QueueEntry.self, let queueEntry = video.queueEntry {
            VideoActor.deleteQueueEntry(queueEntry, modelContext: modelContext)
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
            if let video = modelContext.model(for: videoId) as? Video {
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
                    updateCleared: false,
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

                if queueWasEmpty {
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
            for (index, queueEntry) in queue.enumerated() {
                queueEntry.order = index
            }
        } catch {
            Logger.log.error("insertQueueEntries: \(error)")
        }
    }

    static func deleteQueueEntry(_ queueEntry: QueueEntry, modelContext: ModelContext) {
        let deletedOrder = queueEntry.order
        modelContext.delete(queueEntry)
        VideoActor.updateQueueOrderDelete(deletedOrder: deletedOrder, modelContext: modelContext)
    }

    static func deleteInboxEntry(_ entry: InboxEntry, updateCleared: Bool = false, modelContext: ModelContext) {
        if updateCleared {
            entry.video?.clearedInboxDate = .now
        }
        modelContext.delete(entry)
    }

    private static func updateQueueOrderDelete(deletedOrder: Int, modelContext: ModelContext) {
        do {
            let fetchDescriptor = FetchDescriptor<QueueEntry>()
            let queue = try modelContext.fetch(fetchDescriptor)
            for queueEntry in queue where queueEntry.order > deletedOrder {
                queueEntry.order -= 1
            }
        } catch {
            Logger.log.error("No queue entry found to delete")
        }
    }

    func clearList(_ list: ClearList, _ direction: ClearDirection, index: Int?, date: Date?) throws {
        switch list {
        case .inbox:
            clearInbox(direction, date: date)
        case .queue:
            clearQueue(direction, index: index)
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
            VideoActor.deleteInboxEntry(entry, modelContext: modelContext)
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
            VideoActor.deleteQueueEntry(entry, modelContext: modelContext)
        }
    }
}
