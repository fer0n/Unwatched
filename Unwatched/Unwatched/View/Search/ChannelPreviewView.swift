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
/// Reuses `ChannelHeaderView`, `imageAccentBackground`, `CapsuleButtonStyle` and the
/// scroll-hiding `myNavigationTitle` so it matches the regular subscription detail view.
struct ChannelPreviewView: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(RefreshManager.self) var refresher

    let sub: SendableSubscription

    @State private var videos: [SendableVideo] = []
    @State private var channelImageUrl: URL?
    @State private var playlists: [InnerTubeAPI.ITPlaylist] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var showTitle = false
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
            VStack {
                ChannelHeaderView(
                    title: sub.displayTitle,
                    imageUrl: sub.thumbnailUrl ?? channelImageUrl,
                    userName: sub.youtubeUserName,
                    author: sub.author,
                    videoCount: videos.isEmpty ? nil : videos.count,
                    reserveImage: true
                )
                subscribeRow
            }
            .padding(.bottom, 20)
            .onAppear {
                withAnimation(.default.speed(1.5)) { showTitle = false }
            }
            .onDisappear {
                withAnimation(.default.speed(1.5)) { showTitle = true }
            }
            #if !os(visionOS)
            .imageAccentBackground(url: backgroundImageUrl)
            #endif
            .myListRowBackground()

            playlistsShelf

            videoList
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .background {
            MyBackgroundColor()
        }
        .myNavigationTitle(LocalizedStringKey(sub.displayTitle), titleHidden: !showTitle)
        .toolbar {
            RefreshToolbarContent(forceNeutral: true)
        }
        .tint(.neutralAccentColor)
        .task {
            await load()
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
            ForEach(videos, id: \.youtubeId) { video in
                VideoListItem(
                    video,
                    video.youtubeId,
                    config: VideoListItemConfig(
                        videoDuration: video.duration,
                        showAllStatus: false,
                        showQueueButton: true,
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

    var subscribeRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                Button {
                    Task { await toggleSubscribe() }
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
                .disabled(subManager.isLoading || (sub.youtubeChannelId == nil && sub.youtubePlaylistId == nil))

                if let youtubeUrl {
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
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 15)
        }
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
        SubscriptionInfo(
            nil,
            sub.youtubeChannelId,
            nil,
            nil,
            sub.title.isEmpty ? nil : sub.title,
            nil,
            sub.youtubePlaylistId
        )
    }

    private func load() async {
        guard videos.isEmpty else { return }
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

        do {
            videos = try await VideoCrawler.loadVideosFromRSS(url: url)
        } catch {
            Log.error("ChannelPreview load failed: \(error)")
            loadFailed = true
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

        do {
            videos = try await VideoCrawler.loadVideosFromRSS(url: url)
        } catch {
            Log.error("ChannelPreview playlist load failed: \(error)")
            loadFailed = true
        }
    }

    private func toggleSubscribe() async {
        guard sub.youtubeChannelId != nil || sub.youtubePlaylistId != nil else { return }
        if subManager.isSubscribedSuccess == true {
            await subManager.unsubscribe(subscriptionInfo)
        } else {
            await subManager.addSubscription(subscriptionInfo)
        }
    }
}
