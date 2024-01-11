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
                BackgroundPlaceholder(systemName: "checkmark.circle.fill")
            } else {
                List {
                    ForEach(watchEntries) { entry in
                        VideoListItem(video: entry.video, showVideoStatus: true, videoSwipeActions: [.queue, .clear])
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
