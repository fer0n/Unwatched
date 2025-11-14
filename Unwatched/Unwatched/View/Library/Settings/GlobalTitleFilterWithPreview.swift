//
//  TitleFilterView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct GlobalTitleFilterWithPreview: View {
    @CloudStorage(Const.filterVideoTitleText) var filterVideoTitleText: String = ""
    @CloudStorage(Const.allowOnMatch) var allowOnMatch: Bool = false

    @State var videoListVM = VideoListVM(initialBatchSize: 500)

    var body: some View {
        ZStack {
            MyBackgroundColor(macOS: false)

            List {
                TitleFilterContent(
                    filterText: $filterVideoTitleText,
                    videoListVM: $videoListVM,
                    allowOnMatch: $allowOnMatch,
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
