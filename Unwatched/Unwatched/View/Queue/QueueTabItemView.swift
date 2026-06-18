//
//  QueueTabItemView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct QueueTabItemView: View {
    let showCancelButton: Bool

    var body: some View {
        QueueView(showCancelButton: showCancelButton)
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

    @Query(QueueTabItemViewModifier.descriptor)
    var queue: [QueueEntry]

    var body: some View {
        MenuTabLabel(
            image: Image(systemName: Const.queueTagSF),
            tag: .queue,
            showBadge: showTabBarBadge && !queue.isEmpty
        )
    }
}
