//
//  VideoListItemSwipeActionsModifier.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog

struct VideoListItemSwipeActionsModifier: ViewModifier {
    @AppStorage(Const.themeColor) var theme: ThemeColor = Color.defaultTheme

    @Environment(PlayerManager.self) private var player
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager

    let video: Video
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
                    video: video,
                    theme: theme,
                    config: config,
                    clearVideoEverywhere: clearVideoEverywhere,
                    markWatched: markWatched,
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
                                video: video,
                                config: config,
                                markWatched: markWatched,
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

    var canBeCleared: Bool {
        config.videoSwipeActions.contains(.clear) &&
            (config.hasInboxEntry == true
                || config.hasQueueEntry == true
                || [NavigationTab.queue, NavigationTab.inbox].contains(navManager.tab)
            )
    }

    func addVideoToTopQueue() {
        Logger.log.info("addVideoTop")
        let order = video.queueEntry?.order
        VideoService.insertQueueEntries(
            at: 1,
            videos: [video],
            modelContext: modelContext
        )
        handlePotentialQueueChange(order: order)
        config.onChange?()
    }

    func addVideoToBottomQueue() {
        Logger.log.info("addVideoBottom")
        let order = video.queueEntry?.order
        VideoService.addToBottomQueue(video: video, modelContext: modelContext)
        handlePotentialQueueChange(order: order)
        config.onChange?()
    }

    func moveToInbox() {
        let task = VideoService.moveVideoToInbox(video, modelContext: modelContext)
        handlePotentialQueueChange(after: task)
        config.onChange?()
    }

    func toggleBookmark() {
        VideoService.toggleBookmark(video, modelContext)
        config.onChange?()
    }

    func markWatched() {
        VideoService.markVideoWatched(video, modelContext: modelContext)
        handlePotentialQueueChange()
        config.onChange?()
    }

    func clearVideoEverywhere() {
        let order = video.queueEntry?.order
        VideoService.clearEntries(from: video,
                                  updateCleared: true,
                                  modelContext: modelContext)
        handlePotentialQueueChange(order: order)
        config.onChange?()
        if video.isYtShort == true {
            HideShortsTip.clearedShorts += 1
        }
    }

    func handlePotentialQueueChange(after task: (Task<(), Error>)? = nil, order: Int? = nil) {
        if order == 0 || video.queueEntry?.order == 0 {
            try? modelContext.save()
            player.loadTopmostVideoFromQueue(after: task)
        }
    }

    func clearList(_ list: ClearList, _ direction: ClearDirection) {
        try? modelContext.save()
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

    var video: Video
    var theme: ThemeColor
    var config: VideoListItemConfig
    var clearVideoEverywhere: () -> Void
    var markWatched: () -> Void
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
                        video: video,
                        config: config,
                        markWatched: markWatched,
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

enum ClearList {
    case queue
    case inbox
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
