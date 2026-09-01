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
    @State private var showTitle = false
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
            VStack {
                ChannelHeaderView(
                    title: show.displayTitle,
                    imageUrl: show.thumbnailUrl,
                    isPodcast: show.isPodcast,
                    userName: nil,
                    author: show.author,
                    videoCount: episodes.isEmpty ? nil : episodes.count,
                    reserveImage: true
                )
                subscribeRow
                description
            }
            .padding(.bottom, 20)
            .onAppear {
                withAnimation(.default.speed(1.5)) { showTitle = false }
            }
            .onDisappear {
                withAnimation(.default.speed(1.5)) { showTitle = true }
            }
            #if !os(visionOS)
            .imageAccentBackground(url: show.thumbnailUrl)
            #endif
            .myListRowBackground()

            episodeList
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .background {
            MyBackgroundColor()
        }
        .myNavigationTitle(LocalizedStringKey(show.displayTitle), titleHidden: !showTitle)
        .tint(.neutralAccentColor)
        .task {
            await load()
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

    /// Full height from the first frame, so the late-arriving blurb can't shove the list down.
    @ViewBuilder
    var description: some View {
        if isLoading || !showDescription.isEmpty {
            Text(showDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 15)
                .padding(.top, 10)
        }
    }

    var subscribeRow: some View {
        let isSubscribed = subManager.isSubscribedSuccess == true
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                subscribeButton

                SubscriptionTagsSetting(subscription: subscription)
                    .opacity(isSubscribed ? 1 : 0)
                    .disabled(!isSubscribed)
                    .allowsHitTesting(isSubscribed)
            }
            .animation(.default, value: isSubscribed)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 15)
        }
    }

    var subscribeButton: some View {
        Button {
            Task { await subManager.togglePodcastSubscription(show) }
        } label: {
            HStack(spacing: 3) {
                if subManager.isLoading {
                    ProgressView()
                } else {
                    Image(systemName: subManager.isSubscribedSuccess == true ? "checkmark" : "plus")
                        .contentTransition(.symbolEffect(.replace))
                }
                Text(subManager.isSubscribedSuccess == true
                        ? String(localized: "subscribed")
                        : String(localized: "subscribe"))
            }
            .fontWidth(.condensed)
            .fontWeight(.semibold)
            .padding(10)
        }
        .buttonStyle(CapsuleButtonStyle())
        .disabled(subManager.isLoading || show.link == nil)
        .subscribeErrorPopover(subManager)
    }

    @ViewBuilder
    var episodeList: some View {
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
            ForEach(episodes, id: \.youtubeId) { episode in
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
            }
            .myListRowBackground()
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
            let feed = try await PodcastService.loadFeed(feedUrl, limitEpisodes: Const.podcastPreviewEpisodeLimit)
            showDescription = feed.showDescription
            // the show travels with every episode: it's what a queued episode gets attached to
            episodes = feed.episodes.map {
                var episode = $0
                episode.subscription = feed.subscription
                return episode
            }
        } catch {
            Log.error("PodcastPreview load failed: \(error)")
            loadFailed = true
        }
    }
}
