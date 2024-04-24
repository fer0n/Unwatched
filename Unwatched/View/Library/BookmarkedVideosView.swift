import SwiftUI
import SwiftData

struct BookmarkedVideosView: View {

    @Query(filter: #Predicate<Video> { $0.bookmarkedDate != nil },
           sort: \Video.bookmarkedDate, order: .reverse,
           animation: .default)
    var videos: [Video]

    var body: some View {
        ZStack {
            if videos.isEmpty {
                ContentUnavailableView("noBookmarkedVideosYet",
                                       systemImage: "bookmark.slash.fill",
                                       description: Text("noBookmarkedVideosYetDescription"))
            } else {
                List {
                    ForEach(videos) { video in
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
                .listStyle(.plain)
            }
        }
        .navigationTitle("bookmarkedVideos")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    BookmarkedVideosView()
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
        .environment(RefreshManager())
        .environment(PlayerManager())
}
