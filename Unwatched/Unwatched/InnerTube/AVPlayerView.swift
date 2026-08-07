#if !os(macOS)
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
    @AppStorage(Const.pipAutoEnable) private var pipAutoEnable = true

    var handleVideoEnded: () -> Void
    var handleSwipe: (SwipeDirecton) -> Void
    var hideMiniPlayer: Bool
    var handleMiniPlayerTap: () -> Void
    var showOverlay: Bool
    var landscapeFullscreen: Bool

    @Query(AVPlayerView.nextEntriesDescriptor) private var nextEntries: [QueueEntry]

    @State private var vm = AVPlayerViewModel()
    @State private var overlayVM = OverlayFullscreenVM.shared
    @State private var scrubberVM = PlayerScrubberOverlayVM()
    @State private var videoZoom: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var isTwoFingerGesturing = false

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
                        PlayerCaptionOverlay()
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
        corePlayerView
            .onChange(of: player.selectedAudioLanguage) { _, lang in vm.handleAudioLanguageChange(lang) }
            .onChange(of: player.selectedVideoQuality) { _, height in vm.handleQualityChange(height: height) }
            .onChange(of: player.selectedCaptionTrackId) { _, id in vm.handleCaptionTrackChange(id) }
            .onChange(of: scenePhase) { _, phase in vm.handleScenePhaseChange(phase) }
            .onChange(of: player.isLoading) { _, new in
                guard new == nil else { return }
                prefetchNextHLS()
            }
            .onChange(of: nextPrefetchVideoId) { _, _ in
                prefetchNextHLS()
            }
            .onDisappear { vm.cleanup() }
    }

    private var corePlayerView: some View {
        playerLayout
            .task { vm.onVideoEnded = handleVideoEnded }
            .onChange(of: player.video?.youtubeId, initial: true) { vm.loadVideoIfNeeded() }
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

    /// The video after the current one in the queue — the one to pre-warm.
    /// The playing video normally sits at queue position 1, so this is position 2
    /// (falling back to position 1 if it isn't the current video, e.g. right after a swap).
    private var nextPrefetchVideoId: String? {
        let first = nextEntries.first?.video
        let second = nextEntries.count > 1 ? nextEntries[1].video : nil
        let next = first?.youtubeId != player.video?.youtubeId ? first : second
        return next?.youtubeId
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

    static var nextEntriesDescriptor: FetchDescriptor<QueueEntry> {
        var descriptor = FetchDescriptor<QueueEntry>(sortBy: [SortDescriptor(\QueueEntry.order)])
        descriptor.fetchLimit = 2
        return descriptor
    }
}
#endif
