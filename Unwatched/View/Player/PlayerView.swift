//
//  PlayerView.swift
//  Unwatched
//

import SwiftUI
import OSLog

struct PlayerView: View {
    @AppStorage(Const.showFullscreenControls) var showFullscreenControlsEnabled: Bool = true
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.reloadVideoId) var reloadVideoId = ""

    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player
    @Environment(SheetPositionReader.self) var sheetPos
    @Environment(NavigationManager.self) var navManager

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

    var body: some View {
        let showFullscreenControls = showFullscreenControlsEnabled && UIDevice.supportsFullscreenControls
        let wideAspect = videoAspectRatio >= Const.consideredWideAspectRatio && landscapeFullscreen

        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color.black)
                .aspectRatio(videoAspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)

            if player.video != nil {
                HStack {
                    if player.embeddingDisabled {
                        playerWebsite
                    } else {
                        playerEmbedded
                    }

                    if landscapeFullscreen && showFullscreenControls {
                        FullscreenPlayerControls(markVideoWatched: markVideoWatched)
                            .frame(width: wideAspect ? 0 : nil)
                            .offset(x: wideAspect ? 10 : 0)
                            .fullscreenSafeArea(enable: wideAspect, onlyOffsetRight: true)
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
            }
        }
    }

    var playerEmbedded: some View {
        HStack {
            PlayerWebView(playerType: .youtubeEmbedded, onVideoEnded: handleVideoEnded)
                .aspectRatio(videoAspectRatio, contentMode: .fit)
                .overlay {
                    if !player.isPlaying && !hideMiniPlayer {
                        thumbnailPlaceholder
                    }
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
        .animation(.bouncy(duration: 0.3), value: hideMiniPlayer)
        .frame(height: !hideMiniPlayer ? Const.playerAboveSheetHeight : nil)
    }

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

    func handleVideoEnded() {
        let continuousPlay = UserDefaults.standard.bool(forKey: Const.continuousPlay)
        Logger.log.info(">handleVideoEnded, continuousPlay: \(continuousPlay)")

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
