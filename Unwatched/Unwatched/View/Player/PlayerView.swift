//
//  PlayerView.swift
//  Unwatched
//

import SwiftUI
import OSLog
import StoreKit
import SwiftData
import UnwatchedShared

struct PlayerView: View {
    @AppStorage(Const.hideControlsFullscreen) var hideControlsFullscreen = false
    @Environment(\.landscapeControlBand) var landscapeControlBand
    @AppStorage(Const.fullscreenControlsSetting) var fullscreenControlsSetting: FullscreenControls = .autoHide
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.reloadVideoId) var reloadVideoId = ""
    @AppStorage(Const.playerType) var playerType: PlayerTypeSetting = .youtubeEmbedded

    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player
    @Environment(SheetPositionReader.self) var sheetPos
    @Environment(NavigationManager.self) var navManager
    @Environment(\.requestReview) var requestReview
    @Environment(AppNotificationVM.self) var appNotificationVM

    @Binding var autoHideVM: AutoHideVM

    #if os(iOS)
    @State var orientation = OrientationManager.shared
    #endif
    @State var overlayVM = OverlayFullscreenVM.shared
    /// `playerType` is what the user picked; `activeType` is what's on screen while a switch to or
    /// from the native player warms up.
    @State var switchManager = PlayerSwitchManager.shared

    var landscapeFullscreen = true
    var enableHideControls: Bool
    var sleepTimerVM: SleepTimerViewModel
    var compactSize: Bool
    /// The player sits inside a page of the paging scroll view rather than above it (see
    /// `VideoPlayer.usePodcastLayout`), so paging must not be mistaken for teardown.
    var pagedInline: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            VideoPlaceholder(
                autoHideVM: autoHideVM,
                fullscreenControlsSetting: fullscreenControlsSetting,
                landscapeFullscreen: landscapeFullscreen
            )
            // placeholder overlay: spans the screen, stays behind video and controls
            #if os(iOS)
            .overlay {
                if layoutMode == .landscapeFullscreen && showSideControls {
                    FullscreenEdgeSwipeArea(
                        autoHideVM: $autoHideVM,
                        showLeft: showLeft
                    )
                }
            }
            #endif

            HStack(spacing: 0) {
                if player.video == nil {
                    if !compactSize {
                        VideoNotAvailableView()
                            .aspectRatio(player.videoAspectRatio, contentMode: .fit)
                    }
                } else if switchManager.activeType == .native {
                    AVPlayerView(
                        handleVideoEnded: handleVideoEnded,
                        handleSwipe: handleSwipe,
                        hideMiniPlayer: hideMiniPlayer,
                        handleMiniPlayerTap: handleMiniPlayerTap,
                        showOverlay: showFullscreenOverlay,
                        landscapeFullscreen: landscapeFullscreen,
                        pagedInline: pagedInline
                    )
                    .environment(\.layoutDirection, .leftToRight)
                } else if !player.embeddingDisabled {
                    embeddedPlayer
                } else {
                    PlayerWebsite(
                        autoHideVM: $autoHideVM,
                        overlayVM: $overlayVM,
                        handleVideoEnded: handleVideoEnded,
                        handleSwipe: handleSwipe,
                        hideMiniPlayer: hideMiniPlayer,
                        handleMiniPlayerTap: handleMiniPlayerTap
                    )
                    .environment(\.layoutDirection, .leftToRight)
                }

                if layoutMode == .landscapeFullscreen && showSideControls {
                    FullscreenPlayerControlsWrapper(
                        autoHideVM: $autoHideVM,
                        sleepTimerVM: sleepTimerVM,
                        showLeft: showLeft)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
            #if os(iOS)
            .environment(\.layoutDirection, showLeft
                            ? .rightToLeft
                            : .leftToRight)
            #endif
            .frame(maxWidth: !showSideControls
                    ? .infinity
                    : nil)
            .overlay(alignment: .trailing) {
                if showTallFullscreenOverlay {
                    FullscreenPlayerControls(
                        autoHideVM: $autoHideVM,
                        arrowEdge: .trailing,
                        sleepTimerVM: sleepTimerVM,
                        showLeft: false
                    )
                    .frame(width: 60)
                    .frame(maxHeight: player.tallFullscreenActive ? 400 : nil)
                    .opacity(tallOverlayShowControls ? 1 : 0)
                    .animation(.easeInOut, value: tallOverlayShowControls)
                }
            }
            .fullscreenSafeArea(enable: landscapeFullscreen)
            // force reload if value changed (requires settings update)
            .id("videoPlayer-\(playVideoFullscreen)-\(reloadVideoId)-\(switchManager.activeType.usesWebPlayer)")
            .environment(\.sleepTimerVM, sleepTimerVM)
            .onChange(of: reloadVideoId) {
                autoHideVM.reset()
            }
            .onChange(of: playVideoFullscreen) {
                player.handleHotSwap()
            }
            // initial: catches a setting change made while no player view was around
            .onChange(of: playerType, initial: true) {
                switchManager.handleSettingChanged()
            }
            .overlay {
                if player.video != nil && switchManager.activeType != .native {
                    PlayerLoadingTimeout()
                        .opacity(hideMiniPlayer ? 1 : 0)
                }
            }
            .onChange(of: landscapeFullscreen, initial: true) {
                sheetPos.landscapeFullscreen = landscapeFullscreen
            }
        }
        .onChange(of: !player.unstarted || player.video == nil) { _, done in
            if done { player.endVideoTransition() }
        }
        #if os(iOS)
        .verticalSwipeGesture(
            disableGesture: player.video != nil,
            onSwipeUp: { handleSwipe(.up) },
            onSwipeDown: { handleSwipe(.down) }
        )
        #endif
        .dateSelectorSheet()
        #if !os(visionOS)
        .persistentSystemOverlays(
            layoutMode.isFullscreen || controlsHidden
                ? .hidden
                : .visible
        )
        #endif
    }

    var layoutMode: PlayerLayoutMode {
        PlayerLayoutMode(
            landscapeFullscreen: landscapeFullscreen,
            tallFullscreenOverlay: player.tallFullscreenActive,
            hideMiniPlayer: hideMiniPlayer
        )
    }

    @ViewBuilder
    var embeddedPlayer: some View {
        PlayerEmbedded(
            autoHideVM: $autoHideVM,
            overlayVM: $overlayVM,
            handleVideoEnded: handleVideoEnded,
            handleSwipe: handleSwipe,
            showFullscreenControls: showFullscreenControls,
            landscapeFullscreen: landscapeFullscreen,
            showEmbeddedThumbnail: showEmbeddedThumbnail,
            hideMiniPlayer: hideMiniPlayer,
            handleMiniPlayerTap: handleMiniPlayerTap,
            customUI: customUI
        )
        .environment(\.layoutDirection, .leftToRight)
    }

    /// Only iOS has the replacement controls the custom UI needs.
    var customUI: Bool {
        #if os(iOS)
        switchManager.activeType == .youtubeCustomUI
        #else
        false
        #endif
    }

    var showLeft: Bool {
        #if os(iOS)
        orientation.hasLeftEmpty
        #else
        false
        #endif
    }

    var hideMiniPlayer: Bool {
        sheetPos.hideMiniPlayer(showMenu: navManager.showMenu, landscapeFullscreen: landscapeFullscreen)
    }

    var showSideControls: Bool {
        showFullscreenControls && landscapeControlBand == nil
    }

    var showFullscreenControls: Bool {
        fullscreenControlsSetting != .disabled
            && Device.supportsFullscreenControls
            && hideMiniPlayer
    }

    var showTallFullscreenOverlay: Bool {
        player.isTallAspectRatio
            && layoutMode == .portraitFullscreen
            && showFullscreenControls
    }

    var tallOverlayShowControls: Bool {
        fullscreenControlsSetting == .enabled
            || !player.isPlaying
            || autoHideVM.showControls
    }

    var controlsHidden: Bool {
        !(fullscreenControlsSetting == .enabled || autoHideVM.showControls)
            && hideControlsFullscreen
    }

    var showEmbeddedThumbnail: Bool {
        !hideMiniPlayer && player.unstarted
    }

    @MainActor
    func handleRequestReview() {
        navManager.handleRequestReview {
            requestReview()
        }
    }

    @MainActor
    func handleVideoEnded() {
        if player.isRepeating {
            player.seek(to: 0)
            return
        }

        let continuousPlay = UserDefaults.standard.bool(forKey: Const.continuousPlay)
        Log.player.info(">handleVideoEnded, continuousPlay: \(continuousPlay)")
        onVideoEnded()

        if continuousPlay {
            if let video = player.video {
                VideoService.setVideoWatched(
                    video, modelContext: modelContext
                )
                // workaround: sync clear is sometimes unreliable (e.g. screen locked);
                // async version ensures the queue entry is actually removed
                _ = VideoService.clearFromEverywhereAsync(video.youtubeId)

                TinyUndoManager.shared.registerAction(
                    .moveToQueue([video.persistentModelID], position: 0)
                )
            }
            player.autoSetNextVideo(.continuousPlay, modelContext)
        } else if Const.markWatchedOnEnded.bool ?? true {
            player.markVideoWatched(showMenu: false)
        } else {
            player.pause()
            player.setVideoEnded(true)
        }
    }

    func handleMiniPlayerTap() {
        sheetPos.setDetentMinimumSheet()
    }

    /// Paged inline (an audio episode) draws the artwork layout, which has no fullscreen overlay
    /// to show. Reading `playerTab` for a value nobody uses made this view depend on the tab, so
    /// switching pages rebuilt the whole player surface.
    var showFullscreenOverlay: Bool {
        guard !pagedInline else { return false }
        return landscapeFullscreen
            || (!sheetPos.isMinimumSheet && navManager.showMenu)
            || navManager.playerTab == .chapterDescription
    }

    static let miniPlayerHorizontalPadding: CGFloat = 15
    static let miniPlayerHeight: CGFloat = 60
}

extension PlayerView {
    func onVideoEnded() {
        handleRequestReview()
        Signal.interaction("Player.Finished")
        SubscribeSuggestion.handleVideoEnded(player.video, appNotificationVM)
    }
}

#Preview {
    let container = DataProvider.previewContainer
    let context = ModelContext(container)
    let player = PlayerManager()
    let video = Video.getDummy()

    let ch1 = Chapter(title: "hi", time: 1)
    context.insert(ch1)
    video.chapters = [ch1]

    context.insert(video)
    player.video = video

    let sub = Subscription.getDummy()
    context.insert(sub)
    sub.videos = [video]

    try? context.save()

    return PlayerView(autoHideVM: .constant(AutoHideVM()),
                      landscapeFullscreen: true,
                      enableHideControls: false,
                      sleepTimerVM: SleepTimerViewModel(),
                      compactSize: false)
        .modelContainer(container)
        .environment(NavigationManager.getDummy())
        .environment(player)
        .environment(SheetPositionReader())
        .environment(RefreshManager())
        .environment(ImageCacheManager())
        .appNotificationOverlay()
        .tint(Color.neutralAccentColor)
}
