import SwiftUI
import SwiftData
import UnwatchedShared

struct AllVideosView: View {
    @AppStorage(Const.allVideosSortOrder) var allVideosSortOrder: VideoSorting = .publishedDate

    @Query(animation: .default) var videos: [Video]

    @State var text = DebouncedText(0.5)
    let sortingOptions: [VideoSorting] = [.publishedDate, .clearedInboxDate]

    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

            SearchableVideos(text: $text)
            ContentUnavailableView("noVideosYet",
                                   systemImage: Const.allVideosViewSF,
                                   description: Text("noVideosYetDescription"))
                .opacity(videos.isEmpty ? 1 : 0)
            List {
                VideoListView(
                    sort: allVideosSortOrder,
                    searchText: text.debounced
                )
            }
            .listStyle(.plain)
            .opacity(videos.isEmpty ? 0 : 1)
        }
        .myNavigationTitle("allVideos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(sortingOptions, id: \.self) { sort in
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
                .accessibilityLabel("videoSorting")
            }
        }
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
