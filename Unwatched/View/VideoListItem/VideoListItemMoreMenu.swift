//
//  VideoListItemMoreMenu.swift
//  Unwatched
//

import SwiftUI

struct VideoListItemMoreMenuView: View {
    @AppStorage(Const.requireClearConfirmation) var requireClearConfirmation: Bool = true

    var video: Video
    var theme: ThemeColor
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
            if let list = config.clearAboveBelowList {
                clearButtons(list)
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
        }
    }

    func clearButtons(_ list: ClearList) -> some View {
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
