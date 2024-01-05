//
//  QueueView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct QueueView: View {
    @Environment(VideoManager.self) var videoManager
    @Environment(\.modelContext) var modelContext

    var onVideoTap: (_ video: Video) -> Void
    @Query(sort: \Video.publishedDate, order: .reverse) var videos: [Video]
    @Query var subscriptions: [Subscription]

    var body: some View {
        List(videos) { video in
            VideoListItem(video: video)
                .onTapGesture {
                    onVideoTap(video)
                }
        }
        .refreshable {
            let subVideos = await videoManager.loadVideos(subscriptions: subscriptions)
            videoManager.insertSubscriptionVideos(subVideos, insertVideo: { video in
                modelContext.insert(video)
            })
        }
        .clipped()
        .listStyle(PlainListStyle())
    }
}

#Preview {
    QueueView(onVideoTap: { _ in })
}
