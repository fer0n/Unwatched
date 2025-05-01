//
//  QueueTabItemView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct QueueTabItemView: View {
    @Query(sort: \QueueEntry.order, animation: .default) var queue: [QueueEntry]

    let showCancelButton: Bool
    let showBadge: Bool
    let horizontalpadding: CGFloat

    var body: some View {
        TabItemView(image: Image(systemName: Const.queueTagSF),
                    tag: NavigationTab.queue,
                    showBadge: showBadge && hasNewItems) {
            QueueView(
                queue: queue,
                showCancelButton: showCancelButton
            )
            .padding(.horizontal, horizontalpadding)
        }
    }

    var hasNewItems: Bool {
        queue.contains(where: { $0.video?.isNew == true })
    }
}
