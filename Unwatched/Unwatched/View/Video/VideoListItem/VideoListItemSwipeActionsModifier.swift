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
                    addVideoToBottomQueue: addVideoToBottomQueue
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
                    moveToInbox: moveToInbox,
                    clearList: clearList,
                    canBeCleared: canBeCleared
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
                                moveToInbox: moveToInbox,
                                openUrlInApp: { urlString in
                                    navManager.openUrlInApp(.url(urlString))
                                },
                                clearList: clearList
                            )
                        })
                    : nil
            )
            .menuOrder(.priority) // <- not working inside lists
            .symbolVariant(.fill)
    }

    func getVideo() -> Video? {
        VideoService.getVideoModel(
            from: videoData,
            modelContext: modelContext
        )
    }

    var canBeCleared: Bool {
        config.videoSwipeActions.contains(.clear) &&
            (config.hasInboxEntry == true
                || config.hasQueueEntry == true
                || [NavigationTab.queue, NavigationTab.inbox].contains(navManager.tab)
            )
    }

    func performVideoAction(
        asyncAction: ((PersistentIdentifier) -> (Task<Void, Error>)?)?,
        syncAction: ((Video) -> Void)?
    ) {
        Logger.log.info("performVideoAction")

        var order = videoData.queueEntryData?.order
        var task: Task<Void, Error>?
        if config.async, let videoId = videoData.persistentId {
            task = asyncAction?(videoId)
            Task {
                try? await task?.value
                config.onChange?()
            }
        } else {
            guard let video = getVideo() else {
                Logger.log.error("performVideoAction: no video")
                return
            }
            order = order ?? video.queueEntry?.order
            syncAction?(video)
            config.onChange?()
        }
        handlePotentialQueueChange(after: task, order: order)
    }

    func addVideoToTopQueue() {
        Logger.log.info("addVideoTop")
        performVideoAction(
            asyncAction: { videoId in
                VideoService.insertQueueEntriesAsync(
                    at: 1,
                    videoIds: [videoId],
                    container: modelContext.container
                )
            },
            syncAction: { video in
                VideoService.insertQueueEntries(
                    at: 1,
                    videos: [video],
                    modelContext: modelContext
                )
            }
        )
    }

    func addVideoToBottomQueue() {
        Logger.log.info("addVideoBottom")
        performVideoAction(
            asyncAction: { videoId in
                VideoService.addToBottomQueueAsync(
                    videoId: videoId,
                    container: modelContext.container
                )
            },
            syncAction: { video in
                VideoService.addToBottomQueue(
                    video: video,
                    modelContext: modelContext
                )
            }
        )
    }

    func moveToInbox() {
        Logger.log.info("moveToInbox")
        performVideoAction(
            asyncAction: { videoId in
                VideoService.moveVideoToInboxAsync(
                    videoId,
                    container: modelContext.container
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

    func toggleBookmark() {
        Logger.log.error("toggleBookmark: no video")
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

    func setWatched(_ watched: Bool) {
        performVideoAction(
            asyncAction: { videoId in
                VideoService.setVideoWatchedAsync(
                    videoId,
                    watched: watched,
                    container: modelContext.container
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
            asyncAction: { videoId in
                VideoService.clearEntriesAsync(
                    from: videoId,
                    updateCleared: true,
                    container: modelContext.container
                )
            },
            syncAction: { video in
                VideoService.clearEntries(
                    from: video,
                    updateCleared: true,
                    modelContext: modelContext
                )
            }
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
            Logger.log.error("clearList: no video")
            return
        }
        let container = modelContext.container
        let task = VideoService.clearList(
            list,
            direction,
            index: video.queueEntry?.order,
            date: video.inboxEntry?.date,
            container: container)
        if list == .queue && direction == .above {
            player.loadTopmostVideoFromQueue(after: task)
        }
        config.onChange?()
    }
}

struct LeadingSwipeActionsView: View {
    var theme: ThemeColor
    var config: VideoListItemConfig
    var addVideoToTopQueue: () -> Void
    var addVideoToBottomQueue: () -> Void

    var body: some View {
        Group {
            if config.videoSwipeActions.contains(.queueTop) {
                Button(role: config.queueRole,
                       action: addVideoToTopQueue,
                       label: {
                        Image(systemName: Const.queueTopSF)
                       })
                    .tint(theme.color.mix(with: Color.black, by: 0.1))
                    .accessibilityLabel("queueNext")
            }
            if config.videoSwipeActions.contains(.queueBottom) {
                Button(role: config.queueRole,
                       action: addVideoToBottomQueue,
                       label: {
                        Image(systemName: Const.queueBottomSF)
                       })
                    .tint(theme.color.mix(with: Color.black, by: 0.3))
                    .accessibilityLabel("queueLast")
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
    var moveToInbox: () -> Void
    var clearList: (ClearList, ClearDirection) -> Void
    var canBeCleared: Bool

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
            if config.videoSwipeActions.contains(.more) {
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
                        moveToInbox: moveToInbox,
                        openUrlInApp: { urlString in
                            navManager.openUrlInApp(.url(urlString))
                        },
                        clearList: clearList
                    )
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                }
                .tint(theme.color.mix(with: Color.black, by: 0.7))
            }
            if config.videoSwipeActions.contains(.details) {
                Button {
                    guard let video = VideoService.getVideoModel(
                        from: videoData,
                        modelContext: modelContext
                    ) else {
                        Logger.log.error("No video to show details for")
                        return
                    }
                    navManager.videoDetail = video
                } label: {
                    Image(systemName: Const.videoDescriptionSF)
                }
                .tint(theme.color.mix(with: Color.black, by: 0.5))
                .accessibilityLabel("videoDescription")
            }
        }
    }
}

enum ClearDirection {
    case above
    case below
}

#Preview {
    let container = DataController.previewContainerFilled
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
                showVideoStatus: true,
                hasInboxEntry: true,
                hasQueueEntry: true,
                watched: true,
                clearAboveBelowList: .inbox
            )
        )
    }
    .listStyle(.plain)
    .modelContainer(container)
    .environment(NavigationManager())
    .environment(PlayerManager())
    .environment(ImageCacheManager())
}
