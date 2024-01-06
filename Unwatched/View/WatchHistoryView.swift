//
//  WatchHistoryView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct WatchHistoryView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \WatchEntry.date) var watchEntries: [WatchEntry]
    @Query var queue: [QueueEntry]

    func addVideoToQueue(_ video: Video) {
        QueueManager.addVideosToQueue(queue,
                                      videos: [video],
                                      insertQueueEntry: { entry in
                                        modelContext.insert(entry)
                                      })
    }

    var body: some View {
        ZStack {
            if watchEntries.isEmpty {
                Text("Nothing marked as watched yet")
            } else {
                List {
                    ForEach(watchEntries) { entry in
                        VideoListItem(video: entry.video)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    addVideoToQueue(entry.video)
                                } label: {
                                    Image(systemName: "text.badge.plus")
                                }
                                .tint(.teal)
                            }
                    }
                }
                .listStyle(.plain)
                .toolbarBackground(Color.backgroundColor, for: .navigationBar)
                .navigationBarTitle("History", displayMode: .inline)
            }
        }

    }
}

// #Preview {
//    WatchHistoryView()
// }
