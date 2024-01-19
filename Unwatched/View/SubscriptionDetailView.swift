//
//  SubscriptionDetailView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct SubscriptionDetailView: View {
    @AppStorage(Const.defaultVideoPlacement) var defaultVideoPlacement: VideoPlacement = .inbox

    @Bindable var subscription: Subscription
    @Environment(\.modelContext) var modelContext

    @AppStorage(Const.handleShortsDifferently) var handleShortsDifferently: Bool = false
    @AppStorage(Const.hideShortsEverywhere) var hideShortsEverywhere: Bool = false
    @AppStorage(Const.shortsDetection) var shortsDetection: ShortsDetection = .safe

    // TODO: test if now the videoListItem might no longer need the hasInboxEntry etc. workaround?
    // TODO: whats the difference between id and persistendModelID? Check what's used in tutorials

    var body: some View {
        VStack {
            List {
                if !subscription.isArchived {
                    Section {
                        Picker("newVideos",
                               selection: $subscription.placeVideosIn) {
                            ForEach(VideoPlacement.allCases, id: \.self) {
                                Text($0.description(defaultPlacement: String(describing: defaultVideoPlacement) ))
                            }
                        }
                    }
                    .listRowSeparator(.hidden, edges: .top)
                }

                Section {
                    VideoListView(
                        subscriptionId: subscription.persistentModelID,
                        ytShortsFilter: shortsFilter
                    )
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

    var shortsFilter: ShortsDetection? {
        (handleShortsDifferently && hideShortsEverywhere) ? shortsDetection : nil
    }
}

// #Preview {
//    NavigationView {
//        SubscriptionDetailView(subscription: Subscription.getDummy())
//    }
// }
