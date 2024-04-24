//
//  VideoListItemSwipeActionsModifier.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog

struct VideoListItemSwipeActionsModifier: ViewModifier {
    @AppStorage(Const.requireClearConfirmation) var requireClearConfirmation: Bool = true

    @Environment(NavigationManager.self) private var navManager
    @Environment(PlayerManager.self) private var player
    @Environment(\.modelContext) var modelContext

    @Binding var showInfo: Bool

    let video: Video
    var config: VideoListItemConfig

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                getLeadingSwipeActions()
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                getTrailingSwipeActions()
            }
    }

    func getLeadingSwipeActions() -> some View {
        Group {
            if config.videoSwipeActions.contains(.queueTop) {
                Button(role: config.queueRole,
                       action: addVideoToTopQueue,
                       label: {
                        Image(systemName: "text.insert")
                       })
                    .tint(.teal)
            }
            if config.videoSwipeActions.contains(.queueBottom) {
                Button(role: config.queueRole,
                       action: addVideoToBottomQueue,
                       label: {
                        Image(systemName: "text.append")
                       })
                    .tint(.mint)
            }
        }
    }

    func getTrailingSwipeActions() -> some View {
        return Group {
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
                    .tint(.black)
            }
            if config.videoSwipeActions.contains(.more) {
                moreMenu
            }
            if config.videoSwipeActions.contains(.details) {
                Button {
                    showInfo = true
                } label: {
                    Image(systemName: Const.videoDescriptionSF)
                }
                .tint(Color(UIColor.lightGray))
            }
        }
    }

    var moreMenu: some View {
        Menu {
            Button(action: markWatched) {
                Image(systemName: Const.watchedSF)
                Text("markWatched")
            }
            Button(action: toggleBookmark) {
                let isBookmarked = video.bookmarkedDate != nil

                Image(systemName: "bookmark")
                    .environment(\.symbolVariants,
                                 isBookmarked
                                    ? .fill
                                    : .none)
                if isBookmarked {
                    Text("bookmarked")
                } else {

                    Text("addBookmark")
                }
            }
            if video.inboxEntry == nil {
                Button(action: moveToInbox) {
                    Image(systemName: "tray.and.arrow.down.fill")
                    Text("moveToInbox")
                }
            }
            if let url = video.url {
                ShareLink(item: url)
            }
            if let list = config.clearAboveBelowList {
                clearButtons(list)
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
        }
        .tint(.gray)
    }

    func clearButtons(_ list: ClearList) -> some View {
        Group {
            Divider()

            if requireClearConfirmation {
                Menu {
                    Button(role: .destructive) {
                        clearList(list, .above)
                    } label: {
                        Image(systemName: "checkmark")
                        Text("confirm")
                    }
                    Button { } label: {
                        Label("cancel", systemImage: "xmark")
                    }
                } label: {
                    Label("clearAbove", systemImage: "arrowtriangle.up.fill")
                }

                Menu {
                    Button(role: .destructive) {
                        clearList(list, .below)
                    } label: {
                        Image(systemName: "checkmark")
                        Text("confirm")
                    }
                    Button { } label: {
                        Label("cancel", systemImage: "xmark")
                    }
                } label: {
                    Label("clearBelow", systemImage: "arrowtriangle.down.fill")
                }
            } else {
                Button(role: .destructive) {
                    clearList(list, .above)
                } label: {
                    Label("clearAbove", systemImage: "arrowtriangle.up.fill")
                }
                Button(role: .destructive) {
                    clearList(list, .below)
                } label: {
                    Label("clearBelow", systemImage: "arrowtriangle.down.fill")
                }
            }
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

    func addVideoToBottomQueue() {
        Logger.log.info("addVideoBottom")
        let order = video.queueEntry?.order
        let task = VideoService.addToBottomQueue(video: video, modelContext: modelContext)
        handlePotentialQueueChange(after: task, order: order)
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

enum ClearDirection {
    case above
    case below
}

enum ClearList {
    case queue
    case inbox
}
