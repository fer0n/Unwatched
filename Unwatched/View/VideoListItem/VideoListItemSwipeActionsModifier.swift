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
                    toggleBookmark: toggleBookmark,
                    moveToInbox: moveToInbox,
                    clearList: clearList
                )
            }
    }

    func addVideoToTopQueue() {
        Logger.log.info("addVideoTop")
        let order = video.queueEntry?.order
        let task = VideoService.insertQueueEntries(
            at: 1,
            videos: [video],
            modelContext: modelContext
        )
        handlePotentialQueueChange(after: task, order: order)
        config.onChange?()
    }

    func addVideoToBottomQueue() {
        Logger.log.info("addVideoBottom")
        let order = video.queueEntry?.order
        let task = VideoService.addToBottomQueue(video: video, modelContext: modelContext)
        handlePotentialQueueChange(after: task, order: order)
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
        let task = VideoService.markVideoWatched(video, modelContext: modelContext)
        handlePotentialQueueChange(after: task)
        config.onChange?()
    }

    func clearVideoEverywhere() {
        let order = video.queueEntry?.order
        let task = VideoService.clearFromEverywhere(
            video,
            updateCleared: true,
            modelContext: modelContext
        )
        handlePotentialQueueChange(after: task, order: order)
        config.onChange?()
    }

    func handlePotentialQueueChange(after task: Task<(), Error>, order: Int? = nil) {
        if order == 0 || video.queueEntry?.order == 0 {
            player.loadTopmostVideoFromQueue(after: task)
        }
    }

    func clearList(_ list: ClearList, _ direction: ClearDirection) {
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
                Button(action: addVideoToTopQueue) {
                    Image(systemName: "text.insert")
                }
                .tint(theme.color.mix(with: Color.black, by: 0.1))
            }
            if config.videoSwipeActions.contains(.queueBottom) {
                Button(action: addVideoToBottomQueue) {
                    Image(systemName: "text.append")
                }
                .tint(theme.color.mix(with: Color.black, by: 0.3))
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
    var toggleBookmark: () -> Void
    var moveToInbox: () -> Void
    var clearList: (ClearList, ClearDirection) -> Void

    var body: some View {
        Group {
            if config.videoSwipeActions.contains(.clear) &&
                (config.hasInboxEntry == true
                    || config.hasQueueEntry == true
                    || [NavigationTab.queue, NavigationTab.inbox].contains(navManager.tab)
                ) {
                Button(role: config.clearRole,
                       action: clearVideoEverywhere,
                       label: {
                        Image(systemName: Const.clearSF)
                       })
                    .tint(theme.color.mix(with: Color.black, by: 0.9))
            }
            if config.videoSwipeActions.contains(.more) {
                VideoListItemMoreMenuView(
                    video: video,
                    theme: theme,
                    config: config,
                    markWatched: markWatched,
                    toggleBookmark: toggleBookmark,
                    moveToInbox: moveToInbox,
                    openUrlInApp: { urlString in
                        navManager.openUrlInApp(.url(urlString))
                    },
                    clearList: clearList
                )
                .tint(theme.color.mix(with: Color.black, by: 0.7))
            }
            if config.videoSwipeActions.contains(.details) {
                Button {
                    navManager.videoDetail = video
                } label: {
                    Image(systemName: Const.videoDescriptionSF)
                }
                .tint(theme.color.mix(with: Color.black, by: 0.5))
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
    let container = DataController.previewContainer
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
                hasInboxEntry: false,
                hasQueueEntry: true,
                watched: true
            )
        )
    }
    .listStyle(.plain)
    .modelContainer(container)
    .environment(NavigationManager())
    .environment(PlayerManager())
    .environment(ImageCacheManager())
}
