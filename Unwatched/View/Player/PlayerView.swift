//
//  PlayerView.swift
//  Unwatched
//

import SwiftUI
import OSLog
import StoreKit
import SwiftData

struct PlayerView: View {
    @AppStorage(Const.hideControlsFullscreen) var hideControlsFullscreen = false
    @AppStorage(Const.fullscreenControlsSetting) var fullscreenControlsSetting: FullscreenControls = .autoHide
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.reloadVideoId) var reloadVideoId = ""
    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1.0

    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player
    @Environment(SheetPositionReader.self) var sheetPos
    @Environment(NavigationManager.self) var navManager
    @Environment(\.requestReview) var requestReview

    @State var autoHideVM = AutoHideVM()
    @State var overlayVM = OverlayFullscreenVM()

    var landscapeFullscreen = true
    let hasWiderAspectRatio = true
    var markVideoWatched: (_ showMenu: Bool, _ source: VideoSource) -> Void
    var setShowMenu: (() -> Void)?

    var hideMiniPlayer: Bool {
        ((navManager.showMenu || navManager.showDescriptionDetail)
            && sheetPos.swipedBelow)
            || (navManager.showMenu == false && navManager.showDescriptionDetail == false)
    }

    var videoAspectRatio: Double {
        player.aspectRatio
            ?? player.video?.subscription?.customAspectRatio
            ?? Const.defaultVideoAspectRatio
    }

    var showFullscreenControls: Bool {
        fullscreenControlsSetting != .disabled && UIDevice.supportsFullscreenControls
    }

    var body: some View {
        let wideAspect = videoAspectRatio >= Const.consideredWideAspectRatio && landscapeFullscreen
        ZStack(alignment: .top) {
            Rectangle()
                .fill(landscapeFullscreen ? .black : Color.playerBackgroundColor)
                .aspectRatio(videoAspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(backgroundTapRecognizer)
                .animation(.default, value: videoAspectRatio)

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
                            autoHideVM: $autoHideVM)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                }
                .environment(\.layoutDirection, autoHideVM.positionLeft
                                ? .rightToLeft
                                : .leftToRight)
                .frame(maxWidth: !showFullscreenControls || wideAspect
                        ? .infinity
                        : nil)
                .fullscreenSafeArea(enable: wideAspect)
                // force reload if value changed (requires settings update)
                .id("videoPlayer-\(playVideoFullscreen)-\(reloadVideoId)")
                .onChange(of: playVideoFullscreen) {
                    player.handleHotSwap()
                }
                .onChange(of: playbackSpeed) {
                    // workaround: doesn't update otherwise
                }
                .onChange(of: reloadVideoId) {
                    autoHideVM.reset()
                }
                .overlay {
                    PlayerLoadingTimeout()
                        .opacity(hideMiniPlayer ? 1 : 0)
                }
            }
        }
        .persistentSystemOverlays(
            landscapeFullscreen || controlsHidden
                ? .hidden
                : .visible
        )
        .statusBarHidden(controlsHidden)
    }

    var controlsHidden: Bool {
        !(
            fullscreenControlsSetting == .enabled || autoHideVM.showControls
        ) && hideControlsFullscreen
    }

    @MainActor
    var playerEmbedded: some View {
        HStack {
            PlayerWebView(
                overlayVM: $overlayVM,
                autoHideVM: $autoHideVM,
                playerType: .youtubeEmbedded,
                onVideoEnded: handleVideoEnded,
                setShowMenu: setShowMenu
            )
            .aspectRatio(videoAspectRatio, contentMode: .fit)
            .overlay {
                OverlayFullscreenButton(
                    overlayVM: $overlayVM,
                    enabled: showFullscreenControls,
                    landscapeFullscreen: landscapeFullscreen
                )

                thumbnailPlaceholder
                    .opacity(!player.isPlaying && !hideMiniPlayer ? 1 : 0)
            }
            .animation(.easeInOut(duration: player.isPlaying ? 0.3 : 0)
                        .delay(player.isPlaying ? 0.3 : 0),
                       value: player.isPlaying)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .frame(maxHeight: landscapeFullscreen && !hideMiniPlayer ? .infinity : nil)
            .frame(maxWidth: !landscapeFullscreen && !hideMiniPlayer ? .infinity : nil)
            .frame(width: !hideMiniPlayer ? 89 : nil,
                   height: !hideMiniPlayer ? 50 : nil)
            .onTapGesture {
                if !hideMiniPlayer {
                    handleMiniPlayerTap()
                }
            }
            .padding(.leading, !hideMiniPlayer ? 2 : 0)

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
                playerType: .youtube,
                onVideoEnded: handleVideoEnded
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
                .padding(.trailing, !hideMiniPlayer ? 1 : 0)
        }
    }

    var backgroundTapRecognizer: some View {
        HStack {
            Color.black
                .onTapGesture {
                    autoHideVM.setShowControls(positionLeft: true)
                }
            Color.black
                .onTapGesture {
                    autoHideVM.setShowControls(positionLeft: false)
                }
        }
        .disabled(fullscreenControlsSetting != .autoHide)
    }

    var thumbnailPlaceholder: some View {
        CachedImageView(imageHolder: player.video) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: !hideMiniPlayer ? 89 : nil,
                       height: !hideMiniPlayer ? 50 : nil)
        } placeholder: {
            Color.backgroundColor
        }
        .aspectRatio(Const.defaultVideoAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onTapGesture(perform: handleMiniPlayerTap)
        .id(player.video?.thumbnailUrl)
    }

    @MainActor
    func handleRequestReview() {
        navManager.askForReviewPoints += 1
        if navManager.askForReviewPoints >= Const.askForReviewPointThreashold {
            navManager.askForReviewPoints = -40
            requestReview()
        }
    }

    @MainActor
    func handleVideoEnded() {
        let continuousPlay = UserDefaults.standard.bool(forKey: Const.continuousPlay)
        Logger.log.info(">handleVideoEnded, continuousPlay: \(continuousPlay)")
        handleRequestReview()

        if continuousPlay {
            if let video = player.video {
                VideoService.markVideoWatched(
                    video, modelContext: modelContext
                )
            }
            player.autoSetNextVideo(.continuousPlay, modelContext)
        } else {
            player.pause()
            player.seekPosition = nil
            player.setVideoEnded(true)
        }
    }

    func handleMiniPlayerTap() {
        navManager.showMenu = false
        navManager.showDescriptionDetail = false
    }
}

#Preview {
    let container = DataController.previewContainer
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

    return PlayerView(landscapeFullscreen: false,
                      markVideoWatched: { _, _ in })
        .modelContainer(container)
        .environment(NavigationManager.getDummy())
        .environment(player)
        .environment(SheetPositionReader())
        .environment(RefreshManager())
        .environment(ImageCacheManager())
        .tint(Color.neutralAccentColor)
}
