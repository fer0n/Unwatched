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

    @AppStorage(Const.continuousPlay) var continuousPlay: Bool = false
    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1.0

    @GestureState private var dragState: CGFloat = 0
    @State var continuousPlayWorkaround: Bool = false
    @State var isSubscribedSuccess: Bool?
    @State var hapticToggle: Bool = false

    @Binding var showMenu: Bool

    var body: some View {
        @Bindable var player = player

        VStack(spacing: 10) {

            ZStack {
                if player.video != nil {
                    YoutubeWebViewPlayer(onVideoEnded: handleVideoEnded)
                } else {
                    Rectangle()
                        .fill(Color.backgroundColor)
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            .frame(maxWidth: .infinity)

            Spacer()

            ChapterMiniControlView()

            Spacer()
            Spacer()

            VStack(spacing: 25) {
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
                }
                .padding(.horizontal, 10)
            }
            .padding(.horizontal, 5)

            Spacer()
            Spacer()

            HStack {
                Spacer()
                    .frame(maxWidth: .infinity)
                Button {
                    setShowMenu()
                } label: {
                    VStack {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 30))
                        Text("showMenu")
                            .font(.caption)
                            .padding(.bottom, 3)
                    }
                    .padding(.horizontal)
                }

                Button {
                    if let url = player.video?.url {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Image(systemName: "link")
                        .font(.system(size: 20))
                }
                .padding(5)
                .contextMenu {
                    if let url =  player.video?.url {
                        ShareLink(item: url)
                    }
                }
                .frame(maxWidth: .infinity)

            }
            .padding(.horizontal, 30)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
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
            Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .resizable()
                .frame(width: 90, height: 90)
                .accentColor(.myAccentColor)
                .contentTransition(.symbolEffect(.replace, options: .speed(7)))
        }
    }

    func markVideoWatched() {
        print(">markVideoWatched")
        if let video = player.video {
            setShowMenu()
            setNextVideo(.nextUp)
            VideoService.markVideoWatched(
                video, modelContext: modelContext
            )
        }
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
}
