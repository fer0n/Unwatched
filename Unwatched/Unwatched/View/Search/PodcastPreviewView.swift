//
//  PodcastPreviewView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

/// A read-only show page for a podcast that isn't in the library yet, mirroring `ChannelPreviewView`.
struct PodcastPreviewView: View {
    @Environment(RefreshManager.self) var refresher
    @Environment(\.modelContext) var modelContext

    let show: SendableSubscription

    @State private var episodes: [SendableVideo] = []
    @State private var showDescription = ""
    @State private var isLoading = true
    @State private var loadFailed = false
    /// Only the newest `Const.podcastPreviewEpisodeLimit` are parsed until the list or a search runs past them
    @State private var hasFullFeed = false
    @State private var reachedListEnd = false
    @State private var isLoadingFullFeed = false
    @State private var showTitle = false
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var subManager = SubscribeManager()
    /// Not persisted — a stand-in with the same `subscriptionKey` so `subscribeRow` reserves the tag menu's full size
    /// from the first frame, swapped for the real model once subscribed.
    @State private var subscription: Subscription

    init(_ show: SendableSubscription) {
        self.show = show
        _subscription = State(initialValue: Subscription(link: show.link, title: show.title))
    }

    var body: some View {
        List {
            if isSearching {
                SubscriptionSearchField(text: $searchText)
            } else {
                header
            }
            episodeList
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        #if !os(visionOS)
        .scrollEdgeEffectHidden(!showTitle && !isSearching, for: .top)
        #endif
        .background {
            MyBackgroundColor()
        }
        .myNavigationTitle(LocalizedStringKey(show.displayTitle), titleHidden: !showTitle && !isSearching)
        .paneToolbar(placement: .primaryAction) {
            SubscriptionSearchButton(isSearching: $isSearching)
        }
        .channelPageColor(imageUrl: show.thumbnailUrl)
        .task {
            await load()
        }
        .task(id: wantsFullFeed) {
            if wantsFullFeed {
                await loadFullFeed()
            }
        }
        .onChange(of: isSearching) {
            if !isSearching { searchText = "" }
        }
        .onChange(of: subManager.isSubscribedSuccess) {
            if subManager.isSubscribedSuccess == true {
                fetchSubscription()
            } else {
                subscription = Subscription(link: show.link, title: show.title)
            }
        }
        .onDisappear {
            if subManager.hasNewSubscriptions {
                subManager.hasNewSubscriptions = false
                Task { await refresher.refreshAll() }
            }
        }
    }

    var header: some View {
        SubscriptionHero(
            artwork: SubscriptionArtwork(thumbnailUrl: show.thumbnailUrl, isPodcast: true),
            backgroundUrl: show.thumbnailUrl,
            showTitle: $showTitle
        ) {
            VStack(spacing: 4) {
                #if !os(visionOS)
                SubscriptionHeroTitle(show.displayTitle)
                #endif
                SubscriptionHeroMeta(SubscriptionHeroMeta.text(handle: show.author, isPodcast: true, isPlaylist: false))
            }
            description
        } chips: {
            subscribeButton
            SubscriptionTagsSetting(subscription: subscription)
                .opacity(isSubscribed ? 1 : 0)
                .disabled(!isSubscribed)
                .allowsHitTesting(isSubscribed)
                .animation(.default, value: isSubscribed)
        }
    }

    private var wantsFullFeed: Bool {
        !isLoading && !hasFullFeed && (reachedListEnd || (isSearching && !searchText.isEmpty))
    }

    private var isSubscribed: Bool {
        subManager.isSubscribedSuccess == true
    }

    /// Full height from the first frame, so the late-arriving blurb can't shove the list down.
    @ViewBuilder
    var description: some View {
        if isLoading || !showDescription.isEmpty {
            Text(showDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3, reservesSpace: true)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    var subscribeButton: some View {
        Button {
            Task { await subManager.togglePodcastSubscription(show) }
        } label: {
            SubscribeCapsuleLabel(
                isSubscribed: isSubscribed,
                isLoading: subManager.isLoading
            )
        }
        .buttonStyle(CapsuleButtonStyle())
        .environment(\.settingIsActive, isSubscribed)
        .disabled(show.link == nil)
        .allowsHitTesting(!subManager.isLoading)
        .subscribeErrorPopover(subManager)
    }

    private var shownEpisodes: [SendableVideo] {
        guard isSearching else { return episodes }
        return episodes.filter { $0.matchesSubscriptionSearch(searchText) }
    }

    @ViewBuilder
    var episodeList: some View {
        let shown = shownEpisodes
        if isLoading && episodes.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
                .myListRowBackground()
        } else if loadFailed && episodes.isEmpty {
            ContentUnavailableView(
                "channelLoadFailed",
                systemImage: "wifi.exclamationmark",
                description: Text("channelLoadFailedDescription")
            )
            .myListRowBackground()
        } else {
            ForEach(shown, id: \.youtubeId) { episode in
                VideoListItem(
                    episode,
                    episode.youtubeId,
                    config: VideoListItemConfig(
                        videoDuration: episode.duration,
                        showAllStatus: false,
                        showContextMenu: false,
                        showDelete: false
                    )
                )
                .equatable()
                .videoListItemEntry()
                .onAppear {
                    if !isSearching && episode.youtubeId == shown.last?.youtubeId {
                        reachedListEnd = true
                    }
                }
            }
            .myListRowBackground()

            if isLoadingFullFeed {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .myListRowBackground()
            } else if isSearching && shown.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowSeparator(.hidden)
                    .myListRowBackground()
            }
        }
    }

    /// `SubscriptionTagsSetting` needs the persisted `Subscription`, not the feed's `SendableSubscription`.
    private func fetchSubscription() {
        guard let feedUrl = show.link else { return }
        let fetch = FetchDescriptor<Subscription>(predicate: #Predicate<Subscription> { $0.isPodcast == true })
        let subs = try? modelContext.fetch(fetch)
        if let match = subs?.first(where: { $0.link == feedUrl }) {
            subscription = match
        }
    }

    private func load() async {
        guard episodes.isEmpty, let feedUrl = show.link else {
            isLoading = false
            loadFailed = show.link == nil
            return
        }
        await subManager.setIsPodcastSubscribed(feedUrl)
        defer { isLoading = false }

        do {
            let limit = Const.podcastPreviewEpisodeLimit
            let feed = try await PodcastService.loadFeed(feedUrl, limitEpisodes: limit)
            showDescription = feed.showDescription
            episodes = attachingShow(feed)
            hasFullFeed = feed.episodes.count < limit
        } catch {
            Log.podcasts.error("PodcastPreview load failed: \(error)")
            loadFailed = true
        }
    }

    private func loadFullFeed() async {
        guard !hasFullFeed, !isLoadingFullFeed, let feedUrl = show.link else { return }
        isLoadingFullFeed = true
        defer { isLoadingFullFeed = false }
        do {
            let feed = try await PodcastService.loadFeed(feedUrl)
            episodes = attachingShow(feed)
            hasFullFeed = true
        } catch {
            guard !Task.isCancelled else { return }
            Log.podcasts.error("PodcastPreview full feed load failed: \(error)")
        }
    }

    /// The show travels with every episode: it's what a queued episode gets attached to.
    private func attachingShow(_ feed: PodcastFeed) -> [SendableVideo] {
        feed.episodes.map {
            var episode = $0
            episode.subscription = feed.subscription
            return episode
        }
    }
}
