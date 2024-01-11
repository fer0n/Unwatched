import SwiftUI
import SwiftData

struct AllVideosView: View {
    @Query(sort: \Video.publishedDate, order: .reverse) var videos: [Video]

    var body: some View {
        ZStack {
            if videos.isEmpty {
                BackgroundPlaceholder(systemName: "checkmark.circle.fill")
            } else {
                List {
                    ForEach(videos) { video in
                        VideoListItem(video: video, showVideoStatus: true, videoSwipeActions: [.queue, .clear])
                    }
                }
                .listStyle(.plain)
                .toolbarBackground(Color.backgroundColor, for: .navigationBar)
            }
        }
        .navigationBarTitle("All Videos", displayMode: .inline)
    }
}
