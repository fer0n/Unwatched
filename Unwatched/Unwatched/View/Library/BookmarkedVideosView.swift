import SwiftUI
import SwiftData
import UnwatchedShared

struct BookmarkedVideosView: View {

    @State var videoListVM = VideoListVM()

    var body: some View {
        ZStack {
            MyBackgroundColor()

            if videoListVM.hasNoVideos {
                ContentUnavailableView("noBookmarkedVideosYet",
                                       systemImage: "bookmark.slash.fill",
                                       description: Text("noBookmarkedVideosYetDescription"))
            } else {
                VideosViewAsync(
                    videoListVM: $videoListVM,
                    sorting: [SortDescriptor<Video>(\.bookmarkedDate, order: .reverse)],
                    filter: #Predicate<Video> { $0.bookmarkedDate != nil }
                )
                .listStyle(.plain)
            }
        }
        .concentricMacWorkaround()
        .myNavigationTitle("bookmarkedVideos")
    }
}

#Preview {
    BookmarkedVideosView()
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager())
        .environment(RefreshManager())
        .environment(PlayerManager())
}
