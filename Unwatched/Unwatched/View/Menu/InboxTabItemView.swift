//
//  InboxTabItemView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct InboxTabItemView: View {
    @Environment(RefreshManager.self) var refresher

    static var descriptor: FetchDescriptor<InboxEntry> {
        var descriptor = FetchDescriptor<InboxEntry>(
            sortBy: [SortDescriptor(\InboxEntry.date, order: .reverse)]
        )
        descriptor.fetchLimit = Const.inboxFetchLimit
        return descriptor
    }

    @Query(InboxTabItemView.descriptor, animation: .default)
    var inboxEntries: [InboxEntry]

    let showCancelButton: Bool
    let showBadge: Bool
    let horizontalpadding: CGFloat

    var body: some View {
        TabItemView(image: getInboxSymbol,
                    tag: NavigationTab.inbox,
                    showBadge: showBadge && hasNewItems) {
            InboxView(inboxEntries: inboxEntries,
                      showCancelButton: showCancelButton)
                .padding(.horizontal, horizontalpadding)
        }
    }

    var getInboxSymbol: Image {
        let isLoading = refresher.isLoading
        let isEmpty = inboxEntries.isEmpty

        let full = isEmpty ? "" : ".full"
        if !isLoading {
            return Image(systemName: "tray\(full)")
        }

        return Image("custom.tray.loading.fill")
    }

    var hasNewItems: Bool {
        inboxEntries.contains(where: { $0.video?.isNew == true })
    }
}
