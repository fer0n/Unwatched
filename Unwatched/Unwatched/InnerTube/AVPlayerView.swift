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

    @State private var vm = AVPlayerViewModel.shared
    @State private var ownerToken = UUID()
    @State private var overlayVM = OverlayFullscreenVM.shared
    @State private var scrubberVM = PlayerScrubberOverlayVM()
    @State private var videoZoom: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var isTwoFingerGesturing = false
    @State private var nextPrefetchVideoId: String?

    @ViewBuilder
    private var videoPlayerView: some View {
        PlayerViewControllerRepresentable(
            avPlayer: vm.avPlayer,
            pipEnabled: player.pipEnabled,
            autoPip: pipAutoEnable,
            onPipChanged: { active in player.setPip(active) }
        )
        .aspectRatio(player.videoAspectRatio, contentMode: .fit)
        .overlay {
            if player.isLoading != nil {
                ThumbnailPlaceholder(
                    imageUrl: UrlService.getImageUrl(player.video?.thumbnailUrl, .max),
                    hideMiniPlayer: hideMiniPlayer,
                    handleMiniPlayerTap: handleMiniPlayerTap
                )
                .transition(.opacity.animation(.easeOut(duration: 0.3)))
            }
        }
        .overlay {
            ScrubberThumbnailOverlay()
        }
        .transitionCover(player.transitionCovered)
        .clipShape(RoundedRectangle(
                    cornerRadius: Const.videoPlayerCornerRadius,
                    style: .continuous))
    }

    @ViewBuilder
    private var playerLayout: some View {
        MiniPlayerLayout(hideMiniPlayer: hideMiniPlayer, handleMiniPlayerTap: handleMiniPlayerTap) {
            if hideMiniPlayer {
                videoPlayerView
                    .scaleEffect(videoZoom)
                    .offset(x: panOffset.width, y: panOffset.height)
                    .clipShape(RoundedRectangle(
                        cornerRadius: Const.videoPlayerCornerRadius,
                        style: .continuous
                    ))
                    .modifier(PlayerGestureOverlay(
                        handleSwipe: handleSwipe,
                        onTap: scrubberVM.handleTap,
                        onDoubleTap: scrubberVM.handleSeek,
                        onChapterSwipe: scrubberVM.showBriefly,
                        isExternallyPinching: isTwoFingerGesturing
                    ))
                    .modifier(ZoomPanModifier(zoom: $videoZoom, offset: $panOffset, isGesturing: $isTwoFingerGesturing))
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
                    .frame(width: 107, height: 60)
                    .padding(.leading, PlayerView.miniPlayerHorizontalPadding)
                    .overlay {
                        Color.black.opacity(0.000001)
                            .onTapGesture { handleMiniPlayerTap() }
                    }
            }
        }
    }

    var body: some View {
        let filter = player.queueFilter(modelContext)
        return corePlayerView
            .background {
                NextQueueVideoReader(filter: filter, videoId: $nextPrefetchVideoId)
                    .id(filter)
            }
            .onChange(of: player.selectedAudioLanguage) { _, lang in vm.handleAudioLanguageChange(lang) }
            .onChange(of: player.selectedVideoQuality) { _, height in vm.handleQualityChange(height: height) }
            .onChange(of: scenePhase) { _, phase in vm.handleScenePhaseChange(phase) }
            .onChange(of: player.isLoading) { _, new in
                guard new == nil else { return }
                prefetchNextHLS()
            }
            .onChange(of: nextPrefetchVideoId) { _, _ in
                prefetchNextHLS()
            }
            .onDisappear { vm.cleanup(owner: ownerToken) }
    }

    private var corePlayerView: some View {
        playerLayout
            .task { vm.onVideoEnded = handleVideoEnded }
            .onChange(of: player.video?.youtubeId, initial: true) {
                // before `task`: the outgoing view must not clean up what this one loaded into
                vm.takeOwnership(ownerToken)
                vm.loadVideoIfNeeded()
            }
            .onChange(of: player.video?.youtubeId) { videoZoom = 1.0; panOffset = .zero }
            .onChange(of: landscapeFullscreen) { _, isLandscape in
                scrubberVM.handleLandscapeChanged(isLandscape: isLandscape)
            }
            .onChange(of: player.isPlaying) { _, isPlaying in
                vm.handleIsPlayingChange()
                scrubberVM.handlePlayingChanged(isPlaying: isPlaying)
            }
            .onChange(of: player.temporaryPlaybackSpeed) { _, speed in
                scrubberVM.handleTemporarySpeedChanged(active: speed != nil)
            }
            .onChange(of: player.seekAbsolute) { vm.applyAbsoluteSeek() }
            .onChange(of: player.playbackSpeed) { vm.handlePlaybackSpeedChange() }
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
///
/// Its own view, keyed by the filter: a `@Query`'s descriptor only changes when the view is
/// re-initialised, and rebuilding `AVPlayerView` would tear down the player.
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

    private var nextVideoId: String? {
        filter.nextVideo(skipping: player.video?.youtubeId, in: entries)?.youtubeId
    }
}
