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

    var body: some View {
        let videoAspectRatio = player.video?.subscription?.customAspectRatio ?? Const.defaultVideoAspectRatio
        let hideMiniPlayer = (
            (navManager.showMenu || navManager.showDescriptionDetail)
                && sheetPos.swipedBelow
        ) || (navManager.showMenu == false && navManager.showDescriptionDetail == false)
        let showFullscreenControls = showFullscreenControlsEnabled && UIDevice.supportsFullscreenControls
        let wideAspect = videoAspectRatio >= Const.consideredWideAspectRatio && landscapeFullscreen

        if player.video != nil {
            HStack {
                if player.embeddingDisabled {
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
                } else {
                    PlayerWebView(playerType: .youtubeEmbedded, onVideoEnded: handleVideoEnded)
                        .aspectRatio(videoAspectRatio, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .frame(maxHeight: landscapeFullscreen ? .infinity : nil)
                        .frame(maxWidth: !landscapeFullscreen ? .infinity : nil)
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
        } else {
            Rectangle()
                .fill(Color.black)
                .aspectRatio(videoAspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)
        }
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
}
