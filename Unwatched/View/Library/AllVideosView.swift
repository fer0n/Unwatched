import SwiftUI
import SwiftData

struct AllVideosView: View {
    @AppStorage(Const.handleShortsDifferently) var handleShortsDifferently: Bool = false
    @AppStorage(Const.hideShortsEverywhere) var hideShortsEverywhere: Bool = false
    @AppStorage(Const.shortsDetection) var shortsDetection: ShortsDetection = .safe
    @AppStorage(Const.allVideosSortOrder) var allVideosSortOrder: VideoSorting = .publishedDate

    @Query(animation: .default) var videos: [Video]
    @State var text = DebouncedText(0.5)

    var body: some View {
        ZStack {
            SearchableVideos(text: $text)
            if videos.isEmpty {
                ContentUnavailableView("noVideosYet",
                                       systemImage: "play.rectangle.on.rectangle",
                                       description: Text("noVideosYetDescription"))
            } else {
                List {
                    VideoListView(
                        ytShortsFilter: shortsFilter,
                        sort: allVideosSortOrder,
                        searchText: text.debounced
                    )
                }
                .listStyle(.plain)
            }
        }
        .task(id: text.val) {
            await text.handleDidSet()
        }
        .navigationTitle("allVideos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(VideoSorting.allCases, id: \.self) { sort in
                        Button {
                            allVideosSortOrder = sort
                        } label: {
                            HStack {
                                Image(systemName: sort.systemName)
                                Text(sort.description)
                            }
                        }
                        .disabled(allVideosSortOrder == sort)
                    }
                } label: {
                    Image(systemName: allVideosSortOrder == .publishedDate
                            ? Const.filterEmptySF
                            : Const.filterSF)
                }
            }
        }
    }

    var shortsFilter: ShortsDetection? {
        (handleShortsDifferently && hideShortsEverywhere) ? shortsDetection : nil
    }
}

#Preview {
    NavigationStack {
        AllVideosView()
            .modelContainer(DataController.previewContainer)
            .environment(NavigationManager())
            .environment(RefreshManager())
            .environment(PlayerManager())
            .environment(ImageCacheManager())
    }
}
