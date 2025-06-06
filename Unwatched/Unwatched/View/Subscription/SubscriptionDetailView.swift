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
                .imageAccentBackground(url: imageUrl)

                VideoListView(subscriptionId: subscription.persistentModelID)
            }
            .scrollContentBackground(.hidden)
        }
        .background {
            Color.backgroundColor.ignoresSafeArea(.all)
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
    let container = DataProvider.previewContainerFilled
    let fetch = FetchDescriptor<Subscription>()
    let subs = try? container.mainContext.fetch(fetch)
    let sub = subs?.first

    if let sub {
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
