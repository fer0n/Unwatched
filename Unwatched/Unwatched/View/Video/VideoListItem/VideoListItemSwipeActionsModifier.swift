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
    @Environment(\.swipeActionColor) private var swipeActionColor

    @Environment(PlayerManager.self) var player
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) var navManager
    @Environment(\.videoListContext) var listContext
    @Environment(\.queueFilter) var queueFilter

    let videoData: VideoData
    var config: VideoListItemConfig
    let onChange: ((_ reason: VideoChangeReason?, _ order: Int?) -> Void)?

    private var color: Color {
        swipeActionColor ?? theme.color
    }

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                LeadingSwipeActionsView(
                    color: color,
                    config: config,
                    addVideoToTopQueue: { addVideoToTopQueue(via: "swipe") },
                    addVideoToBottomQueue: { addVideoToBottomQueue(via: "swipe") },
                    toggleIsNew: toggleIsNew,
                    )
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                TrailingSwipeActionsView(
                    videoData: videoData,
                    color: color,
                    config: config,
                    clearVideoEverywhere: clearVideoEverywhere,
                    setWatched: setWatched,
                    addVideoToTopQueue: { addVideoToTopQueue(via: "menu") },
                    addVideoToBottomQueue: { addVideoToBottomQueue(via: "menu") },
                    toggleBookmark: toggleBookmark,
                    toggleIsNew: toggleIsNew,
                    moveToInbox: moveToInbox,
                    clearList: clearList,
                    canBeCleared: canBeCleared,
                    deleteVideo: deleteVideo,
                    deferVideo: deferVideo
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
                                addVideoToTopQueue: { addVideoToTopQueue(via: "menu") },
                                addVideoToBottomQueue: { addVideoToBottomQueue(via: "menu") },
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
                                viewChannel: viewChannel,
                                viewPlaylist: viewPlaylist,
                                deferVideo: deferVideo
                            )
                        })
                    : nil
            )
            #if os(iOS)
            .menuOrder(.priority) // <- not working inside lists
            #endif
            .symbolVariant(.fill)
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
            video.youtubeId,
            config: VideoListItemConfig(
                hasInboxEntry: true,
                hasQueueEntry: true,
                watched: true,
                isNew: true,
                clearAboveBelowList: .inbox
            )
        )
        .equatable()
        .listRowSeparator(.hidden)
    }
    .listStyle(.plain)
    .modelContainer(container)
    .environment(NavigationManager())
    .environment(PlayerManager())
    .environment(ImageCacheManager())
}
