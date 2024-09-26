//
//  InboxTabItemView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct InboxTabItemView: View {
    @AppStorage(Const.newInboxItemsCount) var newInboxItemsCount: Int = 0
    @Environment(RefreshManager.self) var refresher
    @Environment(NavigationManager.self) var navManager
    @Query(sort: \InboxEntry.date, order: .reverse, animation: .default) var inboxEntries: [InboxEntry]

    let showCancelButton: Bool
    let showBadge: Bool

    var body: some View {
        TabItemView(image: getInboxSymbol,
                    text: "inbox",
                    tag: NavigationTab.inbox,
                    showBadge: showBadge && newInboxItemsCount > 0 && inboxEntries.count > 0) {
            InboxView(inboxEntries: inboxEntries,
                      showCancelButton: showCancelButton)
        }
    }

    @MainActor
    var getInboxSymbol: Image {
        let isLoading = refresher.isLoading
        let isEmpty = inboxEntries.isEmpty
        let currentTab = navManager.tab == .inbox

        let full = isEmpty ? "" : ".full"
        if !isLoading {
            return Image(systemName: "tray\(full)")
        }

        let fill = currentTab ? ".fill" : ""
        return Image("custom.tray.loading\(fill)")
    }
}
