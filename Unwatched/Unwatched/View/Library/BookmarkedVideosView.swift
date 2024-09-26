import SwiftUI
import SwiftData
import UnwatchedShared

struct BookmarkedVideosView: View {

    @Query(filter: #Predicate<Video> { $0.bookmarkedDate != nil },
           sort: \Video.bookmarkedDate, order: .reverse,
           animation: .default)
    var videos: [Video]

    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

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
                                watched: video.watchedDate != nil
                            )
                        )
                    }
                    .listRowBackground(Color.backgroundColor)
                }
                .listStyle(.plain)
            }
        }
        .myNavigationTitle("bookmarkedVideos")
    }
}

#Preview {
    BookmarkedVideosView()
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
        .environment(RefreshManager())
        .environment(PlayerManager())
}
