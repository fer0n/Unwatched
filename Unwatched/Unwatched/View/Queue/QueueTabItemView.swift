//
//  QueueTabItemView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct QueueTabItemView: View {
    let showCancelButton: Bool
    let showBadge: Bool
    let horizontalpadding: CGFloat

    var body: some View {
        QueueView(showCancelButton: showCancelButton)
            .padding(.horizontal, horizontalpadding)
            .modifier(QueueTabItemViewModifier(showBadge: showBadge))
    }
}

struct QueueTabItemViewModifier: ViewModifier {
    @Query(QueueTabItemViewModifier.descriptor)
    var queue: [QueueEntry]

    let showBadge: Bool

    func body(content: Content) -> some View {
        content
            .tabItemView(
                image: Image(systemName: Const.queueTagSF),
                tag: NavigationTab.queue,
                showBadge: showBadge && hasNewItems
            )
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
