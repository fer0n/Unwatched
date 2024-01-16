import SwiftUI
import SwiftData

struct SideloadingView: View {
    @Query(filter: #Predicate<Video> { $0.subscription == nil }) var sideloadedVideos: [Video]

    var body: some View {
        ZStack {
            if sideloadedVideos.isEmpty {
                Text("No sideloaded videos found")
            } else {
                List {
                    ForEach(sideloadedVideos) { video in
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
                .navigationBarTitle("Sideloads", displayMode: .inline)
            }
        }
    }
}

// #Preview {
//    WatchHistoryView()
// }
