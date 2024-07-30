//
//  PlayerView.swift
//  Unwatched
//

import SwiftUI
import OSLog
import StoreKit
import SwiftData

struct PlayerView: View {
    @AppStorage(Const.fullscreenControlsSetting) var fullscreenControlsSetting: FullscreenControls = .autoHide
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.reloadVideoId) var reloadVideoId = ""
    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1.0

    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player
    @Environment(SheetPositionReader.self) var sheetPos
    @Environment(NavigationManager.self) var navManager
    @Environment(\.requestReview) var requestReview

    @State var controlsVM = FullscreenPlayerControlsVM()

    var landscapeFullscreen = true
    let hasWiderAspectRatio = true
    var markVideoWatched: (_ showMenu: Bool, _ source: VideoSource) -> Void

    var hideMiniPlayer: Bool {
        ((navManager.showMenu || navManager.showDescriptionDetail)
            && sheetPos.swipedBelow)
            || (navManager.showMenu == false && navManager.showDescriptionDetail == false)
    }

    var videoAspectRatio: Double {
        player.video?.subscription?.customAspectRatio ?? Const.defaultVideoAspectRatio
    }

    var showFullscreenControls: Bool {
        fullscreenControlsSetting != .off && UIDevice.supportsFullscreenControls
    }

    var body: some View {
        let wideAspect = videoAspectRatio >= Const.consideredWideAspectRatio && landscapeFullscreen

        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color.black)
                .aspectRatio(videoAspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(
                    Color.black
                        .onTapGesture {
                            controlsVM.setShowControls()
                        }
                )

            if player.video != nil {
                HStack(spacing: 0) {
                    if player.embeddingDisabled {
                        playerWebsite
                            .zIndex(1)
                    } else {
                        playerEmbedded
                            .zIndex(1)
                    }

                    if landscapeFullscreen && showFullscreenControls {
                        FullscreenPlayerControlsWrapper(
                            markVideoWatched: markVideoWatched,
                            controlsVM: controlsVM)
                    }
                }
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
            }
        }
        .persistentSystemOverlays(landscapeFullscreen ? .hidden : .visible)
    }

    @MainActor
    var playerEmbedded: some View {
        HStack {
            PlayerWebView(playerType: .youtubeEmbedded, onVideoEnded: handleVideoEnded)
                .aspectRatio(videoAspectRatio, contentMode: .fit)
                .overlay {
                    overlayFullscreenButton(enabled: showFullscreenControls)

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

            if !hideMiniPlayer {
                miniPlayerContent
            }
        }
        .animation(.bouncy(duration: 0.4), value: hideMiniPlayer)
        .frame(height: !hideMiniPlayer ? Const.playerAboveSheetHeight : nil)
    }

    func overlayFullscreenButton(enabled: Bool) -> some View {
        let isInvisible = player.isPlaying || (enabled && !landscapeFullscreen)

        return Color.white
            .opacity(isInvisible ? .leastNonzeroMagnitude : 1)
            .contentShape(Circle())
            .frame(width: 90, height: 90)
            .onTapGesture {
                player.handlePlayButton()
            }
            .clipShape(Circle())
            .overlay {
                // workaround: when using the button directly, it can't be
                // pressed while being "invisible", only seems to work with
                // Color.white, even an sf symbol doesn't work
                PlayButton(size: 90, enableHaptics: false)
                    .allowsHitTesting(!player.isPlaying)
                    .opacity(isInvisible ? .leastNonzeroMagnitude : 1)
            }
            .animation(.easeInOut(duration: 0.2), value: player.isPlaying)
            .opacity(enabled ? 1 : 0)
    }

    @MainActor
    var playerWebsite: some View {
        ZStack {
            PlayerWebView(playerType: .youtube, onVideoEnded: handleVideoEnded)
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
                .contentShape(Rectangle())
                .onTapGesture(perform: handleMiniPlayerTap)

            PlayButton(size: 30)
                .fontWeight(.black)
        }
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
                _ = VideoService.markVideoWatched(
                    video, modelContext: modelContext
                )
            }
            player.autoSetNextVideo(.continuousPlay)
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
