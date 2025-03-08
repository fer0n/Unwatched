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
    var deleteVideo: () -> Void
    var viewChannel: (() -> Void)?

    var body: some View {
        #if os(iOS)
        ControlGroup {
            videoActions
        }
        .controlGroupStyle(.menu)
        #else
        videoActions
        Divider()
        Button("viewChannel") {
            viewChannel?()
        }
        Divider()
        #endif

        Button(action: toggleBookmark) {
            if videoData.bookmarkedDate != nil {
                Label("removeBookmark", systemImage: "bookmark.slash.fill")
            } else {
                Label("addBookmark", systemImage: "bookmark.fill")
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
            Button("openInAppBrowser", systemImage: Const.appBrowserSF) {
                openUrlInApp(url.absoluteString)
            }
        }

        ShareLink(item: UrlService.getShortenedUrl(videoData.youtubeId))

            .tint(Color.automaticBlack)

        ClearAboveBelowButtons(clearList: clearList, config: config, videoId: videoData.youtubeId)
            .tint(.red)

        if config.showDelete {
            Divider()

            ConfirmableMenuButton(helperText: "reallyDeleteVideo") {
                deleteVideo()
            } label: {
                Label("delete", systemImage: "trash")
                    .foregroundStyle(.red, .red, .red)
            }
        }
    }

    @ViewBuilder
    var videoActions: some View {
        Button("markWatched", systemImage: "checkmark", action: { setWatched(true) })

        Button("queueNext",
               systemImage: Const.queueTopSF,
               action: addVideoToTopQueue
        )

        Button("queueLast",
               systemImage: Const.queueBottomSF,
               action: addVideoToBottomQueue
        )
        Button(
            "clearVideo",
            systemImage: Const.clearNoFillSF,
            action: clearVideoEverywhere
        )
        .disabled(!canBeCleared)
    }
}

struct ClearAboveBelowButtons: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(\.scrollViewProxy) var scrollProxy
    @AppStorage(Const.requireClearConfirmation) var requireClearConfirmation: Bool = true

    var clearList: (ClearList, ClearDirection) -> Void
    var config: VideoListItemConfig
    var videoId: String

    var body: some View {
        if let list = config.clearAboveBelowList {
            if requireClearConfirmation {
                ConfirmableMenuButton {
                    clearAbove(list)
                } label: {
                    Label("clearAbove", systemImage: "arrowtriangle.up.fill")
                }

                ConfirmableMenuButton {
                    clearBelow(list)
                } label: {
                    Label("clearBelow", systemImage: "arrowtriangle.down.fill")
                }
            } else {
                Button(role: .destructive) {
                    clearAbove(list)
                } label: {
                    Label("clearAbove", systemImage: "arrowtriangle.up.fill")
                }
                Button(role: .destructive) {
                    clearBelow(list)
                } label: {
                    Label("clearBelow", systemImage: "arrowtriangle.down.fill")
                }
            }
        }
    }

    func clearAbove(_ list: ClearList) {
        withAnimation {
            clearList(list, .above)
        }
        navManager.setScrollId(videoId, list.rawValue)
        if let topElementId = navManager.topListItemId {
            Task {
                try? await Task.sleep(s: 0.3)
                withAnimation {
                    scrollProxy?.scrollTo(topElementId, anchor: .top)
                }
            }
        }
    }

    func clearBelow(_ list: ClearList) {
        withAnimation {
            clearList(list, .below)
        }
    }
}
