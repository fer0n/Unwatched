//
//  VideoPlayer.swift
//  Unwatched
//

import SwiftUI

struct VideoPlayer: View {
    @Environment(\.dismiss) var dismiss
    @Environment(NavigationManager.self) private var navManager
    @Environment(Alerter.self) private var alerter
    @Environment(\.modelContext) var modelContext
    @AppStorage("playbackSpeed") var playbackSpeed: Double = 1.0
    @AppStorage("continuousPlay") var continuousPlay: Bool = false

    @State private var isPlaying: Bool = false
    @State var continuousPlayWorkaround: Bool = false
    @State var elapsedSeconds: Double?
    @State var isSubscribedSuccess: Bool?
    @State var isLoading: Bool = false

    @Bindable var video: Video
    var markVideoWatched: () -> Void
    var chapterManager: ChapterManager

    func updateElapsedTime(_ seconds: Double, persist: Bool = false) {
        elapsedSeconds = seconds
        if persist {
            persistTimeChanges()
        }
    }

    func persistTimeChanges() {
        if let seconds = elapsedSeconds {
            video.elapsedSeconds = seconds
        }
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

    func handleSubscription(isSubscribed: Bool) {
        isSubscribedSuccess = nil
        isLoading = true
        let container = modelContext.container

        if isSubscribed {
            guard let subId = video.subscription?.id else {
                print("no subId to un/subscribe")
                isLoading = false
                return
            }
            SubscriptionService.deleteSubscriptions(
                [subId],
                container: container)
            isLoading = false
        } else {
            let channelId = video.subscription?.youtubeChannelId ??
                video.youtubeChannelId
            let subId = video.subscription?.id
            Task {
                do {
                    try await SubscriptionService.addSubscription(
                        channelId: channelId,
                        subsciptionId: subId,
                        modelContainer: container)
                    await MainActor.run {
                        isSubscribedSuccess = true
                    }
                } catch {
                    await MainActor.run {
                        alerter.showError(error)
                    }
                }
                isLoading = false
            }
        }
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

    var subscriptionIcon: String? {
        if isLoading {
            return "circle.circle"
        }
        if isSubscribedSuccess == true {
            return "checkmark"
        }
        if !SubscriptionService.isSubscribed(video) {
            return "arrow.right.circle"
        }
        return nil
    }

    var subscriptionTitle: some View {
        HStack {
            Text(video.subscription?.title ?? "no subscription found")
                .textCase(.uppercase)
            if let icon = subscriptionIcon {
                Image(systemName: icon)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.pulse, options: .repeating, isActive: isLoading)
            }
        }
        .foregroundColor(.teal)
        .onTapGesture {
            if let sub = video.subscription {
                navManager.pushSubscription(sub)
                dismiss()
            }
        }
        .contextMenu {
            let isSubscribed = SubscriptionService.isSubscribed(video)
            Button {
                withAnimation {
                    handleSubscription(isSubscribed: isSubscribed)
                }
            } label: {
                Text(isSubscribed ? "unsubscribe" : "subscribe")
            }
            .disabled(isLoading)
        }
    }

    var playButton: some View {
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
    }

    var webViewPlayer: some View {
        YoutubeWebViewPlayer(video: video,
                             playbackSpeed: Binding(get: getPlaybackSpeed, set: setPlaybackSpeed),
                             isPlaying: $isPlaying,
                             updateElapsedTime: updateElapsedTime,
                             chapterManager: chapterManager,
                             onVideoEnded: handleVideoEnded
        )
        .aspectRatio(16/9, contentMode: .fit)
        .frame(maxWidth: .infinity)
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
                    subscriptionTitle
                }
                .padding(.vertical)
                webViewPlayer
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
                playButton
                ChapterSelection(video: video, chapterManager: chapterManager)
            }
            .padding(.top, 15)
        }
        .onAppear {
            chapterManager.video = video
            continuousPlayWorkaround = continuousPlay
        }
        .onDisappear {
            persistTimeChanges()
        }
        .onChange(of: continuousPlay, { _, newValue in
            continuousPlayWorkaround = newValue
        })
    }
}

#Preview {
    VideoPlayer(video: Video.getDummy(), markVideoWatched: {}, chapterManager: ChapterManager())
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
}
