//
//  VideoPlayer.swift
//  Unwatched
//

import SwiftUI

struct VideoPlayer: View {
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager
    @Environment(PlayerManager.self) var player
    @Environment(SheetPositionReader.self) var sheetPos

    @AppStorage(Const.continuousPlay) var continuousPlay: Bool = false
    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1.0
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false

    @GestureState private var dragState: CGFloat = 0
    @State var continuousPlayWorkaround: Bool = false
    @State var isSubscribedSuccess: Bool?
    @State var hapticToggle: Bool = false

    @Binding var showMenu: Bool

    var compactSize = false
    var showInfo = true
    var showFullscreenButton = false
    @State var sleepTimerVM = SleepTimerViewModel()

    var body: some View {
        @Bindable var player = player
        let layout = compactSize
            ? AnyLayout(HStackLayout(spacing: 25))
            : AnyLayout(VStackLayout(spacing: 25))

        VStack(spacing: 0) {
            if player.video != nil {
                ZStack {
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
                            .frame(maxWidth: .infinity)
                    }
                }
                // force reload if value changed (requires settings update
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
                        nextVideoButton
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
                    VideoPlayerFooter(setShowMenu: setShowMenu,
                                      sleepTimerVM: sleepTimerVM,
                                      onSleepTimerEnded: onSleepTimerEnded)
                }
            }
            .innerSizeTrackerModifier(onChange: { size in
                sheetPos.playerControlHeight = size.height
            })
        }
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
        .onChange(of: continuousPlay, { _, newValue in
            continuousPlayWorkaround = newValue
        })
        .onChange(of: player.video?.subscription) {
            // workaround to update ui, doesn't work without
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
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

    var nextVideoButton: some View {
        ZStack {
            let manualNext = !continuousPlay
                && player.videoEnded
                && !player.isPlaying
            Button {
                if manualNext {
                    markVideoWatched(showMenu: false, source: .userInteraction)
                } else {
                    continuousPlay.toggle()
                }
                hapticToggle.toggle()
            } label: {
                Image(systemName: manualNext
                        ? "forward.end.fill"
                        : "text.line.first.and.arrowtriangle.forward"
                )
                .modifier(OutlineToggleModifier(isOn: manualNext ? false : continuousPlay))
                .contentTransition(.symbolEffect(.replace, options: .speed(7)))
            }
            .padding(3)
            .contextMenu {
                if !manualNext {
                    Button {
                        markVideoWatched(showMenu: false, source: .userInteraction)
                    } label: {
                        Label("nextVideo", systemImage: "forward.end.fill")
                    }
                }
            }
        }
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
        print(">markVideoWatched")
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
        print(">handleVideoEnded")

        if continuousPlayWorkaround == true {
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
        print("next", next?.title ?? "no video found")
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
