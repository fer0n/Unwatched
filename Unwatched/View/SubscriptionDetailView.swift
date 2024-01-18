//
//  SubscriptionDetailView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct SubscriptionDetailView: View {
    @Bindable var subscription: Subscription
    @Environment(\.modelContext) var modelContext
    @AppStorage(Const.defaultEpisodePlacement) var defaultEpisodePlacement: VideoPlacement = .inbox

    var body: some View {
        VStack {
            List {
                if !subscription.isArchived {
                    Section {
                        Picker("newVideos",
                               selection: $subscription.placeVideosIn) {
                            ForEach(VideoPlacement.allCases, id: \.self) {
                                Text($0.description(defaultPlacement: String(describing: defaultEpisodePlacement) ))
                            }
                        }
                    }
                    .listRowSeparator(.hidden, edges: .top)
                }

                Section {
                    ForEach(subscription.videos.sorted(by: { ($0.publishedDate ?? Date.distantPast)
                                                        > ($1.publishedDate ?? Date.distantPast)})
                    ) { video in
                        VideoListItem(
                            video: video,
                            showVideoStatus: true,
                            hasInboxEntry: video.inboxEntry != nil,
                            hasQueueEntry: video.queueEntry != nil,
                            watched: video.watched,
                            videoSwipeActions: [.queue, .clear]
                        )
                    }
                }
            }
            .listStyle(.plain)
            .refreshable {
                let task = VideoService.loadNewVideosInBg(
                    subscriptions: [subscription],
                    modelContext: modelContext)
                try? await task.value
            }
        }
        .navigationBarTitle(subscription.title.uppercased(), displayMode: .inline)
        .toolbarBackground(Color.backgroundColor, for: .navigationBar)
    }
}

#Preview {
    NavigationView {
        SubscriptionDetailView(subscription: Subscription.getDummy())
    }
}
