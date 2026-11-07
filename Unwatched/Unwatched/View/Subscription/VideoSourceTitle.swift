//
//  VideoSourceTitle.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct VideoOrigin: Equatable {
    enum Channel: Equatable {
        case subscription(Subscription)
        case preview(title: String)
    }

    let channel: Channel?
    let playlist: Subscription?

    @MainActor
    init(_ video: Video) {
        _ = ChannelLookupRevision.shared.value
        let playlist = video.playlistSubscription
        if let channel = video.channelSubscription {
            self.channel = .subscription(channel)
            self.playlist = playlist
        } else if playlist != nil, video.uploaderChannelId != nil, let title = video.channelTitle {
            channel = .preview(title: title)
            self.playlist = playlist
        } else {
            channel = video.subscription.map { .subscription($0) }
            self.playlist = nil
        }
    }
}

struct VideoSourceTitle: View {
    enum Style {
        case inline, stacked
    }

    private let openFromPlayer = OpenFromPlayerAction()

    let video: Video
    let source: VideoOrigin
    var style: Style = .inline
    var imageSize: CGFloat = 30
    var subtitle: String?

    var body: some View {
        if let playlist = source.playlist {
            switch style {
            case .inline: inline(playlist)
            case .stacked: stacked(playlist)
            }
        } else {
            channelTitle(showImage: true, subtitle: subtitle)
        }
    }

    private func inline(_ playlist: Subscription) -> some View {
        PlaylistAndChannel {
            SubscriptionTitleButton(
                title: playlist.title,
                thumbnailUrl: playlist.thumbnailUrl,
                isWatchLater: playlist.isWatchLater,
                showsAdd: playlist.isArchived,
                imageSize: imageSize
            ) {
                openFromPlayer.open(playlist)
            }
        } channel: {
            channelTitle(showImage: false, allowsAdd: false)
        }
    }

    private func stacked(_ playlist: Subscription) -> some View {
        HStack(spacing: 10) {
            sourceImage(playlist)
            VStack(alignment: .leading, spacing: 1) {
                SubscriptionTitleButton(
                    title: playlist.title,
                    thumbnailUrl: nil,
                    showsAdd: playlist.isArchived
                ) {
                    openFromPlayer.open(playlist)
                }
                .accessibilityHint(Text("viewPlaylist"))
                channelTitle(showImage: false, subtitle: subtitle)
            }
        }
    }

    @ViewBuilder private func channelTitle(
        showImage: Bool,
        subtitle: String? = nil,
        allowsAdd: Bool = true
    ) -> some View {
        switch source.channel {
        case .subscription(let channel):
            InteractiveSubscriptionTitle(
                subscription: channel,
                showImage: showImage,
                imageSize: imageSize,
                subtitle: subtitle,
                allowsAdd: allowsAdd
            )
            .equatable()
        case .preview(let title):
            SubscriptionTitleButton(
                title: title,
                thumbnailUrl: nil,
                showsAdd: allowsAdd,
                imageSize: imageSize,
                subtitle: subtitle
            ) {
                openFromPlayer { $0.pushChannel(of: video) }
            }
        case nil:
            if let subtitle {
                Text(verbatim: subtitle)
                    .fontWeight(.regular)
            }
        }
    }

    /// The channel's image, else the playlist's; a placeholder keeps the space when neither has one
    @ViewBuilder private func sourceImage(_ playlist: Subscription) -> some View {
        if case .subscription(let channel) = source.channel,
           channel.thumbnailUrl != nil || channel.isWatchLater {
            imageButton(channel)
        } else if playlist.thumbnailUrl != nil || playlist.isWatchLater {
            imageButton(playlist)
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .foregroundStyle(.tertiary)
                .frame(width: imageSize, height: imageSize)
                .accessibilityHidden(true)
        }
    }

    private func imageButton(_ sub: Subscription) -> some View {
        Button {
            openFromPlayer.open(sub)
        } label: {
            SubscriptionImage(
                thumbnailUrl: sub.thumbnailUrl,
                isPodcast: sub.isPodcast,
                isWatchLater: sub.isWatchLater,
                size: imageSize
            )
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }
}

/// "Playlist (Channel)", where a long playlist name truncates before the channel
struct PlaylistAndChannel<Playlist: View, Channel: View>: View {
    @ViewBuilder let playlist: Playlist
    @ViewBuilder let channel: Channel

    var body: some View {
        HStack(spacing: 0) {
            playlist
                .accessibilityHint(Text("viewPlaylist"))
            HStack(spacing: 0) {
                Text(verbatim: " (")
                    .fixedSize()
                    .accessibilityHidden(true)
                channel
                Text(verbatim: ")")
                    .fixedSize()
                    .accessibilityHidden(true)
            }
            .layoutPriority(1)
        }
    }
}
