//
//  WatchHistoryView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct WatchHistoryView: View {
    @Query(sort: \WatchEntry.date, order: .reverse) var watchEntries: [WatchEntry]

    var body: some View {
        ZStack {
            if watchEntries.isEmpty {
                ContentUnavailableView("noHistoryItems",
                                       systemImage: "checkmark.circle.fill",
                                       description: Text("noHistoryItemsDescription"))
            } else {
                List {
                    ForEach(watchEntries) { entry in
                        VideoListItem(video: entry.video,
                                      showVideoStatus: true,
                                      hasInboxEntry: entry.video.inboxEntry != nil,
                                      hasQueueEntry: entry.video.queueEntry != nil,
                                      watched: entry.video.watched,
                                      videoSwipeActions: [.queue, .clear])
                    }
                }
                .listStyle(.plain)
                .toolbarBackground(Color.backgroundColor, for: .navigationBar)
            }
        }
        .navigationBarTitle("Watched", displayMode: .inline)
    }
}

// #Preview {
//    WatchHistoryView()
// }
