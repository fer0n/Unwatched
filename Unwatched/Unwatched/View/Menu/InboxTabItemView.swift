//
//  InboxTabItemView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct InboxTabItemView: View {
    let showCancelButton: Bool
    let showBadge: Bool
    let horizontalpadding: CGFloat

    var body: some View {
        InboxView(showCancelButton: showCancelButton)
            .padding(.horizontal, horizontalpadding)
            .modifier(InboxTabItemViewModifier(showBadge: showBadge))
    }
}

struct InboxTabItemViewModifier: ViewModifier {
    @Environment(RefreshManager.self) var refresher

    @Query(InboxTabItemViewModifier.descriptorAny)
    var anyInboxEntry: [InboxEntry]

    @Query(InboxTabItemViewModifier.descriptorNew)
    var newInboxEntry: [InboxEntry]

    let showBadge: Bool

    func body(content: Content) -> some View {
        content
            .tabItemView(
                image: getInboxSymbol,
                tag: NavigationTab.inbox,
                showBadge: showBadge && hasNewItems
            )
    }

    var getInboxSymbol: Image {
        let isLoading = refresher.isLoading
        let isEmpty = anyInboxEntry.isEmpty

        let full = isEmpty ? "" : ".full"
        if !isLoading {
            return Image(systemName: "tray\(full)")
        }

        return Image("custom.tray.loading.fill")
    }

    var hasNewItems: Bool {
        !newInboxEntry.isEmpty
    }

    static var descriptorAny: FetchDescriptor<InboxEntry> {
        var descriptor = FetchDescriptor<InboxEntry>()
        descriptor.fetchLimit = 1
        return descriptor
    }

    static var descriptorNew: FetchDescriptor<InboxEntry> {
        var descriptor = FetchDescriptor<InboxEntry>(
            predicate: #Predicate<InboxEntry> { $0.video?.isNew == true }
        )
        descriptor.fetchLimit = 1
        return descriptor
    }
}
