//
//  VideoListItemSwipeActionsModifier+Actions.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

extension VideoListItemSwipeActionsModifier {
    func viewChannel() {
        // workaround: drag & tap gesture require workaround that breaks title tap to view channel
        if let video = VideoService.existingVideoModel(from: videoData, modelContext: modelContext) {
            navManager.pushChannel(of: video)
        } else if let subChannelId = videoData.subscriptionData?.youtubeChannelId,
                  let sub = SubscriptionService.getRegularChannel(subChannelId) {
            navManager.pushSubscription(subscription: sub)
        } else if let sub = getVideo()?.subscription {
            // podcasts have no channel id
            navManager.pushSubscription(subscription: sub)
        }
    }

    func viewPlaylist() {
        navManager.pushSubscription(
            subscription: VideoService.existingVideoModel(from: videoData, modelContext: modelContext)?.subscription
        )
    }

    func getVideo() -> Video? {
        VideoService.getVideoModel(
            from: videoData,
            modelContext: modelContext
        )
    }

    var canBeCleared: Bool {
        config.hasInboxEntry == true || config.hasQueueEntry == true
    }

    func performVideoAction(
        isNew: Bool? = nil,
        asyncAction: ((PersistentIdentifier) -> (Task<Void, Error>)?)?,
        syncAction: ((Video) -> Void)?,
        changeReason: VideoChangeReason? = nil,
        addsToQueue: Bool = false
    ) {
        Log.info("performVideoAction")

        var order = videoData.queueEntryData?.order
        let fillsEmptyQueue = addsToQueue && player.isQueueEmpty(modelContext)
        // asked before the action runs — afterwards the entry is gone and can't be recognised
        var wasTopOfQueue = player.isTopOfQueue(order: order, modelContext)
        var task: Task<Void, Error>?
        if config.async, let videoId = videoData.persistentId {
            let isNewTask = handleIsNewAsync(videoId, isNew)
            task = asyncAction?(videoId)
            Task {
                try? await task?.value
                try? await isNewTask?.value
                onChange?(changeReason, order)
            }
        } else {
            guard let video = getVideo() else {
                Log.error("performVideoAction: no video")
                return
            }
            order = order ?? video.queueEntry?.order
            wasTopOfQueue = player.isTopOfQueue(order: order, modelContext)
            syncAction?(video)
            handleIsNew(video, isNew)
            try? modelContext.save()
            onChange?(changeReason, order)
        }
        handlePotentialQueueChange(
            after: task,
            wasTopOfQueue: wasTopOfQueue,
            fillsEmptyQueue: fillsEmptyQueue
        )
    }

    func handleIsNewAsync(_ videoId: PersistentIdentifier, _ isNew: Bool?) -> Task<Void, Error>? {
        if let isNew, videoData.isNew != isNew {
            return Task {
                let context = DataProvider.mainContext
                let video: Video? = context.existingModel(for: videoId)
                if let video {
                    handleIsNew(video, isNew)
                    try? context.save()
                }
            }
        }
        return nil
    }

    func handleIsNew(_ video: Video, _ isNew: Bool?) {
        if let isNew,
           videoData.isNew != isNew {
            withAnimation {
                video.isNew = isNew
            }
        }
    }

    /// The queue tab's slice, not the row's own list: this also runs from the inbox and the search
    /// results, where `queueFilter` is unset.
    private var currentQueueFilter: QueueFilter {
        navManager.queueFilter(modelContext)
    }

    func addVideoToTopQueue(via: String) {
        Log.info("addVideoTop")
        Signal.videoAction("queueTop", listContext, via: via)
        queueAction {
            performVideoAction(
                isNew: false,
                asyncAction: { videoId in
                    VideoService.insertQueueEntriesAsync(
                        at: 1,
                        videoIds: [videoId],
                        filter: currentQueueFilter
                    )
                },
                syncAction: { video in
                    VideoService.insertQueueEntries(
                        at: 1,
                        videos: [video],
                        filter: currentQueueFilter,
                        modelContext: modelContext
                    )
                },
                changeReason: .moveToQueue,
                addsToQueue: true
            )
        }
    }

    func addVideoToBottomQueue(via: String) {
        Log.info("addVideoBottom")
        Signal.videoAction("queueBottom", listContext, via: via)
        queueAction {
            performVideoAction(
                isNew: false,
                asyncAction: { videoId in
                    VideoService.addToBottomQueueAsync(
                        videoId: videoId
                    )
                },
                syncAction: { video in
                    VideoService.addToBottomQueue(
                        video: video,
                        modelContext: modelContext
                    )
                },
                changeReason: .moveToQueue,
                addsToQueue: true
            )
        }
    }

    func queueAction(_ action: @escaping @MainActor () -> Void) {
        guard config.delayQueueAction else { action(); return }
        // Workaround: delay so the swipe snap-back animation finishes before the list reorders.
        // Without this, animationDidEnd: fires on a row that moved off-screen, crashing.
        // and the animation is broken on iOS 26
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation {
                action()
            }
        }
    }

    func moveToInbox() {
        Log.info("moveToInbox")
        Signal.videoAction("inbox", listContext)
        withAnimation {
            performVideoAction(
                isNew: false,
                asyncAction: { videoId in
                    VideoService.moveVideoToInboxAsync(
                        videoId
                    )
                },
                syncAction: { video in
                    VideoService.moveVideoToInbox(
                        video,
                        modelContext: modelContext
                    )
                },
                changeReason: .moveToInbox
            )
        }
    }

    func toggleBookmark() {
        Signal.videoAction("bookmark", listContext)
        performVideoAction(
            asyncAction: { videoId in
                VideoService.toggleBookmarkFetch(
                    videoId,
                    modelContext
                )
            },
            syncAction: { video in
                VideoService.toggleBookmark(
                    video
                )
            }
        )
    }

    func toggleIsNew() {
        if let videoId = videoData.persistentId {
            let isNew = !(videoData.isNew == true)
            let task = VideoService.setIsNew(videoId, isNew)
            Task {
                try? await task.value
                onChange?(nil, nil)
            }
        }
    }

    func setWatched(_ watched: Bool) {
        Signal.videoAction(watched ? "watched" : "unwatched", listContext)
        performVideoAction(
            isNew: false,
            asyncAction: { videoId in
                VideoService.setVideoWatchedAsync(
                    videoId,
                    watched: watched
                )
            },
            syncAction: { video in
                VideoService.setVideoWatched(
                    video,
                    watched: watched,
                    modelContext: modelContext
                )
            },
            changeReason: watched ? .toggleWatched : nil
        )
    }

    func clearVideoEverywhere() {
        Signal.videoAction("clear", listContext)
        performVideoAction(
            isNew: false,
            asyncAction: { videoId in
                VideoService.clearEntriesAsync(
                    from: videoId
                )
            },
            syncAction: { video in
                VideoService.clearEntries(
                    from: video,
                    modelContext: modelContext
                )
            },
            changeReason: .clearEverywhere
        )
        if videoData.isYtShort == true {
            HideShortsTip.clearedShorts += 1
        }
    }

    func handlePotentialQueueChange(
        after task: (Task<(), Error>)? = nil,
        wasTopOfQueue: Bool = false,
        fillsEmptyQueue: Bool = false
    ) {
        if wasTopOfQueue || fillsEmptyQueue {
            try? modelContext.save()
            player.loadTopmostVideoFromQueue(after: task)
        }
    }

    func clearList(_ list: ClearList, _ direction: ClearDirection) {
        try? modelContext.save()
        guard let video = getVideo() else {
            Log.error("clearList: no video")
            return
        }
        onChange?(direction == .above ? .clearAbove : .clearBelow, nil)
        VideoService.clearList(
            list,
            direction,
            index: video.queueEntry?.order,
            date: video.inboxEntry?.date,
            filter: queueFilter,
            modelContext
        )
        if list == .queue && direction == .above {
            player.loadTopmostVideoFromQueue()
        }
    }

    func deleteVideo() {
        if let video = getVideo() {
            clearVideoEverywhere()
            let hasQueueEntry = video.queueEntry != nil
            withAnimation {
                CleanupService.deleteVideo(video, deleteAll: true, modelContext)
                try? modelContext.save()
                onChange?(nil, video.queueEntry?.order)
            }
            if hasQueueEntry {
                player.loadTopmostVideoFromQueue()
            }
        }
    }

    func deferVideo() {
        guard let video = getVideo() else {
            Log.error("deferVideo: no video")
            return
        }
        let order = video.queueEntry?.order
        let wasTopOfQueue = player.isTopOfQueue(order: order, modelContext)
        navManager.deferRequest = DeferRequest(video: video, context: listContext) {
            onChange?(nil, order)
            handlePotentialQueueChange(wasTopOfQueue: wasTopOfQueue)
        }
    }
}
