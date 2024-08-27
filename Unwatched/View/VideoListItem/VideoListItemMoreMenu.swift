//
//  VideoListItemMoreMenu.swift
//  Unwatched
//

import SwiftUI

struct VideoListItemMoreMenuView: View {
    var video: Video
    var config: VideoListItemConfig
    var markWatched: () -> Void
    var toggleBookmark: () -> Void
    var moveToInbox: () -> Void
    var openUrlInApp: (String) -> Void
    var clearList: (ClearList, ClearDirection) -> Void

    var body: some View {
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
            Divider()
            if let url = video.url {
                ShareLink(item: url)

                Button {
                    openUrlInApp(url.absoluteString)
                } label: {
                    Image(systemName: Const.appBrowserSF)
                    Text("openInApp")
                }
            }
            ClearAboveBelowButtons(clearList: clearList, config: config)

        } label: {
            Image(systemName: "ellipsis.circle.fill")
        }
    }

}

struct ClearAboveBelowButtons: View {
    @AppStorage(Const.requireClearConfirmation) var requireClearConfirmation: Bool = true

    var clearList: (ClearList, ClearDirection) -> Void
    var config: VideoListItemConfig

    var body: some View {
        if let list = config.clearAboveBelowList {
            Group {
                Divider()

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
}
