//
//  VideoPlayer.swift
//  Unwatched
//

import SwiftUI

struct VideoPlayer: View {
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager
    @Environment(Alerter.self) private var alerter
    @Environment(PlayerManager.self) var player
    @Environment(SheetPositionReader.self) var sheetPos

    @AppStorage(Const.continuousPlay) var continuousPlay: Bool = false
    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1.0
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false

    @GestureState private var dragState: CGFloat = 0
    @State var continuousPlayWorkaround: Bool = false
    @State var isSubscribedSuccess: Bool?
    @State var hapticToggle: Bool = false
    @State var shareText: MyShareLink?

    @Binding var showMenu: Bool

    var compactSize = false
    var showInfo = true
    var showFullscreenButton = false

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
                    HStack {
                        SpeedControlView(selectedSpeed: $player.playbackSpeed)
                        customSettingsButton
                    }

                    HStack {
                        watchedButton
                            .frame(maxWidth: .infinity)
                        playButton
                        continuousPlayButton
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
                    footer
                        .padding(.horizontal, 30)
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
        .sensoryFeedback(Const.sensoryFeedback, trigger: continuousPlay)
    }

    @MainActor
    var footer: some View {
        HStack {
            if let video = player.video {
                Button(action: toggleBookmark) {
                    Image(systemName: video.bookmarkedDate != nil
                            ? "bookmark.fill"
                            : "bookmark")
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(maxWidth: .infinity)
            }

            Button {
                setShowMenu()
            } label: {
                VStack {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 30))
                    Text("showMenu")
                        .font(.caption)
                        .textCase(.uppercase)
                        .padding(.bottom, 3)
                }
                .padding(.horizontal)
            }

            if let video = player.video {
                Image(systemName: "link")
                    .font(.system(size: 20))
                    .onTapGesture {
                        if let url = video.url {
                            UIApplication.shared.open(url)
                        }
                    }
                    .onLongPressGesture {
                        if let url =  player.video?.url {
                            shareText = MyShareLink(url: url)
                        }
                    }
                    .frame(maxWidth: .infinity)
            }
        }
        .sheet(item: $shareText) { shareText in
            ActivityView(url: shareText.url)
                .presentationDetents([.medium, .large])
                .ignoresSafeArea(.all)
        }
    }

    var watchedButton: some View {
        Button {
            markVideoWatched()
            hapticToggle.toggle()
        } label: {
            Image(systemName: "checkmark")
        }
        .modifier(OutlineToggleModifier(isOn: player.isConsideredWatched))
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

    var continuousPlayButton: some View {
        Toggle(isOn: $continuousPlay) {
            Image(systemName: "text.line.first.and.arrowtriangle.forward")
        }
        .toggleStyle(OutlineToggleStyle())
    }

    var playButton: some View {
        Button {
            player.isPlaying.toggle()
            hapticToggle.toggle()
        } label: {
            let size: Double = (player.embeddingDisabled || compactSize)
                ? 70
                : 90
            Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .resizable()
                .frame(width: size, height: size)
                .accentColor(.myAccentColor)
                .contentTransition(.symbolEffect(.replace, options: .speed(7)))
        }
    }

    func toggleBookmark() {
        if let video = player.video {
            VideoService.toggleBookmark(video, modelContext)
        }
    }

    func markVideoWatched() {
        print(">markVideoWatched")
        if let video = player.video {
            setShowMenu()
            setNextVideo(.nextUp)
            _ = VideoService.markVideoWatched(
                video, modelContext: modelContext
            )
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

    func handleVideoEnded() {
        guard continuousPlayWorkaround == true else {
            player.pause()
            return
        }
        print(">handleVideoEnded")
        if let video = player.video {
            VideoService.markVideoWatched(
                video, modelContext: modelContext
            )
        }
        setNextVideo(.continuousPlay)
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
        guard let next = VideoService.getNextVideoInQueue(modelContext) else {
            print("no next video found")
            return
        }
        print("next", next.title)
        player.setNextVideo(next, source)
    }
}

#Preview {
    VideoPlayer(showMenu: .constant(false))
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager.getDummy())
        .environment(Alerter())
        .environment(PlayerManager.getDummy())
        .environment(SheetPositionReader())
}
