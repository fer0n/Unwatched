//
//  VideoPlayer.swift
//  Unwatched
//

import SwiftUI
import OSLog

struct VideoPlayer: View {
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player
    @Environment(SheetPositionReader.self) var sheetPos
    @Environment(NavigationManager.self) var navManager

    @AppStorage(Const.hasNewQueueItems) var hasNewQueueItems = false

    var compactSize = false
    var showInfo = true
    var showFullscreenButton = false

    var landscapeFullscreen = true
    let hasWiderAspectRatio = true

    var body: some View {
        VStack(spacing: 0) {
            PlayerView(landscapeFullscreen: landscapeFullscreen,
                       markVideoWatched: markVideoWatched)

            if !landscapeFullscreen {
                PlayerControls(compactSize: compactSize,
                               setShowMenu: setShowMenu,
                               showInfo: showInfo,
                               markVideoWatched: markVideoWatched,
                               showFullscreenButton: showFullscreenButton)
            }
        }
        .tint(.neutralAccentColor)
        .contentShape(Rectangle())
        .showMenuGesture(disableGesture: compactSize, setShowMenu: setShowMenu)
        .onChange(of: navManager.showMenu) {
            if navManager.showMenu == false {
                sheetPos.updatePlayerControlHeight()
            }
        }
        .onChange(of: player.isPlaying) {
            if hasNewQueueItems == true && navManager.showMenu && player.isPlaying && navManager.tab == .queue {
                hasNewQueueItems = false
            }
        }
        .ignoresSafeArea(edges: landscapeFullscreen ? .all : [])
        .onChange(of: landscapeFullscreen) {
            if landscapeFullscreen && player.isPlaying && navManager.showMenu && sheetPos.isVideoPlayer {
                navManager.showMenu = false
                sheetPos.hadMenuOpen = true
            } else if !landscapeFullscreen && sheetPos.hadMenuOpen {
                sheetPos.hadMenuOpen = false
                navManager.showMenu = true
            }
        }
    }

    func markVideoWatched(showMenu: Bool = true, source: VideoSource = .nextUp) {
        Logger.log.info(">markVideoWatched")
        if let video = player.video {
            if showMenu {
                setShowMenu()
            }
            player.autoSetNextVideo(source)
            _ = VideoService.markVideoWatched(
                video, modelContext: modelContext
            )
        }
    }

    func setShowMenu() {
        player.updateElapsedTime()
        if player.video != nil {
            if !player.isPlaying || player.embeddingDisabled {
                sheetPos.setDetentMiniPlayer()
            } else {
                sheetPos.setDetentVideoPlayer()
            }
        }
        navManager.showMenu = true
    }
}

#Preview {
    VideoPlayer(landscapeFullscreen: false)
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager.getDummy())
        .environment(PlayerManager.getDummy())
        .environment(SheetPositionReader())
        .environment(RefreshManager())
}
