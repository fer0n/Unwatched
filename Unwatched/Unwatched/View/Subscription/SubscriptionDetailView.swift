//
//  SubscriptionDetailView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct SubscriptionDetailView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) var navManager

    @State var isLoading = false
    @State var subscribeManager = SubscribeManager()
    @State var requiresUnsubscribe = false
    @State var loadNewVideosTask: Task<(), Never>?
    @State var showTitle: Bool = false

    @Bindable var subscription: Subscription

    var body: some View {
        VStack {
            List {
                VStack {
                    SubscriptionInfoDetails(subscription: subscription,
                                            requiresUnsubscribe: $requiresUnsubscribe)
                        .onAppear {
                            showTitle = false
                        }.onDisappear {
                            showTitle = true
                        }
                }
                .padding(.top, 200)
                .listRowInsets(EdgeInsets(top: -200, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .background(
                    CachedImageView(imageUrl: imageUrl) { image in
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
                            .init(color: .black, location: 1)
                        ]
                    ), startPoint: .top, endPoint: .bottom))
                )

                VideoListView(subscriptionId: subscription.persistentModelID)
            }
        }
        .listStyle(.plain)
        .myNavigationTitle(showTitle ? LocalizedStringKey(subscription.title) : nil)
        .toolbar {
            if !subscription.isArchived {
                RefreshToolbarButton(refreshOnlySubscription: subscription.persistentModelID)
            }
        }
        .task(id: loadNewVideosTask) {
            if let task = loadNewVideosTask {
                await task.value
                isLoading = false
            }
        }
        .onAppear {
            handleOnAppear()
        }
        .onDisappear {
            handleOnDisappear()
        }
    }

    var imageUrl: URL? {
        if subscription.thumbnailUrl != nil {
            return subscription.thumbnailUrl
        }
        let fallbackVideo = subscription.videos?.first(where: {
            $0.isYtShort != true
        })
        return fallbackVideo?.thumbnailUrl
    }

    func handleOnAppear() {
        if navManager.tab == .library {
            navManager.lastLibrarySubscriptionId = subscription.persistentModelID
        }
    }

    func handleOnDisappear() {
        if subscription.isArchived && requiresUnsubscribe {
            let subId = subscription.persistentModelID
            _ = SubscriptionService.deleteSubscriptions([subId])
        }
        if navManager.tab == .library {
            navManager.lastLibrarySubscriptionId = nil
        }
    }

    func loadNewVideos() {
        if isLoading { return }
        isLoading = true
        let subId = subscription.persistentModelID
        loadNewVideosTask = Task {
            let task = VideoService.loadNewVideosInBg(
                subscriptionIds: [subId])
            _ = try? await task.value
        }
    }
}

#Preview {
    let container = DataProvider.previewContainer
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
                .environment(ImageCacheManager())
                .environment(SheetPositionReader())
        }
    } else {
        return SubscriptionDetailView(subscription: Subscription.getDummy())
            .modelContainer(container)
            .environment(NavigationManager())
            .environment(RefreshManager())
            .environment(PlayerManager())
            .environment(ImageCacheManager())
            .environment(SheetPositionReader())
    }
}
