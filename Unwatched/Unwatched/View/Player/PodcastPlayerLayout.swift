//
//  PodcastPlayerLayout.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// An episode's art beside its notes where the column is wide, stacked where it isn't.
struct PodcastPlayerLayout: View {
    @Environment(PlayerManager.self) var player

    let playerView: PlayerView

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= Self.sideBySideMinWidth
            // AnyLayout keeps the player view's identity, which would otherwise tear down playback
            let layout = isWide
                ? AnyLayout(HStackLayout(alignment: .top, spacing: 0))
                : AnyLayout(VStackLayout(spacing: 0))

            layout {
                playerView
                    .frame(
                        maxWidth: isWide ? min(proxy.size.width * 0.45, Self.maxArtworkSize) : nil,
                        maxHeight: isWide ? nil : min(proxy.size.height * 0.4, Self.maxArtworkSize)
                    )
                    .padding(.horizontal, isWide ? 20 : 10)
                    .padding(.top, isWide ? 30 : 10)

                if let video = player.video {
                    ChapterDescriptionView(
                        video: video,
                        scrollToCurrent: true,
                        showThumbnail: false,
                        showActions: false
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    static let sideBySideMinWidth: CGFloat = 640
    static let maxArtworkSize: CGFloat = 460
}

private struct PodcastPlayerLayoutPreview: View {
    // `PlayerSwitchManager.activeType` reads the shared player
    @State private var player: PlayerManager = {
        let dummy = PlayerManager.getTheDailyPodcastDummy()
        let player = PlayerManager.shared
        player.video = dummy.video
        player.video?.videoDescription = """
            Grocery bills have barely come down since the peak of inflation, even as the cost of \
            fuel and shipping has eased. Why are food prices still so high, and who is profiting?

            Guest: Jeanna Smialek, who covers the Federal Reserve and the economy for The New York Times.

            Background reading:
            • How the price of eggs became a political issue.
            • Why companies keep raising prices even as their costs fall.

            Photo: Justin Sullivan/Getty Images

            Unlock full access to New York Times podcasts and explore everything from politics to pop \
            culture. Subscribe today at nytimes.com/podcasts or on Apple Podcasts and Spotify.
            """
        player.currentTime = dummy.currentTime
        PodcastPlayerLayoutPreview.seedArtwork(dummy.video?.thumbnailUrl)
        return player
    }()

    private static func seedArtwork(_ url: URL?) {
        guard let url,
              let data = try? Data(contentsOf: url),
              let image = PlatformImage(downsampling: data, maxPixelSize: Const.maxDecodedImagePixelSize)
        else { return }
        ImageService.decodedImageCache.store(
            image,
            url: url.absoluteString,
            maxPixelSize: Int(Const.maxDecodedImagePixelSize)
        )
    }

    let size: CGSize

    var body: some View {
        VideoPlayer(compactSize: true,
                    horizontalLayout: false,
                    landscapeFullscreen: false,
                    hideControls: false)
            .frame(width: size.width, height: size.height)
            .background(Color.playerBackgroundColor)
            .modelContainer(DataProvider.previewContainer)
            .environment(NavigationManager.getDummy(true))
            .environment(player)
            .environment(ImageCacheManager())
            .environment(RefreshManager())
            .environment(SheetPositionReader())
            .environment(TinyUndoManager())
            .tint(Color.neutralAccentColor)
            .environment(\.colorScheme, .dark)
    }
}

#Preview("iPad landscape column") {
    PodcastPlayerLayoutPreview(size: CGSize(width: 830, height: 800))
}

#Preview("iPad portrait column") {
    PodcastPlayerLayoutPreview(size: CGSize(width: 834, height: 690))
}

#Preview("Mac window") {
    PodcastPlayerLayoutPreview(size: CGSize(width: 1000, height: 640))
}

#Preview("Narrow") {
    PodcastPlayerLayoutPreview(size: CGSize(width: 520, height: 760))
}
