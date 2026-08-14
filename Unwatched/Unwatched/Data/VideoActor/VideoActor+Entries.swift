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

        let moved = source.map { orderedQueue[$0] }
        orderedQueue.move(fromOffsets: source, toOffset: destination)

        // Only the entries that moved need a new order; the ones they moved past keep theirs.
        let movedIds = Set(moved.map(ObjectIdentifier.init))
        let remaining = orderedQueue.filter { !movedIds.contains(ObjectIdentifier($0)) }
        let position = orderedQueue.firstIndex { movedIds.contains(ObjectIdentifier($0)) } ?? 0
        if let orders = QueueOrder.insert(
            count: moved.count,
            at: position,
            into: remaining.map(\.order)
        ) {
            for (entry, order) in zip(moved, orders) where entry.order != order {
                entry.order = order
            }
        } else {
            QueueInsertionService.renumber(orderedQueue, modelContext: modelContext)
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
        Log.info("detectShortAndAdjustEntries: \(video.title)")
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
        Log.info("updateExistingVideo: \(video.title)")
        video.title = updatedVideo.title
        video.updatedDate = updatedVideo.updatedDate

        var deleteImage: URL?
        if video.thumbnailUrl != updatedVideo.thumbnailUrl
            && updatedVideo.thumbnailUrl != nil {
            deleteImage = video.thumbnailUrl
            video.thumbnailUrl = updatedVideo.thumbnailUrl
        }

        if video.videoDescription != updatedVideo.videoDescription {
            updateDescriptionAndChapters(video, updatedVideo)
        }
        return deleteImage
    }

    /// Takes the new description, and brings the video's `Chapter` rows along with it if it has
    /// any.
    ///
    /// Videos without rows need nothing further: their chapters are parsed from the description,
    /// and `ChapterService.derivedChapters` keys its cache on that description, so a changed one
    /// re-parses by itself. Rows only exist where the user edited them, and those are worth
    /// correcting in place rather than leaving to describe a description that's gone.
    func updateDescriptionAndChapters(_ video: Video, _ updatedVideo: SendableVideo) {
        video.videoDescription = updatedVideo.videoDescription

        let currentChapters = video.chapters ?? []
        guard !currentChapters.isEmpty else {
            // No rows of its own, so its chapters re-parse from the new description on their own.
            // A SponsorBlock merge was built on the old one though, and has to be rebuilt.
            if !(video.mergedChapters?.isEmpty ?? true) {
                CleanupService.deleteMergedChapters(from: video, modelContext)
            }
            return
        }

        let newChapters = updatedVideo.chapters
        guard !newChapters.isEmpty else {
            return
        }

        // only correct existing chapters, don't replace custom ones
        let similarity = ChapterService.chaptersSimilarity(newChapters, currentChapters)
        guard similarity > 0.6 else {
            return
        }

        let reconciled = ChapterService.reconcileChapters(newChapters, with: currentChapters, in: modelContext)
        if reconciled.hasChanges {
            video.chapters = reconciled.chapters
            CleanupService.deleteMergedChapters(from: video, modelContext)
        }
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
            Log.info("updateRecentVideoDate \(mostRecentDate)")
            subscription.mostRecentVideoDate = mostRecentDate
        }
    }

    func getFilteredByVideoTitleText(
        _ videos: [Video],
        _ sub: Subscription,
        _ defaultPlacement: DefaultVideoPlacement
    ) -> [Video] {
        var filtered = videos

        let filterStringsGlobal = VideoService.getVideoTitleFilter(defaultPlacement.filterVideoTitleText)
        if !filterStringsGlobal.isEmpty {
            filtered = filtered
                .filter { video in
                    let hasMatch = filterStringsGlobal.contains(where: { video.title.localizedStandardContains($0) })
                    if defaultPlacement.allowOnMatch {
                        return hasMatch
                    }
                    return !hasMatch
                }
        }

        let filterStringsSub = VideoService.getVideoTitleFilter(sub.filterText)
        if !filterStringsSub.isEmpty {
            filtered = filtered
                .filter { video in
                    let hasMatch = filterStringsSub.contains(where: { video.title.localizedStandardContains($0) })
                    if sub.allowOnMatch {
                        return hasMatch
                    }
                    return !hasMatch
                }
        }

        return filtered
    }

    func triageSubscriptionVideos(_ sub: Subscription,
                                  videos: [Video],
                                  defaultPlacement: DefaultVideoPlacement) -> [Video] {
        let isFirstTimeLoading = sub.mostRecentVideoDate == nil
        let limitVideos = isFirstTimeLoading ? (firstTimeVideoLimit ?? Const.triageNewSubs) : nil

        var videosToAdd = limitVideos == nil ? videos : Array(videos.prefix(limitVideos!))
        if let cutOffDate = sub.mostRecentVideoDate {
            videosToAdd = videosToAdd.filter { ($0.publishedDate ?? .distantPast) > cutOffDate }
        }
        videosToAdd = getFilteredByVideoTitleText(videosToAdd, sub, defaultPlacement)

        var placement = sub.videoPlacement
        if sub.videoPlacement == .defaultPlacement {
            placement = defaultPlacement.videoPlacement
        }
        let hideShorts = sub.shortsSetting.shouldHide(
            defaultPlacement.hideShorts
        )

        let addedVideos = addSingleVideoTo(
            videosToAdd,
            videoPlacement: placement,
            hideShorts: hideShorts,
            isNew: true
        )
        return addedVideos
    }

    func handleVideoPlacement(_ videos: [Video], placement: VideoPlacement) {
        Log.info("handleVideoPlacement")
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
        ) -> [Video] {
        var addedVideos: [Video] = []
        let videosToProcess = videoPlacement == .queueLast ? Array(videos.reversed()) : videos

        // check setting for ytShort, use individual setting in that case
        for video in videosToProcess {
            let placement: VideoPlacement = (video.isYtShort == true && hideShorts)
                ? VideoPlacement.nothing
                : videoPlacement
            if placement != .nothing {
                video.isNew = isNew
            }
            handleVideoPlacement([video], placement: placement)
            addedVideos.append(video)
        }
        return addedVideos
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
        QueueInsertionService.addVideosToInbox(videos, modelContext: modelContext)
    }

    func clearEntries(from videoId: PersistentIdentifier) throws {
        if let video = self[videoId, as: Video.self] {
            VideoService.clearEntries(
                from: video,
                modelContext: modelContext,
                save: false
            )
            try modelContext.save()
        } else {
            Log.info("clearEntries: model not found")
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
        VideoActor.insertQueueEntries(at: -1, videos: [video], modelContext: modelContext)
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

    /// - Parameter startIndex: the position the videos take in the queue, `-1` for the bottom.
    static func insertQueueEntries(at startIndex: Int = 0, videos: [Video], modelContext: ModelContext) {
        QueueInsertionService.insertQueueEntries(at: startIndex, videos: videos, modelContext: modelContext)
    }

    func clearList(
        _ list: ClearList,
        _ direction: ClearDirection,
        index: Int? = nil,
        date: Date? = nil
    ) throws {
        try VideoActor.clearList(
            list,
            direction,
            index: index,
            date: date,
            modelContext
        )
    }

    static func clearList(
        _ list: ClearList,
        _ direction: ClearDirection,
        index: Int?,
        date: Date?,
        _ modelContext: ModelContext
    ) throws {
        switch list {
        case .inbox:
            clearInbox(direction, date: date, modelContext)
        case .queue:
            clearQueue(direction, index: index, modelContext)
        @unknown default:
            Log.warning("Clear list value not implemented")
        }
        try modelContext.save()
    }

    static func clearInbox(_ direction: ClearDirection, date: Date?, _ modelContext: ModelContext) {
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

    static func clearQueue(
        _ direction: ClearDirection,
        index: Int?,
        _ modelContext: ModelContext
    ) {
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

    func consumeDeferredVideos(_ clearedYouTubeId: String? = nil) {
        let past = Date.distantFuture
        let now = Date.now
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { $0.deferDate != nil && $0.deferDate ?? past <= now })
        let videos = try? modelContext.fetch(fetch)

        Log.info("consumeDeferredVideos: \(videos?.count ?? 0)")

        for video in videos ?? [] {
            video.deferDate = nil

            if let clearedId = clearedYouTubeId, video.youtubeId == clearedId {
                Log.info("consumeDeferredVideos: already cleared \(video.title)")
                continue
            }

            guard video.inboxEntry == nil,
                  video.queueEntry == nil else {
                continue
            }
            video.isNew = true
            _ = addSingleVideoTo(
                [video],
                videoPlacement: .queueNext,
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

    func getEntryVideosWithoutDuration() -> [Video] {
        let inboxFetch = FetchDescriptor<InboxEntry>(predicate: #Predicate { $0.video?.duration == nil })
        let inboxEntries = try? modelContext.fetch(inboxFetch)
        var videosToProcess = inboxEntries?.compactMap { $0.video } ?? []

        let queueFetch = FetchDescriptor<QueueEntry>(predicate: #Predicate { $0.video?.duration == nil })
        let queueEntries = try? modelContext.fetch(queueFetch)
        videosToProcess.append(contentsOf: queueEntries?.compactMap { $0.video } ?? [])

        let uniqueVideos = Array(Set(videosToProcess))
        return uniqueVideos
    }

    func fetchVideoDurationsQueueInbox() async throws -> [VideoDurationInfo] {
        Log.info("fetchVideoDurationsQueueInbox")
        return try await fetchVideoDurations(for: [], includeEntries: true)
    }

    private func getVideosToFetchDurationFor(
        _ videos: [Video],
        optional optionalVideos: [Video],
        includeEntries: Bool = true
    ) -> [Video] {
        var checkVideos = videos
        var toFetchVideos: [Video] = []
        var seenYouTubeIds = Set<String>()

        if includeEntries {
            let entryVideos = getEntryVideosWithoutDuration()
            checkVideos.append(contentsOf: entryVideos)
            Log.info("getVideosToFetchDurationFor: \(entryVideos.count) entry videos without duration")
        }

        let staleCutoffDate = Date().addingTimeInterval(-Const.durationFetchInterval)
        var availableOptionalVideos: [Video] = []
        // Process checkVideos and ensure unique youtubeIds
        for video in checkVideos {
            guard !seenYouTubeIds.contains(video.youtubeId) else { continue }
            seenYouTubeIds.insert(video.youtubeId)

            if shouldFetchDurationForVideo(video, cutoffDate: staleCutoffDate) {
                toFetchVideos.append(video)
            } else {
                // videos without duration, but already checked recently
                availableOptionalVideos.append(video)
            }
        }

        // Add unique optional videos
        for video in optionalVideos {
            guard !seenYouTubeIds.contains(video.youtubeId) else { continue }
            seenYouTubeIds.insert(video.youtubeId)
            availableOptionalVideos.append(video)
        }

        // Remove videos that are already in toFetchVideos from availableOptionalVideos
        let toFetchYouTubeIds = Set(toFetchVideos.map { $0.youtubeId })
        availableOptionalVideos = availableOptionalVideos.filter { !toFetchYouTubeIds.contains($0.youtubeId) }

        // Fill remaining slots up to maxRequest boundary
        let maxRequest = Const.maxVideoIdsPerRequest
        let currentCount = toFetchVideos.count
        let slotsToFill = calculateSlotsToFill(currentCount: currentCount, maxRequest: maxRequest)
        if slotsToFill > 0 {
            let additionalVideos = Array(availableOptionalVideos.prefix(slotsToFill))
            toFetchVideos.append(contentsOf: additionalVideos)
            Log.info("getVideosToFetchDurationFor: \(additionalVideos.count) batch filler")
        }

        Log.info("getVideosToFetchDurationFor: Total: \(toFetchVideos.count)")
        return toFetchVideos
    }

    private func shouldFetchDurationForVideo(_ video: Video, cutoffDate: Date) -> Bool {
        guard let apiUpdatedDate = video.apiUpdatedDate else {
            return true // No update date means we should fetch
        }
        return apiUpdatedDate < cutoffDate
    }

    private func calculateSlotsToFill(currentCount: Int, maxRequest: Int) -> Int {
        let remainder = currentCount % maxRequest
        return remainder > 0 ? maxRequest - remainder : 0
    }

    /// Fetch durations for videos without duration set
    /// - Parameters:
    ///  - videos: videos to check for duration
    ///  - optionalVideos: videos that will be checked if the request limit is not yet reached
    func fetchVideoDurations(
        for videoIds: [PersistentIdentifier],
        optional optionalVideoIds: [PersistentIdentifier] = [],
        includeEntries: Bool = true,
        ) async throws -> [VideoDurationInfo] {
        Log.info("fetchUpdateDurations, videos: \(videoIds.count)")
        guard !videoIds.isEmpty || includeEntries else {
            Log.info("fetchUpdateDurations, no videos without duration")
            return []
        }

        // Ids, not models: a model held across the request sits on the shared context while other
        // jobs take turns on it, and one of those may delete its row.
        let videos: [Video] = videoIds.compactMap { modelContext.resolvedModel(withID: $0) }
        let optionalVideos: [Video] = optionalVideoIds.compactMap { modelContext.resolvedModel(withID: $0) }

        let selected = getVideosToFetchDurationFor(
            videos,
            optional: optionalVideos,
            includeEntries: includeEntries
        ).map { (youtubeId: $0.youtubeId, modelId: $0.persistentModelID) }

        let infos = try await YoutubeDataAPI.getYtVideoDurations(selected.map(\.youtubeId))

        let durations = Dictionary(
            infos.map { ($0.youtubeId, $0) },
            uniquingKeysWith: { _, new in new }
        )

        var results = [VideoDurationInfo]()
        for entry in selected {
            guard let video: Video = modelContext.resolvedModel(withID: entry.modelId) else {
                // deleted while the request was in flight
                continue
            }
            // mark as updated even without a duration: deleted videos aren't in the response
            video.apiUpdatedDate = Date()

            guard var info = durations[entry.youtubeId] else {
                continue
            }
            video.duration = info.duration
            info.persistentId = video.persistentModelID
            results.append(info)
        }
        try modelContext.save()
        return results
    }
}
