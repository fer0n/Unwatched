//
//  SubscriptionTitleFitlerPreview.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SubscriptionTitleFitlerPreview: View {
    @State var videoListVM = VideoListVM(initialBatchSize: 800)
    @Bindable var subscription: Subscription

    var body: some View {
        TitleFilterContent(
            filterText: $subscription.filterText,
            videoListVM: $videoListVM,
            filter: videoFilter
        )

        Spacer()
            .frame(height: videoListVM.hasNoVideos ? 300 : 0)
            .listRowBackground(Color.backgroundColor)
    }

    var videoFilter: Predicate<Video>? {
        VideoListView.getVideoFilter(subscription.persistentModelID)
    }
}
