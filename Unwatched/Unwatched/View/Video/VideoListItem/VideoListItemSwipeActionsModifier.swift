//
//  VideoListItemSwipeActionsModifier.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

struct VideoListItemSwipeActionsModifier: ViewModifier {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    @Environment(PlayerManager.self) private var player
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager

    let videoData: VideoData
    var config: VideoListItemConfig

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                LeadingSwipeActionsView(
                    theme: theme,
                    config: config,
                    addVideoToTopQueue: addVideoToTopQueue,
                    addVideoToBottomQueue: addVideoToBottomQueue,
                    toggleIsNew: toggleIsNew,
                    )
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                TrailingSwipeActionsView(
                    videoData: videoData,
                    theme: theme,
                    config: config,
                    clearVideoEverywhere: clearVideoEverywhere,
                    setWatched: setWatched,
                    addVideoToTopQueue: addVideoToTopQueue,
                    addVideoToBottomQueue: addVideoToBottomQueue,
                    toggleBookmark: toggleBookmark,
                    toggleIsNew: toggleIsNew,
                    moveToInbox: moveToInbox,
                    clearList: clearList,
                    canBeCleared: canBeCleared,
                    deleteVideo: deleteVideo
                )
            }
            .contextMenu(
                config.showContextMenu
                    ? ContextMenu(
                        menuItems: {
                            VideoListItemMoreMenuView(
                                videoData: videoData,
                                config: config,
                                setWatched: setWatched,
                                addVideoToTopQueue: addVideoToTopQueue,
                                addVideoToBottomQueue: addVideoToBottomQueue,
                                clearVideoEverywhere: clearVideoEverywhere,
                                canBeCleared: canBeCleared,
                                toggleBookmark: toggleBookmark,
                                toggleIsNew: toggleIsNew,
                                moveToInbox: moveToInbox,
                                openUrlInApp: { urlString in
                                    navManager.openUrlInApp(.url(urlString))
                                },
                                clearList: clearList,
                                deleteVideo: deleteVideo,
                                viewChannel: viewChannel
                            )
                        })
                    : nil
            )
            #if os(iOS)
            .menuOrder(.priority) // <- not working inside lists
            #endif
            .symbolVariant(.fill)
    }

    func viewChannel() {
        // workaround: drag & tap gesture require workaround that breaks title tap to view channel
        if let subChannelId = videoData.subscriptionData?.youtubeChannelId,
           let sub = SubscriptionService.getRegularChannel(subChannelId) {
            navManager.pushSubscription(subscription: sub)
        }
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
        changeReason: ChangeReason? = nil
    ) {
        Log.info("performVideoAction")

        var order = videoData.queueEntryData?.order
        var task: Task<Void, Error>?
        if config.async, let videoId = videoData.persistentId {
            let isNewTask = handleIsNewAsync(videoId, isNew)
            task = asyncAction?(videoId)
            Task {
                try? await task?.value
                try? await isNewTask?.value
                config.onChange?(changeReason)
            }
        } else {
            guard let video = getVideo() else {
                Log.error("performVideoAction: no video")
                return
            }
            order = order ?? video.queueEntry?.order
            syncAction?(video)
            handleIsNew(video, isNew)
            try? modelContext.save()
            config.onChange?(changeReason)
        }
        handlePotentialQueueChange(after: task, order: order)
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

    func addVideoToTopQueue() {
        Log.info("addVideoTop")
        performVideoAction(
            isNew: false,
            asyncAction: { videoId in
                VideoService.insertQueueEntriesAsync(
                    at: 1,
                    videoIds: [videoId]
                )
            },
            syncAction: { video in
                VideoService.insertQueueEntries(
                    at: 1,
                    videos: [video],
                    modelContext: modelContext
                )
            },
            changeReason: .queue
        )
    }

    func addVideoToBottomQueue() {
        Log.info("addVideoBottom")
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
            changeReason: .queue
        )
    }

    func moveToInbox() {
        Log.info("moveToInbox")
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
                }
            )
        }
    }

    func toggleBookmark() {
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
                config.onChange?(nil)
            }
        }
    }

    func setWatched(_ watched: Bool) {
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
            }
        )
    }

    func clearVideoEverywhere() {
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
            changeReason: .clear
        )
        if videoData.isYtShort == true {
            HideShortsTip.clearedShorts += 1
        }
    }

    func handlePotentialQueueChange(_ video: Video? = nil, after task: (Task<(), Error>)? = nil, order: Int? = nil) {
        if order == 0 || video?.queueEntry?.order == 0 {
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
        config.onChange?(direction == .above ? .clearAbove : .clearBelow)
        let task = VideoService.clearList(
            list,
            direction,
            index: video.queueEntry?.order,
            date: video.inboxEntry?.date)
        if list == .queue && direction == .above {
            player.loadTopmostVideoFromQueue(after: task)
        }
    }

    func deleteVideo() {
        if let video = getVideo() {
            clearVideoEverywhere()
            withAnimation {
                CleanupService.deleteVideo(video, modelContext)
                try? modelContext.save()
                config.onChange?(nil)
            }
        }
    }
}

struct LeadingSwipeActionsView: View {
    var theme: ThemeColor
    var config: VideoListItemConfig
    var addVideoToTopQueue: () -> Void
    var addVideoToBottomQueue: () -> Void
    var toggleIsNew: () -> Void

    var body: some View {
        Group {
            Button(role: config.queueRole,
                   action: addVideoToTopQueue,
                   label: {
                    Image(systemName: Const.queueTopSF)
                   })
                .tint(theme.color.mix(with: Color.black, by: 0.1))
                .accessibilityLabel("queueNext")
            Button(role: config.queueRole,
                   action: addVideoToBottomQueue,
                   label: {
                    Image(systemName: Const.queueBottomSF)
                   })
                .tint(theme.color.mix(with: Color.black, by: 0.3))
                .accessibilityLabel("queueLast")
            if config.isNew == true {
                Button(action: toggleIsNew) {
                    Image(systemName: Const.removeNewSF)
                }
                .tint(theme.color.mix(with: Color.black, by: 0.5))
                .accessibilityLabel("removeIsNew")
            }
        }
    }
}

struct TrailingSwipeActionsView: View {
    @Environment(NavigationManager.self) private var navManager
    @Environment(\.modelContext) var modelContext

    var videoData: VideoData
    var theme: ThemeColor
    var config: VideoListItemConfig
    var clearVideoEverywhere: () -> Void
    var setWatched: (Bool) -> Void
    var addVideoToTopQueue: () -> Void
    var addVideoToBottomQueue: () -> Void
    var toggleBookmark: () -> Void
    var toggleIsNew: () -> Void
    var moveToInbox: () -> Void
    var clearList: (ClearList, ClearDirection) -> Void
    var canBeCleared: Bool
    var deleteVideo: () -> Void

    var body: some View {
        Group {
            if canBeCleared {
                Button(
                    "clearVideo",
                    systemImage: Const.clearSF,
                    role: config.clearRole,
                    action: clearVideoEverywhere
                )
                .labelStyle(.iconOnly)
                .tint(theme.color.mix(with: Color.black, by: 0.9))
            }
            #if os(iOS)
            moreMenu
            #endif
            Button {
                guard let video = VideoService.getVideoModel(
                    from: videoData,
                    modelContext: modelContext
                ) else {
                    Log.error("No video to show details for")
                    return
                }
                navManager.videoDetail = video
                video.isNew = false
            } label: {
                Image(systemName: "text.bubble.fill")
            }
            .tint(theme.color.mix(with: Color.black, by: 0.5))
            .accessibilityLabel("videoDescription")
        }
    }

    var moreMenu: some View {
        Menu {
            VideoListItemMoreMenuView(
                videoData: videoData,
                config: config,
                setWatched: setWatched,
                addVideoToTopQueue: addVideoToTopQueue,
                addVideoToBottomQueue: addVideoToBottomQueue,
                clearVideoEverywhere: clearVideoEverywhere,
                canBeCleared: canBeCleared,
                toggleBookmark: toggleBookmark,
                toggleIsNew: toggleIsNew,
                moveToInbox: moveToInbox,
                openUrlInApp: { urlString in
                    navManager.openUrlInApp(.url(urlString))
                },
                clearList: clearList,
                deleteVideo: deleteVideo
            )
        } label: {
            Image(systemName: "ellipsis.circle.fill")
        }
        .tint(theme.color.mix(with: Color.black, by: 0.7))
    }
}

enum ClearDirection {
    case above
    case below
}

#Preview {
    let container = DataProvider.previewContainerFilled
    let context = ModelContext(container)
    let fetch = FetchDescriptor<Video>()
    let videos = try? context.fetch(fetch)
    guard let video = videos?.first else {
        return Text("noVideoFound")
    }

    return List {
        VideoListItem(
            video,
            config: VideoListItemConfig(
                hasInboxEntry: true,
                hasQueueEntry: true,
                watched: true,
                isNew: true,
                clearAboveBelowList: .inbox
            )
        )
        .listRowSeparator(.hidden)
    }
    .listStyle(.plain)
    .modelContainer(container)
    .environment(NavigationManager())
    .environment(PlayerManager())
    .environment(ImageCacheManager())
}
