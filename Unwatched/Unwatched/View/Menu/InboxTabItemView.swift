//
//  InboxTabItemView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct InboxTabItemView: View {
    let showCancelButton: Bool

    var body: some View {
        InboxView(showCancelButton: showCancelButton)
            .modifier(InboxTabItemViewModifier())
    }
}

/// Auto-clears the "new" status when entering/leaving the inbox tab.
struct InboxTabItemViewModifier: ViewModifier {
    @Query(InboxTabItemViewModifier.descriptorNew)
    var newInboxEntry: [InboxEntry]

    func body(content: Content) -> some View {
        content
            .autRemoveNewViewModifier(hasNewItems: hasNewItems, list: .inbox)
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

/// Tab-bar label for the inbox: a tray icon that reflects loading/empty state.
struct InboxTabLabel: View {
    @Environment(RefreshManager.self) var refresher

    @Query(InboxTabItemViewModifier.descriptorAny)
    var anyInboxEntry: [InboxEntry]

    var body: some View {
        MenuTabLabel(
            image: getInboxSymbol,
            tag: .inbox
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
}
