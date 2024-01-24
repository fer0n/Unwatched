//
//  WatchHistoryView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct WatchHistoryView: View {
    @Environment(NavigationManager.self) var navManager
    @Query(sort: \WatchEntry.date, order: .reverse) var watchEntries: [WatchEntry]

    var body: some View {

        ZStack {
            if watchEntries.isEmpty {
                ContentUnavailableView("noHistoryItems",
                                       systemImage: Const.watchedSF,
                                       description: Text("noHistoryItemsDescription"))
            } else {
                List {
                    ForEach(watchEntries.indices, id: \.self) { index in
                        let entry = watchEntries[index]
                        VideoListItem(video: entry.video,
                                      showVideoStatus: true,
                                      hasInboxEntry: entry.video.inboxEntry != nil,
                                      hasQueueEntry: entry.video.queueEntry != nil,
                                      watched: entry.video.watched,
                                      videoSwipeActions: [.queueTop, .clear])
                            .id(NavigationManager.getScrollId(entry.video.youtubeId, "history"))
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("watched")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            navManager.setScrollId(watchEntries.first?.video.youtubeId, "history")
        }
    }
}

// #Preview {
//    WatchHistoryView()
// }
