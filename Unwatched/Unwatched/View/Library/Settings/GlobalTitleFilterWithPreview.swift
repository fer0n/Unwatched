//
//  TitleFilterView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct GlobalTitleFilterWithPreview: View {
    @CloudStorage(Const.filterVideoTitleText) var filterVideoTitleText: String = ""
    @State var videoListVM = VideoListVM(initialBatchSize: 500)

    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

            List {
                TitleFilterContent(
                    filterText: $filterVideoTitleText,
                    videoListVM: $videoListVM
                )
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .myNavigationTitle("videoTitleFilter")
        }
    }
}

#Preview {
    GlobalTitleFilterWithPreview()
        .modelContainer(DataProvider.previewContainerFilled)
        .environment(NavigationManager.getDummy(false))
        .environment(PlayerManager.getDummy())
        .environment(ImageCacheManager())
}
