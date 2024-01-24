//
//  SubscriptionDetailView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct SubscriptionDetailView: View {
    @Environment(\.modelContext) var modelContext

    @AppStorage(Const.handleShortsDifferently) var handleShortsDifferently: Bool = false
    @AppStorage(Const.hideShortsEverywhere) var hideShortsEverywhere: Bool = false
    @AppStorage(Const.shortsDetection) var shortsDetection: ShortsDetection = .safe
    @State var isLoading = false
    @State var subscribeManager = SubscribeManager()

    @Bindable var subscription: Subscription

    let coordinateSpaceName = "navstack"
    @State var size: CGRect = .zero
    @State var requiresUnsubscribe = false

    // TODO: test if now the videoListItem might no longer need the hasInboxEntry etc. workaround?
    // TODO: whats the difference between id and persistendModelID? Check what's used in tutorials

    var body: some View {
        let firstNonShort = subscription.videos.first(where: { !$0.isYtShort && !$0.isLikelyYtShort })
        let thumbnailUrl = firstNonShort?.thumbnailUrl

        VStack {
            List {
                VStack {
                    SubscriptionInfoDetails(subscription: subscription,
                                            requiresUnsubscribe: $requiresUnsubscribe)
                }
                .padding(.top, 200)
                .listRowInsets(EdgeInsets(top: -200, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .background(
                    CacheAsyncImage(url: thumbnailUrl) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.clear
                    }
                    .overlay(Material.thin)
                    .padding(.bottom, -100)
                    .mask(LinearGradient(gradient: Gradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(0.8), location: 0.2),
                            .init(color: .black, location: 0.3),
                            .init(color: .black, location: 0.5),
                            .init(color: .clear, location: 1)
                        ]
                    ), startPoint: .top, endPoint: .bottom))
                )

                VideoListView(
                    subscriptionId: subscription.persistentModelID,
                    ytShortsFilter: shortsFilter
                )
            }
        }
        .listStyle(.plain)
        .navigationTitle(subscription.title.uppercased())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !subscription.isArchived {
                RefreshToolbarButton(refreshOnlySubscription: subscription.persistentModelID)
            }
        }
        .onDisappear {
            print("onDisappear")
            if subscription.isArchived && requiresUnsubscribe {
                let subId = subscription.persistentModelID
                let container = modelContext.container
                SubscriptionService.deleteSubscriptions([subId], container: container)
            }
        }
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

#Preview {
    let container = DataController.previewContainer
    let fetch = FetchDescriptor<Subscription>()
    let subs = try? container.mainContext.fetch(fetch)
    let sub = subs?.first

    if let sub = sub {
        return NavigationView {
            SubscriptionDetailView(subscription: sub)
                .modelContainer(container)
                .environment(NavigationManager())
                .environment(RefreshManager())
                .environment(PlayerManager())
        }
    } else {
        return SubscriptionDetailView(subscription: Subscription.getDummy())
            .modelContainer(container)
            .environment(NavigationManager())
            .environment(RefreshManager())
            .environment(PlayerManager())
    }
}
