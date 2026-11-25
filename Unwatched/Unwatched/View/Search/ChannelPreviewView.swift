//
//  ChannelPreviewView.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared

/// A read-only channel detail page for the Search tab. Loads the channel's recent
/// videos from its RSS feed without persisting the channel — nothing is written to
/// the store unless the user taps Subscribe (or plays/queues one of the videos).
///
/// Reuses `SubscriptionHero` and `channelPageColor` so it matches the regular subscription detail view.
struct ChannelPreviewView: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(RefreshManager.self) var refresher

    @AppStorage(Const.browserDisplayMode) var browserDisplayMode: BrowserDisplayMode = .inApp

    let sub: SendableSubscription

    @State private var videos: [SendableVideo] = []
    @State private var channelImageUrl: URL?
    @State private var playlists: [InnerTubeAPI.ITPlaylist] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var showTitle = false
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var subManager = SubscribeManager()

    private let api = InnerTubeAPI()

    init(_ sub: SendableSubscription) {
        self.sub = sub
    }

    /// This preview represents a playlist (rather than a channel) when a playlist id is set.
    private var isPlaylist: Bool {
        sub.youtubePlaylistId != nil
    }

    var body: some View {
        List {
            if isSearching {
                SubscriptionSearchField(text: $searchText)
            } else {
                header
                playlistsShelf
            }
            videoList
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        #if !os(visionOS)
        .scrollEdgeEffectHidden(!showTitle && !isSearching, for: .top)
        #endif
        .background {
            MyBackgroundColor()
        }
        .myNavigationTitle(LocalizedStringKey(sub.displayTitle), titleHidden: !showTitle && !isSearching)
        .paneToolbar(placement: .primaryAction) {
            SubscriptionSearchButton(isSearching: $isSearching)
            if !isSearching {
                RefreshButton(forceNeutral: true)
            }
        }
        .channelPageColor(imageUrl: sub.isWatchLater ? nil : backgroundImageUrl)
        .task {
            await load()
        }
        .onChange(of: isSearching) {
            if !isSearching { searchText = "" }
        }
        .onDisappear {
            // If the user subscribed while here, refresh on the way out so the new
            // subscription's videos are fetched into the library.
            if subManager.hasNewSubscriptions {
                subManager.hasNewSubscriptions = false
                Task { await refresher.refreshAll() }
            }
        }
    }

    var header: some View {
        SubscriptionHero(
            artwork: SubscriptionArtwork(
                thumbnailUrl: sub.thumbnailUrl ?? channelImageUrl,
                isWatchLater: sub.isWatchLater
            ),
            backgroundUrl: backgroundImageUrl,
            useThemeColor: sub.isWatchLater,
            showTitle: $showTitle
        ) {
            VStack(spacing: 4) {
                #if !os(visionOS)
                SubscriptionHeroTitle(sub.displayTitle)
                #endif
                SubscriptionHeroMeta(SubscriptionHeroMeta.text(
                    handle: sub.youtubeUserName.map { "@\($0)" } ?? sub.author,
                    isPodcast: false,
                    isPlaylist: isPlaylist
                ))
            }
        } chips: {
            chips
        }
    }

    @ViewBuilder
    var playlistsShelf: some View {
        if !isPlaylist && !playlists.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(playlists) { playlist in
                            Button {
                                openPlaylist(playlist)
                            } label: {
                                PlaylistCard(playlist: playlist)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 5)
                }
                .scrollClipDisabled()

                Divider()
            }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10))
            .myListRowBackground()
        }
    }

    func openPlaylist(_ playlist: InnerTubeAPI.ITPlaylist) {
        let playlistSub = SendableSubscription(
            title: playlist.title,
            author: sub.displayTitle,
            youtubePlaylistId: playlist.id,
            thumbnailUrl: sub.thumbnailUrl ?? channelImageUrl
        )
        navManager.pushSubscription(sendableSubscription: playlistSub)
    }

    @ViewBuilder
    var videoList: some View {
        if isLoading && videos.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
                .myListRowBackground()
        } else if loadFailed && videos.isEmpty {
            ContentUnavailableView(
                "channelLoadFailed",
                systemImage: "wifi.exclamationmark",
                description: Text("channelLoadFailedDescription")
            )
            .myListRowBackground()
        } else if videos.isEmpty {
            ContentUnavailableView(
                "channelNoVideos",
                systemImage: "rectangle.stack.badge.play"
            )
            .myListRowBackground()
        } else {
            ForEach(shownVideos, id: \.youtubeId) { video in
                VideoListItem(
                    video,
                    video.youtubeId,
                    config: VideoListItemConfig(
                        videoDuration: video.duration,
                        showAllStatus: false,
                        showContextMenu: false,
                        showDelete: false
                    )
                )
                .equatable()
                .videoListItemEntry()
            }
            .myListRowBackground()
            .environment(\.videoListShowsUploader, isPlaylist)

            if isSearching && !searchText.isEmpty && shownVideos.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowSeparator(.hidden)
                    .myListRowBackground()
            }
        }
    }

    @ViewBuilder
    var chips: some View {
        let isSubscribed = subManager.isSubscribedSuccess == true
        Button {
            Task { await toggleSubscribe() }
        } label: {
            SubscribeCapsuleLabel(
                isSubscribed: isSubscribed,
                isLoading: subManager.isLoading
            )
        }
        .buttonStyle(CapsuleButtonStyle())
        .environment(\.settingIsActive, isSubscribed)
        .disabled(sub.youtubeChannelId == nil && sub.youtubePlaylistId == nil)
        .allowsHitTesting(!subManager.isLoading)
        .subscribeErrorPopover(subManager)

        if isPlaylist, let youtubeUrl {
            PlaylistAddVideosMenu(playlistUrl: youtubeUrl)
        }

        if browserDisplayMode != .disabled, let youtubeUrl {
            Button {
                navManager.openUrlInApp(.url(youtubeUrl.absoluteString))
            } label: {
                Image(systemName: Const.youtubeSF)
                    .fontWeight(.black)
                    .padding(10)
            }
            .accessibilityLabel("browser")
            .buttonStyle(CapsuleButtonStyle(primary: false))
        }
    }

    private var shownVideos: [SendableVideo] {
        guard isSearching else { return videos }
        return videos.filter { $0.matchesSubscriptionSearch(searchText) }
    }

    var youtubeUrl: URL? {
        guard let urlString = UrlService.getYoutubeUrl(
            userName: sub.youtubeUserName,
            channelId: sub.youtubeChannelId,
            playlistId: sub.youtubePlaylistId
        ) else { return nil }
        return URL(string: urlString)
    }

    var backgroundImageUrl: URL? {
        sub.thumbnailUrl ?? channelImageUrl ?? videos.first(where: { $0.isYtShort != true })?.thumbnailUrl
    }

    private var subscriptionInfo: SubscriptionInfo {
        var info = SubscriptionInfo(
            nil,
            sub.youtubeChannelId,
            nil,
            nil,
            sub.title.isEmpty ? nil : sub.title,
            nil,
            sub.youtubePlaylistId
        )
        // reuse the header's avatar instead of fetching it again
        if !isPlaylist {
            info.imageUrl = sub.thumbnailUrl ?? channelImageUrl
        }
        return info
    }
}

// MARK: - Loading

extension ChannelPreviewView {
    private func load() async {
        guard videos.isEmpty else { return }
        isLoading = true
        loadFailed = false
        defer { isLoading = false }

        if let playlistId = sub.youtubePlaylistId {
            await loadPlaylist(playlistId)
        } else if let channelId = sub.youtubeChannelId {
            await loadChannel(channelId)
        } else {
            loadFailed = true
        }
    }

    private func loadChannel(_ channelId: String) async {
        guard let url = try? UrlService.getFeedUrlFromChannelId(channelId) else {
            loadFailed = true
            return
        }

        // Fetch the channel avatar and playlists concurrently with the video feed.
        async let avatar = api.fetchChannelAvatarURL(channelId: channelId)
        async let channelPlaylists = api.fetchChannelPlaylists(channelId: channelId)
        await subManager.setIsSubscribed(SubscriptionInfo(channelId: channelId))

        await loadVideos(rss: url) {
            try await api.fetchChannelVideos(channelId: channelId)
        }

        if let avatarUrl = try? await avatar {
            channelImageUrl = avatarUrl
        }
        if let loadedPlaylists = try? await channelPlaylists {
            playlists = loadedPlaylists
        }
    }

    private func loadPlaylist(_ playlistId: String) async {
        guard let url = try? UrlService.getPlaylistFeedUrl(playlistId) else {
            loadFailed = true
            return
        }
        await subManager.setIsSubscribed(SubscriptionInfo(playlistId: playlistId))

        await loadVideos(rss: url) {
            try await api.fetchPlaylistVideos(playlistId: playlistId)
        }
    }

    /// RSS feeds 404 for hours most days; InnerTube's dates are approximate.
    private func loadVideos(rss url: URL, fallback: () async throws -> InnerTubeAPI.SearchPage) async {
        do {
            videos = try await VideoCrawler.loadVideosFromRSS(url: url)
        } catch let error as URLError where error.code == .badServerResponse {
            Log.warning("ChannelPreview RSS unavailable, using InnerTube: \(error)")
            do {
                videos = try await fallbackVideos(fallback)
            } catch {
                failLoading(error)
            }
        } catch {
            failLoading(error)
        }
    }

    private func fallbackVideos(_ fetch: () async throws -> InnerTubeAPI.SearchPage) async throws -> [SendableVideo] {
        try await fetch().videos.filter(\.isFeedUpload).map { video in
            guard isPlaylist else {
                var video = video
                video.channelTitle = sub.displayTitle
                return SearchVM.sendable(from: video)
            }
            var sendable = SearchVM.sendable(from: video)
            // playlist lockups don't mark Shorts; unknown lets a later refresh detect them
            sendable.isYtShort = nil
            return sendable
        }
    }

    private func failLoading(_ error: Error) {
        guard !Task.isCancelled else { return }
        Log.error("ChannelPreview load failed: \(error)")
        loadFailed = true
    }
}

extension ChannelPreviewView {
    fileprivate func toggleSubscribe() async {
        guard sub.youtubeChannelId != nil || sub.youtubePlaylistId != nil else { return }
        if subManager.isSubscribedSuccess == true {
            await subManager.unsubscribe(subscriptionInfo)
        } else {
            if !isLoading && !loadFailed && subscriptionInfo.title != nil {
                await subManager.addWithoutRSS(subscriptionInfo)
            } else {
                await subManager.addSubscription(subscriptionInfo)
            }
            if subManager.isSubscribedSuccess == true {
                Signal.log("Subscription.Added", parameters: ["source": "channelPreview"])
            }
        }
    }
}
