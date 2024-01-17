import SwiftUI
import SwiftData

struct AllVideosView: View {
    @Query(sort: \Video.publishedDate, order: .reverse) var videos: [Video]

    var body: some View {
        ZStack {
            if videos.isEmpty {
                ContentUnavailableView("noVideosYet",
                                       systemImage: "play.rectangle.on.rectangle",
                                       description: Text("noVideosYetDescription"))
            } else {
                List {
                    ForEach(videos) { video in
                        VideoListItem(
                            video: video,
                            showVideoStatus: true,
                            hasInboxEntry: video.inboxEntry != nil,
                            hasQueueEntry: video.queueEntry != nil,
                            watched: video.watched,
                            videoSwipeActions: [.queue, .clear])
                    }
                }
                .listStyle(.plain)
                .toolbarBackground(Color.backgroundColor, for: .navigationBar)
            }
        }
        .navigationBarTitle("allVideos", displayMode: .inline)
    }
}
