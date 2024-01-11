//
//  WatchHistoryView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct WatchHistoryView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \WatchEntry.date, order: .reverse) var watchEntries: [WatchEntry]
    @Query var queue: [QueueEntry]

    func addVideoToQueue(_ video: Video) {
        VideoService.insertQueueEntries(at: 0,
                                        videos: [video],
                                        modelContext: modelContext)
    }

    var body: some View {
        ZStack {
            if watchEntries.isEmpty {
                BackgroundPlaceholder(systemName: "checkmark.circle.fill")
            } else {
                List {
                    ForEach(watchEntries) { entry in
                        VideoListItem(video: entry.video, showVideoStatus: true)
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
            }
        }
        .navigationBarTitle("Watched", displayMode: .inline)
    }
}

// #Preview {
//    WatchHistoryView()
// }
