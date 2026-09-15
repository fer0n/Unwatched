//
//  InboxTabItemView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct InboxTabItemView: View {
    var body: some View {
        InboxView()
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
        let name = Self.symbol(isLoading: refresher.isLoading, isEmpty: anyInboxEntry.isEmpty)
        return refresher.isLoading ? Image(name) : Image(systemName: name)
    }

    static func symbol(isLoading: Bool, isEmpty: Bool) -> String {
        isLoading ? "custom.tray.loading.fill" : isEmpty ? "tray" : "tray.full"
    }
}
