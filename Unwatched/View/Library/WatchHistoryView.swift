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
            Color.backgroundColor.ignoresSafeArea(.all)

            if watchEntries.isEmpty {
                ContentUnavailableView("noHistoryItems",
                                       systemImage: Const.watchedSF,
                                       description: Text("noHistoryItemsDescription"))
            } else {
                List {
                    ForEach(watchEntries) { entry in
                        ZStack {
                            if let video = entry.video {
                                VideoListItem(
                                    video,
                                    config: VideoListItemConfig(
                                        showVideoStatus: true,
                                        hasInboxEntry: video.inboxEntry != nil,
                                        hasQueueEntry: video.queueEntry != nil,
                                        watched: video.watched
                                    )
                                )
                            }
                        }
                    }
                    .listRowBackground(Color.backgroundColor)
                }
                .listStyle(.plain)
            }
        }
        .myNavigationTitle("watched")
    }
}

#Preview {
    WatchHistoryView()
        .modelContainer(DataController.previewContainer)
        .environment(ImageCacheManager())
}
