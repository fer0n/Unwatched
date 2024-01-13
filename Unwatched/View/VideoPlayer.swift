//
//  VideoPlayer.swift
//  Unwatched
//

import SwiftUI

struct VideoPlayer: View {
    @Environment(\.dismiss) var dismiss
    @Environment(NavigationManager.self) private var navManager
    @Environment(\.modelContext) var modelContext
    @AppStorage("playbackSpeed") var playbackSpeed: Double = 1.0
    @AppStorage("continuousPlay") var continuousPlay: Bool = false

    @State private var isPlaying: Bool = true
    @State var continuousPlayWorkaround: Bool = false
    @State var elapsedSeconds: Double?

    @Bindable var video: Video
    var markVideoWatched: () -> Void
    var chapterManager: ChapterManager

    func updateElapsedTime(_ seconds: Double) {
        elapsedSeconds = seconds
    }

    func setPlaybackSpeed(_ value: Double) {
        if video.subscription?.customSpeedSetting != nil {
            video.subscription?.customSpeedSetting = value
        } else {
            playbackSpeed = value
        }
    }

    func getPlaybackSpeed() -> Double {
        video.subscription?.customSpeedSetting ?? playbackSpeed
    }

    func handleVideoEnded() {
        if !continuousPlayWorkaround {
            return
        }
        if navManager.tab == .queue,
           let next = VideoService.getNextVideoInQueue(modelContext) {
            playNextVideo(next)
        }
    }

    func playNextVideo(_ next: Video) {
        print("playNextVideo")
        if let vid = navManager.video {
            VideoService.markVideoWatched(vid, modelContext: modelContext)
        }
        navManager.video = next
        chapterManager.video = next
    }

    var watchedButton: some View {
        Button {
            markVideoWatched()
            dismiss()
        } label: {
            Text("Mark\nWatched")
        }
        .modifier(OutlineToggleModifier(isOn: false))
    }

    var customSettingsButton: some View {
        Toggle(isOn: Binding(get: {
            video.subscription?.customSpeedSetting != nil
        }, set: { value in
            video.subscription?.customSpeedSetting = value ? playbackSpeed : nil
        })) {
            Text("Custom\nSettings")
                .fontWeight(.medium)
        }
        .toggleStyle(OutlineToggleStyle())
        .disabled(video.subscription == nil)
    }

    var continuousPlayButton: some View {
        Toggle(isOn: $continuousPlay) {
            Text("Continuous\nPlay")
                .fontWeight(.medium)
        }
        .toggleStyle(OutlineToggleStyle())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                VStack(spacing: 10) {
                    Text(video.title)
                        .font(.system(size: 20, weight: .heavy))
                        .multilineTextAlignment(.center)
                        .onTapGesture {
                            UIApplication.shared.open(video.url)
                        }

                    Text(video.feedTitle ?? "no subscription found")
                        .textCase(.uppercase)
                        .foregroundColor(.teal)
                        .onTapGesture {
                            if let sub = video.subscription {
                                navManager.pushSubscription(sub)
                                dismiss()
                            }
                        }
                }
                .padding(.vertical)

                YoutubeWebViewPlayer(video: video,
                                     playbackSpeed: Binding(get: getPlaybackSpeed, set: setPlaybackSpeed),
                                     isPlaying: $isPlaying,
                                     updateElapsedTime: updateElapsedTime,
                                     chapterManager: chapterManager,
                                     onVideoEnded: handleVideoEnded
                )
                .aspectRatio(16/9, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .onDisappear {
                    if let seconds = elapsedSeconds {
                        video.elapsedSeconds = seconds
                    }
                }

                VStack {
                    SpeedControlView(selectedSpeed: Binding(
                                        get: getPlaybackSpeed,
                                        set: setPlaybackSpeed)
                    )

                    HStack {
                        customSettingsButton
                        Spacer()
                        watchedButton
                        Spacer()
                        continuousPlayButton
                    }
                    .padding(.horizontal, 5)
                }

                Button {
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .accentColor(.myAccentColor)
                        .contentTransition(.symbolEffect(.replace, options: .speed(7)))
                }
                .padding(40)
                ChapterSelection(video: video, chapterManager: chapterManager)

            }
            .padding(.top, 15)
        }
        .onAppear {
            chapterManager.video = video
            continuousPlayWorkaround = continuousPlay
        }
        .onChange(of: continuousPlay, { _, newValue in
            continuousPlayWorkaround = newValue
        })
    }
}

#Preview {
    VideoPlayer(video: Video.dummy, markVideoWatched: {}, chapterManager: ChapterManager())
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
}
