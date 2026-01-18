//
//  WatchHistoryView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct WatchHistoryView: View {
    @State var videoListVM = VideoListVM()

    var body: some View {
        ZStack {
            MyBackgroundColor()

            if videoListVM.hasNoVideos {
                ContentUnavailableView("noHistoryItems",
                                       systemImage: Const.watchedSF,
                                       description: Text("noHistoryItemsDescription"))
            } else {
                VideosViewAsync(
                    videoListVM: $videoListVM,
                    sorting: [SortDescriptor<Video>(\.watchedDate, order: .reverse)],
                    filter: #Predicate<Video> {
                        $0.watchedDate != nil
                    }
                )
            }
        }
        .concentricMacWorkaround()
        .myNavigationTitle("watched")
        .showStatsToolbarItem(true)
        .toolbar {
            ToolbarItem {
                ShowStatsItem()
            }
        }
    }
}

#Preview {
    WatchHistoryView()
        .modelContainer(DataProvider.previewContainer)
        .environment(ImageCacheManager())
}
