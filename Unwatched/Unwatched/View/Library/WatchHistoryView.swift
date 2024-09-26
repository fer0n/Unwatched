//
//  WatchHistoryView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct WatchHistoryView: View {
    @Query(
        filter: #Predicate<Video> {
            $0.watchedDate != nil
        },
        sort: \Video.watchedDate,
        order: .reverse
    )
    var videos: [Video]

    var body: some View {

        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

            if videos.isEmpty {
                ContentUnavailableView("noHistoryItems",
                                       systemImage: Const.watchedSF,
                                       description: Text("noHistoryItemsDescription"))
            } else {
                List {
                    ForEach(videos) { video in
                        VideoListItem(
                            video,
                            config: VideoListItemConfig(
                                showVideoStatus: true,
                                hasInboxEntry: video.inboxEntry != nil,
                                hasQueueEntry: video.queueEntry != nil,
                                watched: video.watchedDate != nil
                            )
                        )
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
