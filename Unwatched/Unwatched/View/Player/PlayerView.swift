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
                } else if !player.embeddingDisabled {
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

                if landscapeFullscreen && showFullscreenControls {
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
                if player.video != nil {
                    PlayerLoadingTimeout()
                        .opacity(hideMiniPlayer ? 1 : 0)
                }
            }
            .onChange(of: landscapeFullscreen, initial: true) {
                sheetPos.landscapeFullscreen = landscapeFullscreen
            }
        }
        .dateSelectorSheet()
        .persistentSystemOverlays(
            landscapeFullscreen || controlsHidden
                ? .hidden
                : .visible
        )
    }

    var showLeft: Bool {
        #if os(iOS)
        orientation.hasLeftEmpty
        #else
        false
        #endif
    }

    var hideMiniPlayer: Bool {
        !(
            navManager.showMenu
                && !sheetPos.swipedBelow
                && !landscapeFullscreen
        )
    }

    var showFullscreenControls: Bool {
        fullscreenControlsSetting != .disabled
            && Device.supportsFullscreenControls
            && hideMiniPlayer
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
        switch direction {
        case .up:
            guard Const.swipeGestureUp.bool ?? true else {
                return
            }
            #if os(macOS)
            return
            #endif
            if enableHideControls {
                hideControlsFullscreen = true
            } else if !landscapeFullscreen {
                #if os(iOS)
                OrientationManager.changeOrientation(to: .landscapeRight)
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
            #endif
            if enableHideControls && hideControlsFullscreen {
                hideControlsFullscreen = false
            } else if landscapeFullscreen {
                #if os(iOS)
                OrientationManager.changeOrientation(to: .portrait)
                #endif
            } else {
                player.setPip(true)
            }
        case .left:
            guard Const.swipeGestureLeft.bool ?? true else {
                return
            }
            if !player.unstarted && player.goToNextChapter() {
                overlayVM.show(.next)
            }
        case .right:
            guard Const.swipeGestureRight.bool ?? true else {
                return
            }
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
