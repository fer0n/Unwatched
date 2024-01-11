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
                        VideoListItem(video: video, showVideoStatus: true, videoSwipeActions: [.queue, .clear])
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
