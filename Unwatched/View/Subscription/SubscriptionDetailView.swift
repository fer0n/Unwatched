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

    @State var isLoading = false

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
            .toolbar {
                if !subscription.isArchived {
                    RefreshToolbarButton(refreshOnlySubscription: subscription.persistentModelID)
                }
            }
        }
        .navigationBarTitle(subscription.title.uppercased(), displayMode: .inline)
    }

    var shortsFilter: ShortsDetection? {
        (handleShortsDifferently && hideShortsEverywhere) ? shortsDetection : nil
    }

    func loadNewVideos() {
        if isLoading { return }
        isLoading = true
        let container = modelContext.container
        let subId = subscription.persistentModelID
        Task {
            let task = VideoService.loadNewVideosInBg(
                subscriptionIds: [subId],
                container: container)
            try? await task.value
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// #Preview {
//    NavigationView {
//        SubscriptionDetailView(subscription: Subscription.getDummy())
//    }
// }
