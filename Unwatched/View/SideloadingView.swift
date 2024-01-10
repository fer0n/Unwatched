import SwiftUI
import SwiftData

struct SideloadingView: View {
    @Environment(\.modelContext) var modelContext
    @Query(filter: #Predicate<Video> { $0.subscription == nil }) var sideloadedVideos: [Video]
    @Query var queue: [QueueEntry]

    func addVideoToQueue(_ video: Video) {
        VideoService.insertQueueEntries(at: 0,
                                        videos: [video],
                                        modelContext: modelContext)
    }

    var body: some View {
        ZStack {
            if sideloadedVideos.isEmpty {
                Text("No sideloaded videos found")
            } else {
                List {
                    ForEach(sideloadedVideos) { video in
                        VideoListItem(video: video, showVideoStatus: true)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    addVideoToQueue(video)
                                } label: {
                                    Image(systemName: "text.badge.plus")
                                }
                                .tint(.teal)
                            }
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
