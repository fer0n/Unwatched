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
    @AppStorage(Const.fullscreenControlsSetting) var fullscreenControlsSetting: FullscreenControls = .autoHide
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.reloadVideoId) var reloadVideoId = ""
    @AppStorage(Const.playerType) var playerType: PlayerTypeSetting = .youtubeEmbedded

    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player
    @Environment(SheetPositionReader.self) var sheetPos
    @Environment(NavigationManager.self) var navManager
    @Environment(\.requestReview) var requestReview

    @Binding var autoHideVM: AutoHideVM

    #if os(iOS)
    @State var orientation = OrientationManager.shared
    #endif
    @State var overlayVM = OverlayFullscreenVM.shared

    var landscapeFullscreen = true
    var enableHideControls: Bool
    var sleepTimerVM: SleepTimerViewModel
    var compactSize: Bool

    var body: some View {
        ZStack(alignment: .top) {
            VideoPlaceholder(
                autoHideVM: autoHideVM,
                fullscreenControlsSetting: fullscreenControlsSetting,
                landscapeFullscreen: landscapeFullscreen
            )

            HStack(spacing: 0) {
                if player.video == nil {
                    if !compactSize {
                        VideoNotAvailableView()
                            .aspectRatio(player.videoAspectRatio, contentMode: .fit)
                    }
                } else if playerType == .native {
                    #if os(iOS)
                    AVPlayerView(
                        handleVideoEnded: handleVideoEnded,
                        handleSwipe: handleSwipe,
                        hideMiniPlayer: hideMiniPlayer,
                        handleMiniPlayerTap: handleMiniPlayerTap,
                        showOverlay: landscapeFullscreen
                            || (!sheetPos.isMinimumSheet && navManager.showMenu)
                            || navManager.playerTab == .chapterDescription,
                        landscapeFullscreen: landscapeFullscreen
                    )
                    .environment(\.layoutDirection, .leftToRight)
                    #endif
                } else if !player.embeddingDisabled {
                    #if os(iOS)
                    if playerType == .youtubeCustomUI {
                        PlayerEmbeddedCustomUI(
                            autoHideVM: $autoHideVM,
                            overlayVM: $overlayVM,
                            handleVideoEnded: handleVideoEnded,
                            handleSwipe: handleSwipe,
                            landscapeFullscreen: landscapeFullscreen,
                            hideMiniPlayer: hideMiniPlayer,
                            handleMiniPlayerTap: handleMiniPlayerTap
                        )
                        .environment(\.layoutDirection, .leftToRight)
                    } else {
                        embeddedPlayer
                    }
                    #else
                    embeddedPlayer
                    #endif
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

                if layoutMode == .landscapeFullscreen && showFullscreenControls {
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
            .frame(maxWidth: !showFullscreenControls
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
                    .frame(maxHeight: player.tallFullscreenOverlay ? 400 : nil)
                    .opacity(tallOverlayShowControls ? 1 : 0)
                    .animation(.easeInOut, value: tallOverlayShowControls)
                }
            }
            .fullscreenSafeArea(enable: landscapeFullscreen)
            // force reload if value changed (requires settings update)
            .id("videoPlayer-\(playVideoFullscreen)-\(reloadVideoId)")
            .onChange(of: reloadVideoId) {
                autoHideVM.reset()
            }
            .onChange(of: playVideoFullscreen) {
                player.handleHotSwap()
            }
            .overlay {
                if player.video != nil && playerType != .native {
                    PlayerLoadingTimeout()
                        .opacity(hideMiniPlayer ? 1 : 0)
                }
            }
            .onChange(of: landscapeFullscreen, initial: true) {
                sheetPos.landscapeFullscreen = landscapeFullscreen
            }
        }
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
            tallFullscreenOverlay: player.tallFullscreenOverlay,
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
            handleMiniPlayerTap: handleMiniPlayerTap
        )
        .environment(\.layoutDirection, .leftToRight)
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
        Log.info(">handleVideoEnded, continuousPlay: \(continuousPlay)")
        handleRequestReview()

        if continuousPlay {
            if let video = player.video {
                VideoService.setVideoWatched(
                    video, modelContext: modelContext
                )
                // workaround: sync clear is sometimes unreliable (e.g. screen locked);
                // async version ensures the queue entry is actually removed
                _ = VideoService.clearFromEverywhereAsync(video.youtubeId)
            }
            player.autoSetNextVideo(.continuousPlay, modelContext)
        } else {
            player.pause()
            player.seekAbsolute = nil
            player.setVideoEnded(true)
        }
    }

    func handleMiniPlayerTap() {
        sheetPos.setDetentMinimumSheet()
    }

    func handleSwipe(_ direction: SwipeDirecton) {
        // workaround: when using landscapeFullscreen directly, it captures the initial value
        let landscapeFullscreen = SheetPositionReader.shared.landscapeFullscreen
        // workaround: read live value from UserDefaults to avoid stale closure capture
        let hideControlsFullscreen = Const.hideControlsFullscreen.bool ?? false
        func setHideControlsFullscreen(_ value: Bool) {
            UserDefaults.standard.set(value, forKey: Const.hideControlsFullscreen)
        }
        switch direction {
        case .up:
            guard Const.swipeGestureUp.bool ?? true else {
                return
            }
            #if os(macOS)
            return
            #elseif os(visionOS)
            PlayerManager.shared.tempSpeedChange(faster: true)
            return
            #endif
            if enableHideControls {
                setHideControlsFullscreen(true)
            } else if !landscapeFullscreen {
                #if os(iOS)
                if PlayerManager.shared.tallFullscreenOverlay {
                    // already in portrait fullscreen -> reveal menu, stay fullscreen
                    player.setShowMenu()
                } else if PlayerManager.shared.isTallAspectRatio {
                    player.setTallFullscreen(true)
                } else {
                    OrientationManager.changeOrientation(to: .landscapeRight)
                }
                #endif
            } else {
                player.setShowMenu()
            }
        case .down:
            guard Const.swipeGestureDown.bool ?? true else {
                return
            }
            #if os(macOS)
            return
            #elseif os(visionOS)
            PlayerManager.shared.tempSpeedChange()
            return
            #endif
            if enableHideControls && hideControlsFullscreen {
                setHideControlsFullscreen(false)
            } else if landscapeFullscreen {
                #if os(iOS)
                OrientationManager.changeOrientation(to: .portrait)
                #endif
            } else if PlayerManager.shared.tallFullscreenOverlay {
                if NavigationManager.shared.showMenu {
                    // menu is revealed over portrait fullscreen -> hide it, stay fullscreen
                    NavigationManager.shared.showMenu = false
                } else {
                    player.setTallFullscreen(false)
                }
            } else {
                player.setPip(true)
            }
        case .left:
            guard Const.swipeGestureLeft.bool ?? true else {
                return
            }
            #if os(visionOS)
            if PlayerManager.shared.seekForward() {
                OverlayFullscreenVM.shared.show(.seekForward)
            }
            return
            #endif
            if !player.unstarted && player.goToNextChapter() {
                overlayVM.show(.next)
            }
        case .right:
            guard Const.swipeGestureRight.bool ?? true else {
                return
            }
            #if os(visionOS)
            if PlayerManager.shared.seekBackward() {
                OverlayFullscreenVM.shared.show(.seekBackward)
            }
            return
            #endif
            if !player.unstarted && player.goToPreviousChapter() {
                overlayVM.show(.previous)
            }
        }
    }

    static let miniPlayerHorizontalPadding: CGFloat = 15
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
