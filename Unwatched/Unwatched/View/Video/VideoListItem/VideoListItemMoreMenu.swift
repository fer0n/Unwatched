//
//  VideoListItemMoreMenu.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct VideoListItemMoreMenuView: View {
    var videoData: VideoData
    var config: VideoListItemConfig
    var setWatched: (Bool) -> Void
    var addVideoToTopQueue: () -> Void
    var addVideoToBottomQueue: () -> Void
    var clearVideoEverywhere: () -> Void
    var canBeCleared: Bool
    var toggleBookmark: () -> Void
    var moveToInbox: () -> Void
    var openUrlInApp: (String) -> Void
    var clearList: (ClearList, ClearDirection) -> Void

    var body: some View {
        ControlGroup {
            Button("markWatched", systemImage: "checkmark", action: { setWatched(true) })

            Button("addVideoToTopQueue",
                   systemImage: Const.queueTopSF,
                   action: addVideoToTopQueue
            )

            Button("addVideoToBottomQueue",
                   systemImage: Const.queueBottomSF,
                   action: addVideoToBottomQueue
            )
            Button(
                "clearVideo",
                systemImage: "xmark",
                action: clearVideoEverywhere
            )
            .disabled(!canBeCleared)

            Button(action: toggleBookmark) {
                let isBookmarked = videoData.bookmarkedDate != nil

                Image(systemName: "bookmark")
                    .environment(\.symbolVariants,
                                 isBookmarked
                                    ? .fill
                                    : .slash.fill)
                if isBookmarked {
                    Text("bookmarked")
                } else {
                    Text("addBookmark")
                }
            }
            if config.watched ?? (videoData.watchedDate != nil) {
                Button {
                    setWatched(false)
                } label: {
                    Label("markUnwatched", image: "custom.checkmark.circle.slash.fill")
                }
            }
            Divider()

            if videoData.hasInboxEntry != true {
                Button("moveToInbox", systemImage: "tray.and.arrow.down", action: moveToInbox)
            }

            if let url = videoData.url {
                Button("openInApp", systemImage: Const.appBrowserSF) {
                    openUrlInApp(url.absoluteString)
                }
                ShareLink(item: url)
            }
        }
        .controlGroupStyle(.compactMenu)
        ClearAboveBelowButtons(clearList: clearList, config: config)
    }
}

struct ClearAboveBelowButtons: View {
    @AppStorage(Const.requireClearConfirmation) var requireClearConfirmation: Bool = true

    var clearList: (ClearList, ClearDirection) -> Void
    var config: VideoListItemConfig

    var body: some View {
        if let list = config.clearAboveBelowList {
            if requireClearConfirmation {
                ConfirmableMenuButton {
                    clearList(list, .above)
                } label: {
                    Label("clearAbove", systemImage: "arrowtriangle.up.fill")
                }

                ConfirmableMenuButton {
                    clearList(list, .below)
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
}
