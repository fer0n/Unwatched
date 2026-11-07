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
    private let openFromPlayer = OpenFromPlayerAction()

    let video: Video
    let source: VideoOrigin
    var showImage = false
    var imageSize: CGFloat = 30
    var subtitle: String?

    var body: some View {
        switch source.channel {
        case .subscription(let channel):
            InteractiveSubscriptionTitle(
                subscription: channel,
                showImage: showImage,
                imageSize: imageSize,
                subtitle: subtitle
            )
            .equatable()
        case .preview(let title):
            SubscriptionTitleButton(
                title: title,
                thumbnailUrl: nil,
                showsAdd: true,
                imageSize: imageSize,
                subtitle: subtitle
            ) {
                openFromPlayer { $0.pushChannel(of: video) }
            }
        case nil:
            Spacer()
        }
    }
}

struct VideoPlaylistTitle: View {
    private let openFromPlayer = OpenFromPlayerAction()

    let playlist: Subscription

    var body: some View {
        Button {
            openFromPlayer.open(playlist)
        } label: {
            Label(playlist.displayTitle, systemImage: "rectangle.stack")
                .labelStyle(.regularSpacing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(playlist.displayTitle)
        .accessibilityHint(Text("viewPlaylist"))
    }
}
