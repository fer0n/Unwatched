import SwiftUI
import SwiftData
import UnwatchedShared

struct AllVideosView: View {
    @State var videoListVM = VideoListVM()
    @State var text = DebouncedText(0.5)

    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)
            #if os(iOS)
            SearchableVideos(text: $text)
            #endif
            ContentUnavailableView("noVideosYet",
                                   systemImage: Const.allVideosViewSF,
                                   description: Text("noVideosYetDescription"))
                .opacity(videoListVM.hasNoVideos ? 1 : 0)
            VStack(spacing: 0) {
                #if os(macOS)
                SearchField(text: $text)
                #endif
                VideosViewAsync(
                    videoListVM: $videoListVM,
                    sorting: [SortDescriptor<Video>(\.publishedDate, order: .reverse)],
                    filter: VideoListView.getVideoFilter()
                )
                .opacity(videoListVM.hasNoVideos ? 0 : 1)
            }
        }
        .onChange(of: text.debounced) {
            videoListVM.setSearchText(text.debounced)
        }
        .myNavigationTitle("allVideos")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    NavigationStack {
        AllVideosView()
            .modelContainer(DataProvider.previewContainer)
            .environment(NavigationManager())
            .environment(RefreshManager())
            .environment(PlayerManager())
            .environment(ImageCacheManager())
    }
}
