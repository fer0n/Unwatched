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
    @Environment(RefreshManager.self) var refresher

    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1.0
    @AppStorage(Const.hasNewQueueItems) var hasNewQueueItems = false

    @GestureState private var dragState: CGFloat = 0
    @State var isSubscribedSuccess: Bool?
    @State var hapticToggle: Bool = false
    @State var browserUrl: BrowserUrl?

    @Binding var showMenu: Bool

    var compactSize = false
    var showInfo = true
    var showFullscreenButton = false
    @State var sleepTimerVM = SleepTimerViewModel()

    var landscapeFullscreen = true
    let hasWiderAspectRatio = true

    var body: some View {
        @Bindable var player = player
        let layout = compactSize
            ? AnyLayout(HStackLayout(spacing: 25))
            : AnyLayout(VStackLayout(spacing: 25))

        VStack(spacing: 0) {
            PlayerView(landscapeFullscreen: landscapeFullscreen,
                       markVideoWatched: markVideoWatched)

            if !landscapeFullscreen {
                VStack(spacing: 10) {
                    if !player.embeddingDisabled && !compactSize {
                        Spacer()
                    }

                    ChapterMiniControlView(setShowMenu: setShowMenu, showInfo: showInfo)

                    if !player.embeddingDisabled && !compactSize {
                        Spacer()
                        Spacer()
                    }

                    layout {
                        if compactSize {
                            SleepTimer(viewModel: sleepTimerVM, onEnded: onSleepTimerEnded)
                        }

                        HStack {
                            SpeedControlView(selectedSpeed: $player.playbackSpeed)
                            CustomSettingsButton(playbackSpeed: $playbackSpeed)
                        }

                        HStack {
                            WatchedButton(markVideoWatched: markVideoWatched)
                                .frame(maxWidth: .infinity)

                            PlayButton(size:
                                        (player.embeddingDisabled || compactSize)
                                        ? 70
                                        : 90
                            )
                            .fontWeight(.black)
                            NextVideoButton(markVideoWatched: markVideoWatched)
                                .frame(maxWidth: .infinity)
                            if showFullscreenButton {
                                FullscreenButton(playVideoFullscreen: $playVideoFullscreen)
                                Spacer()
                            }

                        }
                        .padding(.horizontal, 10)
                    }
                    .padding(.horizontal, compactSize ? 20 : 5)

                    if !player.embeddingDisabled && !compactSize {
                        Spacer()
                        Spacer()
                    }
                    if !compactSize {
                        VideoPlayerFooter(openBrowserUrl: openBrowserUrl,
                                          setShowMenu: setShowMenu,
                                          sleepTimerVM: sleepTimerVM,
                                          onSleepTimerEnded: onSleepTimerEnded)
                    }
                }
                .innerSizeTrackerModifier(onChange: { size in
                    sheetPos.setPlayerControlHeight(size.height - Const.playerControlPadding)
                })
            }
        }
        .tint(.neutralAccentColor)
        .contentShape(Rectangle())
        .simultaneousGesture(
            compactSize
                ? nil
                : DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .updating($dragState) { value, state, _ in
                    state = value.translation.height
                    if state < -30 {
                        setShowMenu()
                    }
                }
        )
        .onChange(of: player.video?.subscription) {
            // workaround to update ui, doesn't work without
        }
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
        .sheet(item: $browserUrl) { browserUrl in
            BrowserView(container: modelContext.container,
                        refresher: refresher,
                        startUrl: browserUrl)
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .ignoresSafeArea(edges: landscapeFullscreen ? .all : [])
        .persistentSystemOverlays(landscapeFullscreen ? .hidden : .visible)
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

    func openBrowserUrl(_ url: BrowserUrl) {
        let browserAsTab = UserDefaults.standard.bool(forKey: Const.browserAsTab)
        if browserAsTab {
            sheetPos.setDetentMiniPlayer()
            navManager.openUrlInApp(url)
        } else {
            browserUrl = url
        }
    }

    func onSleepTimerEnded(_ fadeOutSeconds: Double?) {
        var seconds = player.currentTime ?? 0
        player.pause()
        if let fadeOutSeconds = fadeOutSeconds, fadeOutSeconds > seconds {
            seconds -= fadeOutSeconds
        }
        player.updateElapsedTime(seconds)
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
        showMenu = true
    }

}

#Preview {
    VideoPlayer(showMenu: .constant(false), landscapeFullscreen: false)
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager.getDummy())
        .environment(PlayerManager.getDummy())
        .environment(SheetPositionReader())
        .environment(RefreshManager())
}
