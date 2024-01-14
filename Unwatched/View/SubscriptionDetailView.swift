//
//  SubscriptionDetailView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct SubscriptionDetailView: View {
    @Bindable var subscription: Subscription
    @Environment(\.modelContext) var modelContext
    @AppStorage("defaultVideoPlacement") var defaultVideoPlacement: VideoPlacement = .inbox

    var body: some View {
        VStack {
            List {
                Section {
                    Picker("newVideos",
                           selection: $subscription.placeVideosIn) {
                        ForEach(VideoPlacement.allCases, id: \.self) {
                            Text($0.description(defaultPlacement: String(describing: defaultVideoPlacement) ))
                        }
                    }
                }

                Section {
                    ForEach(subscription.videos.sorted(by: { ($0.publishedDate ?? Date.distantPast)
                                                        > ($1.publishedDate ?? Date.distantPast)})
                    ) { video in
                        VideoListItem(video: video, showVideoStatus: true, videoSwipeActions: [.queue, .clear])
                    }
                }
            }
            .listStyle(.plain)
            .refreshable {
                VideoService.loadNewVideosInBg(subscriptions: [subscription],
                                               modelContext: modelContext)
            }
        }
        .navigationBarTitle(subscription.title.uppercased())
        .toolbarBackground(Color.backgroundColor, for: .navigationBar)
    }
}

#Preview {
    NavigationView {
        SubscriptionDetailView(subscription: Subscription.dummy)
    }
}
