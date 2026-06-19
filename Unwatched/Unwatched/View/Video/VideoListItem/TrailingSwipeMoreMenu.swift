//
//  TrailingSwipeMoreMenu.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct TrailingSwipeMoreMenu: View {
    @Environment(NavigationManager.self) private var navManager

    var videoData: VideoData
    var theme: ThemeColor
    var config: VideoListItemConfig
    var setWatched: (Bool) -> Void
    var addVideoToTopQueue: () -> Void
    var addVideoToBottomQueue: () -> Void
    var clearVideoEverywhere: () -> Void
    var canBeCleared: Bool
    var toggleBookmark: () -> Void
    var toggleIsNew: () -> Void
    var moveToInbox: () -> Void
    var clearList: (ClearList, ClearDirection) -> Void
    var deleteVideo: () -> Void

    var body: some View {
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
            Image(systemName: "ellipsis")
        }
        .tint(theme.color.mix(with: Color.black, by: 0.5))
    }
}
