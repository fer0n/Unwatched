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

    @State var requiresUnsubscribe = false
    @State var showTitle: Bool = false
    @State var showFilter = false
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var storedVideoLimit = Const.channelVideoFetchLimit

    @Bindable var subscription: Subscription

    var body: some View {
        List {
            if isSearching {
                SubscriptionSearchField(text: $searchText)
            } else {
                SubscriptionHeader(
                    subscription: subscription,
                    requiresUnsubscribe: $requiresUnsubscribe,
                    showFilter: $showFilter,
                    showTitle: $showTitle,
                    imageUrl: imageUrl
                )
            }
            videoSection
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        #if !os(visionOS)
        .scrollEdgeEffectHidden(!showTitle && !isSearching, for: .top)
        #endif
        .background {
            MyBackgroundColor()
        }
        .concentricMacWorkaround()
        .myNavigationTitle(LocalizedStringKey(subscription.title), titleHidden: !showTitle && !isSearching)
        .paneToolbar(placement: .primaryAction) {
            SubscriptionSearchButton(isSearching: $isSearching)
        }
        .onChange(of: isSearching) {
            if isSearching {
                showFilter = false
            } else {
                searchText = ""
            }
        }
        .channelPageColor(imageUrl: subscription.isWatchLater ? nil : imageUrl, choice: subscription.tint)
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
            PodcastEpisodeListView(subscription: subscription, searchText: isSearching ? searchText : "")
        } else if isSearching {
            // stored videos only: what the channel has beyond them isn't searchable
            VideoListView(
                subscriptionId: subscription.persistentModelID,
                searchText: searchText.trimmingCharacters(in: .whitespaces)
            )
        } else if let source = SubscriptionVideoListVM.Source(subscription) {
            SubscriptionVideoList(
                subscriptionId: subscription.persistentModelID,
                source: source,
                title: subscription.title,
                limit: source.keepsListOrder ? nil : storedVideoLimit,
                showMoreStored: { storedVideoLimit += Const.channelVideoFetchLimit }
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

    func handleOnAppear() {
        navManager.visibleChannelPages.insert(subscription.persistentModelID)
        if navManager.tab == .library {
            navManager.lastLibrarySubscriptionId = subscription.persistentModelID
        }
    }

    func handleOnDisappear() {
        navManager.visibleChannelPages.remove(subscription.persistentModelID)
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
