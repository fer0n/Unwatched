import SwiftUI
import SwiftData

struct AllVideosView: View {
    @AppStorage(Const.handleShortsDifferently) var handleShortsDifferently: Bool = false
    @AppStorage(Const.hideShortsEverywhere) var hideShortsEverywhere: Bool = false
    @AppStorage(Const.shortsDetection) var shortsDetection: ShortsDetection = .safe

    @Query(sort: \Video.publishedDate, order: .reverse) var videos: [Video]

    var body: some View {
        ZStack {
            if videos.isEmpty {
                ContentUnavailableView("noVideosYet",
                                       systemImage: "play.rectangle.on.rectangle",
                                       description: Text("noVideosYetDescription"))
            } else {
                List {
                    VideoListView(ytShortsFilter: shortsFilter)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("allVideos")
        .navigationBarTitleDisplayMode(.inline)
    }

    var shortsFilter: ShortsDetection? {
        (handleShortsDifferently && hideShortsEverywhere) ? shortsDetection : nil
    }
}

#Preview {
    AllVideosView()
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
        .environment(RefreshManager())
        .environment(PlayerManager())
}
