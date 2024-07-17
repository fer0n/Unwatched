//
//  InboxTabItemView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct InboxTabItemView: View {
    @AppStorage(Const.hasNewInboxItems) var hasNewInboxItems: Bool = false
    @Environment(RefreshManager.self) var refresher
    @Environment(NavigationManager.self) var navManager
    @Query(animation: .default) var inbox: [InboxEntry]

    let showCancelButton: Bool
    let showBadge: Bool

    var body: some View {
        TabItemView(image: getInboxSymbol,
                    text: "inbox",
                    tag: NavigationTab.inbox,
                    showBadge: showBadge && hasNewInboxItems) {
            InboxView(showCancelButton: showCancelButton)
        }
    }

    @MainActor
    var getInboxSymbol: Image {
        let isLoading = refresher.isLoading
        let isEmpty = inbox.isEmpty
        let currentTab = navManager.tab == .inbox

        let full = isEmpty ? "" : ".full"
        if !isLoading {
            return Image(systemName: "tray\(full)")
        }

        let fill = currentTab ? ".fill" : ""
        return Image("custom.tray.loading\(fill)")
    }
}
