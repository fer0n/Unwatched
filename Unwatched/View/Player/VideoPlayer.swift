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

    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1.0
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.showFullscreenControls) var showFullscreenControls: Bool = true
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

    var body: some View {
        @Bindable var player = player
        let layout = compactSize
            ? AnyLayout(HStackLayout(spacing: 25))
            : AnyLayout(VStackLayout(spacing: 25))

        VStack(spacing: 0) {
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
                            .aspectRatio(16/9, contentMode: .fit)
                            .frame(maxHeight: landscapeFullscreen ? .infinity : nil)
                            .frame(maxWidth: !landscapeFullscreen ? .infinity : nil)
                    }

                    if landscapeFullscreen && showFullscreenControls {
                        FullscreenPlayerControls(markVideoWatched: markVideoWatched)
                    }
                }
                .frame(maxWidth: !showFullscreenControls ? .infinity : nil)
                // force reload if value changed (requires settings update)
                .id("videoPlayer-\(playVideoFullscreen)")
                .onChange(of: playVideoFullscreen) {
                    player.handleHotSwap()
                }
            } else {
                Rectangle()
                    .fill(Color.backgroundColor)
                    .aspectRatio(16/9, contentMode: .fit)
                    .frame(maxWidth: .infinity)
            }

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
                            customSettingsButton
                        }

                        HStack {
                            watchedButton
                                .frame(maxWidth: .infinity)
                            PlayButton(size:
                                        (player.embeddingDisabled || compactSize)
                                        ? 70
                                        : 90
                            )
                            NextVideoButton(markVideoWatched: markVideoWatched)
                                .frame(maxWidth: .infinity)
                            if showFullscreenButton {
                                fullscreenButton
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
                    sheetPos.playerControlHeight = size.height
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
        .onChange(of: player.isPlaying) {
            if hasNewQueueItems == true && navManager.showMenu && player.isPlaying && navManager.tab == .queue {
                hasNewQueueItems = false
            }
        }
        .sheet(item: $browserUrl) { browserUrl in
            BrowserView(startUrl: browserUrl)
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
        print("openBrowserUrl", url)
        let browserAsTab = UserDefaults.standard.bool(forKey: Const.browserAsTab)
        print("browserAsTab", browserAsTab)
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

    var watchedButton: some View {
        Button {
            markVideoWatched()
            hapticToggle.toggle()
        } label: {
            Image(systemName: "checkmark")
        }
        .modifier(OutlineToggleModifier(isOn: player.isConsideredWatched))
        .padding(3)
        .contextMenu {
            if player.video != nil {
                Button {
                    player.clearVideo()
                } label: {
                    Label("clearVideo", systemImage: "xmark")
                }
            }
        }
    }

    var customSettingsButton: some View {
        Toggle(isOn: Binding(get: {
            player.video?.subscription?.customSpeedSetting != nil
        }, set: { value in
            player.video?.subscription?.customSpeedSetting = value ? playbackSpeed : nil
            hapticToggle.toggle()
        })) {
            Image(systemName: "lock")
        }
        .help("customSpeedSettings")
        .toggleStyle(OutlineToggleStyle(isSmall: true))
        .disabled(player.video?.subscription == nil)
    }

    var fullscreenButton: some View {
        Toggle(isOn: $playVideoFullscreen) {
            Image(systemName: playVideoFullscreen
                    ? "rectangle.inset.filled"
                    : "rectangle.slash.fill")
        }
        .toggleStyle(OutlineToggleStyle())
    }

    func markVideoWatched(showMenu: Bool = true, source: VideoSource = .nextUp) {
        Logger.log.info(">markVideoWatched")
        if let video = player.video {
            if showMenu {
                setShowMenu()
            }
            setNextVideo(source)
            _ = VideoService.markVideoWatched(
                video, modelContext: modelContext
            )
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
            setNextVideo(.continuousPlay)
        } else {
            player.pause()
            player.seekPosition = nil
            player.setVideoEnded(true)
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

    func setNextVideo(_ source: VideoSource) {
        let next = VideoService.getNextVideoInQueue(modelContext)
        Logger.log.info("setNextVideo \(next?.title ?? "no video found")")
        withAnimation {
            player.setNextVideo(next, source)
        }
    }
}

#Preview {
    VideoPlayer(showMenu: .constant(false))
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager.getDummy())
        .environment(PlayerManager.getDummy())
        .environment(SheetPositionReader())
}
