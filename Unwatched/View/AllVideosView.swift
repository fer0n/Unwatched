import SwiftUI
import SwiftData

struct AllVideosView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Video.publishedDate, order: .reverse) var videos: [Video]

    func addVideoToQueue(_ video: Video) {
        VideoService.insertQueueEntries(at: 0,
                                        videos: [video],
                                        modelContext: modelContext)
    }

    var body: some View {
        ZStack {
            if videos.isEmpty {
                BackgroundPlaceholder(systemName: "checkmark.circle.fill")
            } else {
                List {
                    ForEach(videos) { video in
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
            }
        }
        .navigationBarTitle("All Videos", displayMode: .inline)
    }
}
