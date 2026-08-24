//
//  QueueTabItemView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct QueueTabItemView: View {
    var body: some View {
        QueueView()
            .modifier(QueueTabItemViewModifier())
    }
}

/// Auto-clears the "new" status when entering/leaving the queue tab.
struct QueueTabItemViewModifier: ViewModifier {
    @Query(QueueTabItemViewModifier.descriptor)
    var queue: [QueueEntry]

    func body(content: Content) -> some View {
        content
            .autRemoveNewViewModifier(hasNewItems: hasNewItems, list: .queue)
    }

    var hasNewItems: Bool {
        !queue.isEmpty
    }

    static var descriptor: FetchDescriptor<QueueEntry> {
        var descriptor = FetchDescriptor<QueueEntry>(
            predicate: #Predicate<QueueEntry> { $0.video?.isNew == true }
        )
        descriptor.fetchLimit = 1
        return descriptor
    }
}

/// Tab-bar label for the queue, showing a badge dot when the queue has new items.
struct QueueTabLabel: View {
    @AppStorage(Const.showTabBarBadge) var showTabBarBadge = true
    @Environment(NavigationManager.self) private var navManager

    @Query(QueueTabItemViewModifier.descriptor)
    var queue: [QueueEntry]
    @Query(sort: \Tag.order) private var tags: [Tag]

    var body: some View {
        MenuTabLabel(
            image: Image(systemName: symbol),
            tag: .queue,
            showBadge: showTabBarBadge && !queue.isEmpty
        )
    }

    /// Only a symbol the user picked for the tag, the default one says no more than the queue's own
    private var symbol: String {
        navManager.queueTag.tag(in: tags)?.symbol ?? Const.queueTagSF
    }
}
