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
    @State var showFilter = false

    @Environment(ImageCacheManager.self) var imageCacheManager
    @State var pageColor: Color?
    @Environment(\.colorScheme) var colorScheme

    @Bindable var subscription: Subscription

    var body: some View {
        List {
            SubscriptionHeader(
                subscription: subscription,
                requiresUnsubscribe: $requiresUnsubscribe,
                showFilter: $showFilter,
                showTitle: $showTitle,
                imageUrl: imageUrl
            )
            videoSection
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        #if !os(visionOS)
        .scrollEdgeEffectHidden(!showTitle, for: .top)
        #endif
        .background {
            MyBackgroundColor()
        }
        .concentricMacWorkaround()
        .myNavigationTitle(LocalizedStringKey(subscription.title), titleHidden: !showTitle)
        .paneToolbar(placement: .primaryAction) {
            if !subscription.isArchived {
                RefreshButton(
                    refreshOnlySubscription: subscription.persistentModelID,
                    forceNeutral: true
                )
            }
        }
        .tint(pageColor)
        .environment(\.pageThemeColor, pageColor)
        .environment(\.chipIconColor, pageColorResolver.iconColor(for: pageColor))
        .task(id: PageColorKey(imageUrl: imageUrl, colorScheme: colorScheme)) {
            await resolvePageColor()
        }
        #if os(visionOS)
        .tint(nil)
        #endif
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
        .task {
            await loadThumbnailIfMissing()
        }
    }

    @ViewBuilder var videoSection: some View {
        if showFilter {
            Button {
                showFilter = false
            } label: {
                Text("filterPreviewClose")
                    .padding(.horizontal, 5)
            }
            #if !os(visionOS)
            .glassEffect(.regular.interactive())
            .foregroundStyle(Color.automaticBlack)
            .tint(Color.insetBackgroundColor)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            #endif
            .buttonStyle(.bordered)
            .myListRowBackground()
            .listRowSeparator(.hidden)
            .frame(maxWidth: .infinity, alignment: .center)

            SubscriptionTitleFitlerPreview(subscription: subscription)
                .listRowSeparator(.hidden)
        } else if subscription.isPodcast {
            PodcastEpisodeListView(subscription: subscription)
        } else if let source = SubscriptionVideoListVM.Source(subscription) {
            SubscriptionVideoList(
                subscriptionId: subscription.persistentModelID,
                source: source,
                title: subscription.title
            )
            .environment(\.videoListShowsUploader, subscription.youtubePlaylistId != nil)
        } else {
            VideoListView(subscriptionId: subscription.persistentModelID)
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

    var pageColorResolver: PageColorResolver {
        PageColorResolver(imageCacheManager: imageCacheManager, colorScheme: colorScheme)
    }

    func resolvePageColor() async {
        guard !subscription.isWatchLater, let imageUrl else {
            pageColor = nil
            return
        }
        let color = await pageColorResolver.resolve(imageUrl: imageUrl)
        guard !Task.isCancelled else { return }
        pageColor = color
    }

    func handleOnAppear() {
        navManager.visibleSubscriptionPages.insert(subscription.persistentModelID)
        if navManager.tab == .library {
            navManager.lastLibrarySubscriptionId = subscription.persistentModelID
        }
    }

    func handleOnDisappear() {
        navManager.visibleSubscriptionPages.remove(subscription.persistentModelID)
        if subscription.isArchived && requiresUnsubscribe {
            let subId = subscription.persistentModelID
            _ = SubscriptionService.deleteSubscriptions([subId])
        }
        if navManager.tab == .library {
            navManager.lastLibrarySubscriptionId = nil
        }
    }

    /// Fallback for subscriptions that never got a channel avatar (e.g. the one-shot
    /// fetch in `SubscriptionActor.enrichThumbnail` failed at subscribe time).
    func loadThumbnailIfMissing() async {
        guard subscription.thumbnailUrl == nil,
              let channelId = subscription.youtubeChannelId,
              let avatarUrl = try? await InnerTubeAPI().fetchChannelAvatarURL(channelId: channelId) else {
            return
        }
        subscription.thumbnailUrl = avatarUrl
    }

    func loadNewVideos() {
        if isLoading { return }
        isLoading = true
        let subId = subscription.persistentModelID
        loadNewVideosTask = Task {
            let task = VideoService.loadNewVideosInBg(
                subscriptionIds: [subId],
                fetchDurations: true
            )
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
                .previewEnvironments()
        }
    } else {
        return SubscriptionDetailView(subscription: Subscription.getDummy())
            .previewEnvironments()
    }
}

private struct PageColorKey: Equatable {
    let imageUrl: URL?
    let colorScheme: ColorScheme
}
