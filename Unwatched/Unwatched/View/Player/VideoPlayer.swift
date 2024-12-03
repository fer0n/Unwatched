//
//  VideoPlayer.swift
//  Unwatched
//

import SwiftUI
import OSLog
import SwiftData
import UnwatchedShared

struct VideoPlayer: View {
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player
    @Environment(SheetPositionReader.self) var sheetPos
    @Environment(NavigationManager.self) var navManager

    @AppStorage(Const.returnToQueue) var returnToQueue: Bool = false
    @AppStorage(Const.newQueueItemsCount) var newQueueItemsCount: Int = 0

    @State var sleepTimerVM = SleepTimerViewModel()

    var compactSize = false
    var showInfo = true
    var horizontalLayout = false
    var landscapeFullscreen = true

    var body: some View {
        let tallestAspectRatio = player.videoAspectRatio <= Const.tallestAspectRatio + Const.aspectRatioTolerance
        let enableHideControls = UIDevice.requiresFullscreenWebWorkaround && compactSize

        VStack(spacing: 0) {
            PlayerView(landscapeFullscreen: landscapeFullscreen,
                       markVideoWatched: markVideoWatched,
                       setShowMenu: setShowMenu,
                       enableHideControls: enableHideControls,
                       sleepTimerVM: sleepTimerVM)
                .layoutPriority(1)

            if !landscapeFullscreen {
                PlayerContentView(compactSize: compactSize,
                                  showInfo: showInfo && !tallestAspectRatio,
                                  horizontalLayout: horizontalLayout,
                                  enableHideControls: enableHideControls,
                                  setShowMenu: setShowMenu,
                                  markVideoWatched: markVideoWatched,
                                  sleepTimerVM: sleepTimerVM)
            }
        }
        .tint(.neutralAccentColor)
        .contentShape(Rectangle())
        .onChange(of: navManager.showMenu) {
            if navManager.showMenu == false {
                sheetPos.updatePlayerControlHeight()
            }
        }
        .onChange(of: player.isPlaying) {
            if newQueueItemsCount > 0 && navManager.showMenu && player.isPlaying && navManager.tab == .queue {
                newQueueItemsCount = 0
            }
        }
        .ignoresSafeArea(edges: landscapeFullscreen ? .all : [])
        .onChange(of: landscapeFullscreen) {
            if landscapeFullscreen && navManager.showMenu
                && (sheetPos.isVideoPlayer && player.isPlaying || sheetPos.isMinimumSheet) {
                navManager.showMenu = false
            } else if !landscapeFullscreen {
                navManager.showMenu = true
            }
        }
    }

    @MainActor
    func markVideoWatched(showMenu: Bool = true, source: VideoSource = .nextUp) {
        Logger.log.info(">markVideoWatched")
        if let video = player.video {
            try? modelContext.save()

            if showMenu {
                setShowMenu()
                if returnToQueue {
                    navManager.navigateToQueue()
                }
            }

            // workaround: clear on main thread for animation to work (broken in iOS 18.0-2)
            VideoService.setVideoWatched(video, modelContext: modelContext)

            player.autoSetNextVideo(source, modelContext)

            // attempts clearing a second time in the background, as it's so unreliable
            let videoId = video.id
            try? modelContext.save()
            _ = VideoService.setVideoWatchedAsync(videoId)
        }
    }

    func setShowMenu() {
        player.updateElapsedTime()

        print("player.isCompactHeight", player.isCompactHeight)

        if player.video != nil {
            if player.isAnyCompactHeight {
                sheetPos.setDetentMiniPlayer()
            } else {
                sheetPos.setDetentVideoPlayer()
            }
        }
        navManager.showMenu = true
    }
}

#Preview {
    VideoPlayer(compactSize: false,
                showInfo: true,
                horizontalLayout: false,
                landscapeFullscreen: false)
        .modelContainer(DataProvider.previewContainerFilled)
        .environment(NavigationManager.getDummy())
        .environment(PlayerManager.getDummy())
        .environment(ImageCacheManager())
        .environment(RefreshManager())
        .environment(SheetPositionReader())
        .tint(Color.neutralAccentColor)
    // .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
