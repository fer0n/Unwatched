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
    @AppStorage(Const.hideControlsFullscreen) var hideControlsFullscreen = false

    @State var sleepTimerVM = SleepTimerViewModel()
    @State var autoHideVM = AutoHideVM.shared

    var compactSize = false
    var showInfo = true
    var horizontalLayout = false
    var landscapeFullscreen = true
    let hideControls: Bool

    var body: some View {
        let tallestAspectRatio = player.videoAspectRatio <= Const.tallestAspectRatio + Const.aspectRatioTolerance
        let enableHideControls = Device.requiresFullscreenWebWorkaround && compactSize

        VStack(spacing: 0) {
            PlayerView(autoHideVM: $autoHideVM,
                       landscapeFullscreen: landscapeFullscreen,
                       markVideoWatched: markVideoWatched,
                       setShowMenu: setShowMenu,
                       enableHideControls: enableHideControls,
                       sleepTimerVM: sleepTimerVM)
                .layoutPriority(1)

            if !landscapeFullscreen {
                if compactSize {
                    PlayerControls(compactSize: compactSize,
                                   showInfo: showInfo,
                                   horizontalLayout: horizontalLayout,
                                   enableHideControls: enableHideControls,
                                   hideControls: hideControls,
                                   setShowMenu: setShowMenu,
                                   markVideoWatched: markVideoWatched,
                                   sleepTimerVM: sleepTimerVM,
                                   minHeight: .constant(nil),
                                   autoHideVM: $autoHideVM)
                        .padding(.top, 3)
                } else {
                    PlayerContentView(compactSize: compactSize,
                                      showInfo: showInfo && !tallestAspectRatio,
                                      horizontalLayout: horizontalLayout,
                                      enableHideControls: enableHideControls,
                                      hideControls: hideControls,
                                      setShowMenu: setShowMenu,
                                      markVideoWatched: markVideoWatched,
                                      sleepTimerVM: sleepTimerVM, autoHideVM: $autoHideVM)
                }
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
            if player.video?.isNew == true {
                player.video?.isNew = false
            }
        }
        .ignoresSafeArea(edges: landscapeFullscreen ? .all : [])
        .onChange(of: landscapeFullscreen) {
            handleLandscapeFullscreenChange(landscapeFullscreen)
        }
        .hideCursorOnInactive(
            after: 2,
            isEnabled: hideCursorEnabled,
            onChange: { isVisible in
                autoHideVM.setKeepVisible(isVisible, "hover")
            }
        )
    }

    @MainActor
    func handleLandscapeFullscreenChange(_ landscapeFullscreen: Bool) {
        if landscapeFullscreen && navManager.showMenu
            && (sheetPos.isVideoPlayer && player.isPlaying || sheetPos.isMinimumSheet) {
            navManager.showMenu = false
        } else if !landscapeFullscreen {
            // switching back to portrait
            if navManager.showMenu {
                // menu was open in landscape mode -> show menu in portrait
                sheetPos.setDetentVideoPlayer()
            } else {
                // show menu and keep previous detent
                navManager.showMenu = true
            }
        }
    }

    @MainActor
    func markVideoWatched(showMenu: Bool = true, source: VideoSource = .nextUp) {
        Logger.log.info(">markVideoWatched")
        if let video = player.video {
            try? modelContext.save()

            #if os(macOS)
            navManager.toggleSidebar(show: true)
            #else
            if showMenu {
                setShowMenu()
                if returnToQueue {
                    navManager.navigateToQueue()
                }
            }
            #endif

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
        if player.video != nil && !sheetPos.landscapeFullscreen {
            if player.limitHeight {
                sheetPos.setDetentMiniPlayer()
            } else {
                sheetPos.setDetentVideoPlayer()
            }
        }
        navManager.showMenu = true
    }

    var hideCursorEnabled: Bool {
        player.isPlaying
            && (
                Device.isMac && navManager.isSidebarHidden
                    || !Device.isIphone && hideControlsFullscreen
            )
            && !autoHideVM.showDescription
    }
}

#Preview {
    VideoPlayer(compactSize: false,
                showInfo: true,
                horizontalLayout: false,
                landscapeFullscreen: false,
                hideControls: false)
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager.getDummy())
        .environment(PlayerManager.getDummy())
        .environment(ImageCacheManager())
        .environment(RefreshManager())
        .environment(SheetPositionReader())
        .tint(Color.neutralAccentColor)
    // .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
