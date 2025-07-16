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
    @State var appNotificationVM = AppNotificationVM()

    var landscapeFullscreen = true
    var markVideoWatched: (_ showMenu: Bool, _ source: VideoSource) -> Void
    var setShowMenu: (() -> Void)?
    var enableHideControls: Bool
    var sleepTimerVM: SleepTimerViewModel

    var body: some View {
        ZStack(alignment: .top) {
            VideoPlaceholder(
                autoHideVM: autoHideVM,
                fullscreenControlsSetting: fullscreenControlsSetting,
                landscapeFullscreen: landscapeFullscreen
            )

            if player.video != nil {
                HStack(spacing: 0) {
                    if player.embeddingDisabled {
                        playerWebsite
                            .environment(\.layoutDirection, .leftToRight)
                            .zIndex(1)
                    } else {
                        playerEmbedded
                            .zIndex(1)
                            .environment(\.layoutDirection, .leftToRight)
                    }

                    if landscapeFullscreen && showFullscreenControls {
                        FullscreenPlayerControlsWrapper(
                            markVideoWatched: markVideoWatched,
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
                    PlayerLoadingTimeout()
                        .opacity(hideMiniPlayer ? 1 : 0)
                }
                .onChange(of: landscapeFullscreen, initial: true) {
                    sheetPos.landscapeFullscreen = landscapeFullscreen
                }
            }
        }
        .appNotificationOverlay($appNotificationVM)
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

    @MainActor
    var playerEmbedded: some View {
        HStack {
            PlayerWebView(
                overlayVM: $overlayVM,
                autoHideVM: $autoHideVM,
                appNotificationVM: $appNotificationVM,
                playerType: .youtubeEmbedded,
                onVideoEnded: handleVideoEnded,
                setShowMenu: setShowMenu,
                handleSwipe: handleSwipe
            )
            .aspectRatio(player.videoAspectRatio, contentMode: .fit)
            .overlay {
                FullscreenOverlayControls(
                    overlayVM: $overlayVM,
                    enabled: showFullscreenControls,
                    show: landscapeFullscreen || (!sheetPos.isMinimumSheet && navManager.showMenu),
                    markVideoWatched: markVideoWatched
                )

                thumbnailPlaceholder
                    .opacity(showEmbeddedThumbnail ? 1 : 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .frame(maxHeight: landscapeFullscreen && !hideMiniPlayer ? .infinity : nil)
            .frame(maxWidth: !landscapeFullscreen && !hideMiniPlayer ? .infinity : nil)
            .frame(width: !hideMiniPlayer ? 107 : nil,
                   height: !hideMiniPlayer ? 60 : nil)
            .thumbnailQualityWorkaround(enable: !hideMiniPlayer)
            .onTapGesture {
                if !hideMiniPlayer {
                    handleMiniPlayerTap()
                }
            }
            .padding(.leading, !hideMiniPlayer ? 5 : 0)

            if !hideMiniPlayer {
                miniPlayerContent
            }
        }
        .animation(.bouncy(duration: 0.4), value: hideMiniPlayer)
        .frame(height: !hideMiniPlayer ? Const.playerAboveSheetHeight : nil)
    }

    @MainActor
    var playerWebsite: some View {
        ZStack {
            PlayerWebView(
                overlayVM: $overlayVM,
                autoHideVM: $autoHideVM,
                appNotificationVM: $appNotificationVM,
                playerType: .youtube,
                onVideoEnded: handleVideoEnded,
                handleSwipe: handleSwipe
            )
            .frame(maxHeight: .infinity)
            .frame(maxWidth: .infinity)
            .mask(LinearGradient(gradient: Gradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.9),
                    .init(color: .clear, location: 1)
                ]
            ), startPoint: .top, endPoint: .bottom))

            Color.black
                .opacity(!hideMiniPlayer ? 1 : 0)

            HStack {
                if !hideMiniPlayer {
                    thumbnailPlaceholder
                        .thumbnailQualityWorkaround(enable: !hideMiniPlayer)
                        .padding(.leading, 5)
                    miniPlayerContent
                }
            }
            .frame(height: !hideMiniPlayer ? Const.playerAboveSheetHeight : nil)
            .frame(maxHeight: .infinity, alignment: .top)
            .opacity(!hideMiniPlayer ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.4), value: !hideMiniPlayer)
    }

    @ViewBuilder var miniPlayerContent: some View {
        if let video = player.video {
            Text(video.title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fontWeight(.medium)
                .contentShape(Rectangle())
                .onTapGesture(perform: handleMiniPlayerTap)

            PlayButton(size: 30, enableHelper: false)
                .fontWeight(.black)
                .padding(.trailing, 5)
        }
    }

    var thumbnailPlaceholder: some View {
        CachedImageView(imageUrl: player.video?.thumbnailUrl) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: !hideMiniPlayer ? 107 : nil,
                       height: !hideMiniPlayer ? 60 : nil)
        } placeholder: {
            Color.backgroundColor
        }
        .aspectRatio(Const.defaultVideoAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onTapGesture(perform: handleMiniPlayerTap)
        .id(player.video?.thumbnailUrl)
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
                setShowMenu?()
            }
        case .down:
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
            if !player.unstarted && player.goToNextChapter() {
                overlayVM.show(.next)
            }
        case .right:
            if !player.unstarted && player.goToPreviousChapter() {
                overlayVM.show(.previous)
            }
        }
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
                      markVideoWatched: { _, _ in },
                      enableHideControls: false,
                      sleepTimerVM: SleepTimerViewModel())
        .modelContainer(container)
        .environment(NavigationManager.getDummy())
        .environment(player)
        .environment(SheetPositionReader())
        .environment(RefreshManager())
        .environment(ImageCacheManager())
        .tint(Color.neutralAccentColor)
}

extension View {
    func thumbnailQualityWorkaround(enable: Bool) -> some View {
        self
            .scaleEffect(enable ? 0.83 : 1)
            .padding(.horizontal, enable ? -(107 * 0.17) / 2 : 0)
        // ^ workaround: if website is loaded while being mini, the cover image resolution is too low
        // 107 width with 16/9 is the minimum size to still get the higher resolution
    }
}
