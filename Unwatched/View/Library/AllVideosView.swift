import SwiftUI
import SwiftData

struct AllVideosView: View {
    @Environment(NavigationManager.self) var navManager
    @AppStorage(Const.handleShortsDifferently) var handleShortsDifferently: Bool = false
    @AppStorage(Const.hideShortsEverywhere) var hideShortsEverywhere: Bool = false
    @AppStorage(Const.shortsDetection) var shortsDetection: ShortsDetection = .safe

    @Query(sort: \Video.publishedDate, order: .reverse) var videos: [Video]

    var body: some View {
        let idPrefix = NavigationManager.getScrollId("all-videos")

        ZStack {
            if videos.isEmpty {
                ContentUnavailableView("noVideosYet",
                                       systemImage: "play.rectangle.on.rectangle",
                                       description: Text("noVideosYetDescription"))
            } else {
                List {
                    VideoListView(ytShortsFilter: shortsFilter, idPrefix: idPrefix)
                }
                .listStyle(.plain)
            }
        }
        .onAppear {
            navManager.topListItemId = "\(idPrefix)-0"
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
