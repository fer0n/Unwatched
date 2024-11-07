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
                       enableHideControls: enableHideControls)
                .layoutPriority(1)

            if !landscapeFullscreen {
                PlayerControls(compactSize: compactSize,
                               showInfo: showInfo && !tallestAspectRatio,
                               horizontalLayout: horizontalLayout,
                               enableHideControls: enableHideControls,
                               setShowMenu: setShowMenu,
                               markVideoWatched: markVideoWatched,
                               sleepTimerVM: sleepTimerVM)
                    .padding(.vertical, compactSize ? 5 : 0)
                    .showMenuGesture(disableGesture: compactSize, setShowMenu: setShowMenu)
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
            if landscapeFullscreen && player.isPlaying && navManager.showMenu && sheetPos.isVideoPlayer {
                navManager.showMenu = false
                sheetPos.hadMenuOpen = true
            } else if !landscapeFullscreen && sheetPos.hadMenuOpen {
                sheetPos.hadMenuOpen = false
                navManager.showMenu = true
            }
        }
    }

    @MainActor
    func markVideoWatched(showMenu: Bool = true, source: VideoSource = .nextUp) {
        Logger.log.info(">markVideoWatched")
        try? modelContext.save()
        if let video = player.video {
            if showMenu {
                setShowMenu()
                if returnToQueue {
                    navManager.navigateToQueue()
                }
            }
            player.autoSetNextVideo(source, modelContext)
            VideoService.markVideoWatched(
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
    // sub.customAspectRatio = 18/9

    context.insert(sub)
    sub.videos = [video]

    try? context.save()

    return VideoPlayer(compactSize: false,
                       showInfo: true,
                       horizontalLayout: false,
                       landscapeFullscreen: false)
        .modelContainer(container)
        .environment(NavigationManager.getDummy())
        .environment(player)
        .environment(SheetPositionReader())
        .environment(RefreshManager())
        .environment(ImageCacheManager())
        .tint(Color.neutralAccentColor)
    // .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
