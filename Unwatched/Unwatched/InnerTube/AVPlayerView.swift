import SwiftUI
import AVKit
import SwiftData
import UnwatchedShared

// MARK: - AVPlayerView
//
// Experimental native player that fetches HLS stream URLs via the InnerTube API
// and plays them with AVPlayer instead of the standard WKWebView approach.
// Enabled via Settings → Debug → useAVPlayer.

struct AVPlayerView: View {
    @Environment(PlayerManager.self) var player
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @AppStorage(Const.pipAutoEnable) private var pipAutoEnable = true

    var handleVideoEnded: () -> Void
    var handleSwipe: (SwipeDirecton) -> Void
    var hideMiniPlayer: Bool
    var handleMiniPlayerTap: () -> Void
    var showOverlay: Bool
    var landscapeFullscreen: Bool
    /// The player rides inside a page of the paging scroll view (an audio episode), where being offscreen must never
    /// be read as being gone.
    var pagedInline: Bool = false

    @State private var vm = AVPlayerViewModel.shared
    @State private var lifetime = PlayerViewLifetime()
    @State private var overlayVM = OverlayFullscreenVM.shared
    @State private var scrubberVM = PlayerScrubberOverlayVM()
    @State private var videoZoom: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var isTwoFingerGesturing = false
    @State private var nextPrefetchVideoId: String?

    @ViewBuilder
    private var videoPlayerView: some View {
        Group {
            if isAudioOnly {
                // No video track, so the layer would only sit under the cover art with nothing to
                // show — and an `AVPlayerLayer` costs a re-composite on every frame the menu sheet
                // moves whatever size it is (measured: roughly halves the frames dropped while
                // changing the detent). PiP goes with it, which is no loss: there is no picture.
                Color.black
            } else {
                PlayerViewControllerRepresentable(
                    avPlayer: vm.avPlayer,
                    pipEnabled: player.pipEnabled,
                    autoPip: pipAutoEnable,
                    onPipChanged: { active in player.setPip(active) }
                )
            }
        }
        .aspectRatio(surfaceAspectRatio, contentMode: .fit)
        .overlay {
            if isAudioOnly {
                PodcastArtwork(imageUrls: player.displayArtworkUrls, isMiniPlayer: !hideMiniPlayer)
            }
        }
        .overlay {
            // an audio episode's art is already on screen, uncropped: the placeholder's fill would only show it
            // zoomed until loading finishes
            if player.isLoading != nil && !isAudioOnly {
                ThumbnailPlaceholder(
                    imageUrl: UrlService.getImageUrl(player.video?.displayThumbnailUrl, .max),
                    hideMiniPlayer: hideMiniPlayer,
                    handleMiniPlayerTap: handleMiniPlayerTap
                )
                .transition(.opacity.animation(.easeOut(duration: 0.3)))
            }
        }
        .overlay {
            ScrubberThumbnailOverlay()
        }
        .clipShape(RoundedRectangle(
                    cornerRadius: Const.videoPlayerCornerRadius,
                    style: .continuous))
    }

    private var isAudioOnly: Bool {
        player.video?.isAudioOnly == true
    }

    /// The shape the player surface draws in.
    private var surfaceAspectRatio: Double {
        player.surfaceAspectRatio
    }

    /// Cover art, not a video surface: seeking by double tap, zooming and swiping to the next episode all act on
    /// something that isn't there.
    private var plainArtwork: Bool {
        pagedInline
    }

    /// Named on the art only where the art is the episode's own: where it isn't, the cover on screen already is the
    /// show's.
    @ViewBuilder
    private var subscriptionBadge: some View {
        if player.hasEpisodeArtwork, let subscription = player.video?.subscription {
            PodcastSubscriptionBadge(subscription: subscription)
        }
    }

    /// Only as wide as what's shown: square cover art in a 16:9 box left it padded with black.
    private var miniPlayerWidth: CGFloat {
        PlayerView.miniPlayerHeight * surfaceAspectRatio
    }

    /// The art keeps its own animation so the layout around it can go without one.
    private static let artworkResize: Animation = .bouncy(duration: 0.3)

    @ViewBuilder
    private var playerLayout: some View {
        MiniPlayerLayout(hideMiniPlayer: hideMiniPlayer,
                         handleMiniPlayerTap: handleMiniPlayerTap,
                         animatesLayout: !plainArtwork,
                         miniPlayerWidth: miniPlayerWidth) {
            if plainArtwork {
                artworkLayout
            } else if hideMiniPlayer {
                videoPlayerView
                    .scaleEffect(videoZoom)
                    .offset(x: panOffset.width, y: panOffset.height)
                    .clipShape(RoundedRectangle(
                        cornerRadius: Const.videoPlayerCornerRadius,
                        style: .continuous
                    ))
                    .transitionCover(player.transitionCovered)
                    .modifier(PlayerGestureOverlay(
                        handleSwipe: handleSwipe,
                        onTap: scrubberVM.handleTap,
                        onDoubleTap: scrubberVM.handleSeek,
                        onChapterSwipe: scrubberVM.showBriefly,
                        isExternallyPinching: isTwoFingerGesturing,
                        enabled: true
                    ))
                    .modifier(ZoomPanModifier(zoom: $videoZoom,
                                              offset: $panOffset,
                                              isGesturing: $isTwoFingerGesturing,
                                              enabled: true))
                    .overlay(alignment: .bottomLeading) {
                        subscriptionBadge
                    }
                    .overlay {
                        FullscreenOverlayControls(
                            overlayVM: $overlayVM,
                            enabled: hideMiniPlayer,
                            show: showOverlay
                        )
                    }
                    .overlay {
                        PlayerLoadingTimeout(
                            error: vm.loadError,
                            reloadAction: vm.retryLoad,
                            spinnerDelay: 1,
                            reloadOnTimeout: false
                        )
                    }
                    .overlay(alignment: .bottom) {
                        PlayerScrubberOverlay(vm: scrubberVM)
                    }
            } else {
                videoPlayerView
                    .frame(width: miniPlayerWidth, height: PlayerView.miniPlayerHeight)
                    .transitionCover(player.transitionCovered)
                    .padding(.leading, PlayerView.miniPlayerHorizontalPadding)
                    .overlay {
                        Color.black.opacity(0.000001)
                            .onTapGesture { handleMiniPlayerTap() }
                    }
            }
        }
    }

    /// Cover art in one view across both states instead of a branch each, so its size, rounding and inset interpolate
    /// as the mini player comes and goes rather than popping.
    private var artworkLayout: some View {
        videoPlayerView
            .frame(width: hideMiniPlayer ? nil : miniPlayerWidth,
                   height: hideMiniPlayer ? nil : PlayerView.miniPlayerHeight)
            .transitionCover(player.transitionCovered)
            .allowsHitTesting(false)
            .overlay {
                if hideMiniPlayer {
                    PodcastArtworkTapArea()
                } else {
                    Color.black.opacity(0.000001)
                        .onTapGesture { handleMiniPlayerTap() }
                }
            }
            .overlay(alignment: .bottomLeading) {
                // fades rather than vanishing, so it goes with the art shrinking
                subscriptionBadge
                    .opacity(hideMiniPlayer ? 1 : 0)
            }
            .overlay {
                if hideMiniPlayer {
                    PlayerLoadingTimeout(
                        error: vm.loadError,
                        reloadAction: vm.retryLoad,
                        spinnerDelay: 1,
                        reloadOnTimeout: false
                    )
                }
            }
            .padding(.leading, hideMiniPlayer ? 0 : PlayerView.miniPlayerHorizontalPadding)
            // Scoped to the art rather than wrapping the whole player, and shorter: an animated
            // frame re-runs layout for its enclosing tree once per frame for the length of the curve.
            .animation(Self.artworkResize, value: hideMiniPlayer)
    }

    var body: some View {
        let filter = player.queueFilter(modelContext)
        return corePlayerView
            .background {
                NextQueueVideoReader(filter: filter, videoId: $nextPrefetchVideoId)
                    .id(filter)
            }
            .onChange(of: scenePhase) { _, phase in vm.handleScenePhaseChange(phase) }
            .onChange(of: player.isLoading) { _, new in
                guard new == nil else { return }
                prefetchNextHLS()
            }
            .onChange(of: nextPrefetchVideoId) { _, _ in
                prefetchNextHLS()
            }
            .onDisappear {
                // paged offscreen, not gone: `lifetime` tears the player down when it really is
                guard !pagedInline else { return }
                vm.cleanup(owner: lifetime.token)
            }
    }

    private var corePlayerView: some View {
        playerLayout
            .task { vm.onVideoEnded = handleVideoEnded }
            // Playback commands reach the view model through `PlayerBackend`, not from here.
            .onChange(of: player.video?.youtubeId, initial: true) {
                // before `task`: the outgoing view must not clean up what this one loaded into
                vm.takeOwnership(lifetime.token)
                vm.loadVideoIfNeeded()
                videoZoom = 1.0
                panOffset = .zero
            }
            .onChange(of: landscapeFullscreen) { _, isLandscape in
                scrubberVM.handleLandscapeChanged(isLandscape: isLandscape)
            }
            .onChange(of: player.isPlaying) { _, isPlaying in
                scrubberVM.handlePlayingChanged(isPlaying: isPlaying)
            }
            .onChange(of: player.temporaryPlaybackSpeed) { _, speed in
                scrubberVM.handleTemporarySpeedChanged(active: speed != nil)
            }
    }

    /// Pre-warm the second (next-up) video. Gated on the current video having finished
    /// loading so the prefetch doesn't compete with the current stream for bandwidth.
    private func prefetchNextHLS() {
        guard player.isLoading == nil else { return }
        guard let nextId = nextPrefetchVideoId else {
            vm.discardPrefetch(keeping: player.video?.youtubeId)
            return
        }
        vm.prefetchNext(videoId: nextId)
    }
}

/// The video `PlayerManager.autoSetNextVideo` will pick, so the prefetch pre-warms the same row.
private struct NextQueueVideoReader: View {
    @Environment(PlayerManager.self) private var player
    @Query private var entries: [QueueEntry]

    let filter: QueueFilter
    @Binding var videoId: String?

    init(filter: QueueFilter, videoId: Binding<String?>) {
        self.filter = filter
        _videoId = videoId
        _entries = Query(filter.descriptor(limit: 2))
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .onChange(of: nextVideoId, initial: true) {
                videoId = nextVideoId
            }
    }

    /// Podcast episodes have nothing to prefetch: their stream URL comes with the feed.
    private var nextVideoId: String? {
        let next = filter.nextVideo(skipping: player.video?.youtubeId, in: entries)
        return next?.mediaUrl == nil ? next?.youtubeId : nil
    }
}

/// Ties the player's teardown to how long the view's state lives rather than to `onDisappear`, which a paged
/// `TabView` also fires for a page that has merely scrolled out of sight.
private final class PlayerViewLifetime: Sendable {
    let token = UUID()

    deinit {
        let token = token
        Task { @MainActor in
            AVPlayerViewModel.shared.cleanup(owner: token)
        }
    }
}

/// A tap anywhere on an audio episode's cover art — the show chip included, since that is a label with no touch
/// handling of its own — opens the show, the same navigation the subscription row performs.
