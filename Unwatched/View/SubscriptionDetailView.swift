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

    func addVideoToQueue(_ video: Video) {
        QueueManager.insertQueueEntries(
            videos: [video],
            modelContext: modelContext)
        // TODO: potentially delete inbox entry here?
    }

    func loadNewVideos() async {
        await VideoManager.loadVideos(
            subscriptions: [subscription],
            defaultVideoPlacement: .inbox,
            modelContext: modelContext
        )
    }

    var body: some View {
        VStack {
            List {
                Section {
                    Picker("newVideos",
                           selection: $subscription.placeVideosIn) {
                        ForEach(VideoPlacement.allCases, id: \.self) {
                            Text($0.description)
                        }
                    }
                }

                Section {
                    ForEach(subscription.videos.sorted(by: { ($0.publishedDate ?? Date.distantPast)
                                                        > ($1.publishedDate ?? Date.distantPast)})
                    ) { video in
                        VideoListItem(video: video, showVideoStatus: true)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    addVideoToQueue(video)
                                } label: {
                                    Image(systemName: "text.badge.plus")
                                }
                                .tint(.teal)
                            }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    QueueManager.clearFromEverywhere(video,
                                                                     modelContext: modelContext)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .tint(.orange)
                            }
                    }
                }
            }
            .listStyle(.plain)
            .refreshable {
                await loadNewVideos()
            }
            Spacer()

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
