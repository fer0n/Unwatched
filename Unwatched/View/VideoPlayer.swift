//
//  VideoPlayer.swift
//  Unwatched
//

import SwiftUI

struct VideoPlayer: View {
    @Environment(\.dismiss) var dismiss

    @Bindable var video: Video
    var markVideoWatched: () -> Void
    @State private var isCustomSetting: Bool = false
    @AppStorage("playbackSpeed") var playbackSpeed: Double = 1.0

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

    var watchedButton: some View {
        Button {
            markVideoWatched()
            dismiss()
        } label: {
            Text("Mark Watched")
                .bold()
                .padding(.horizontal, 25)
                .padding(.vertical, 15)
        }
        .background(Color.myAccentColor)
        .foregroundColor(.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
    }

    var customSettingsButton: some View {
        Toggle(isOn: Binding(get: {
            video.subscription?.customSpeedSetting != nil
        }, set: { value in
            video.subscription?.customSpeedSetting = value ? playbackSpeed : nil
        })) {
            Text("Custom settings for this feed")
        }
        .disabled(video.subscription == nil)
        .padding()
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(video.title)
                .font(.system(size: 20, weight: .heavy))
                .multilineTextAlignment(.center)
                .padding(.vertical)
            Text(video.subscription?.title ?? "no subscription found")

            WebViewWrapper(videoID: video.youtubeId,
                           playbackSpeed: Binding(get: getPlaybackSpeed, set: setPlaybackSpeed)
            )
            .aspectRatio(16/9, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 20))

            Spacer()
            VStack {
                Slider(value: Binding(get: getPlaybackSpeed, set: setPlaybackSpeed),
                       in: 0.5...2.0, step: 0.1)

                customSettingsButton
            }
            .padding(.vertical)

            watchedButton
        }
        .padding(.top, 25)
        .padding(.horizontal)
    }
}

#Preview {
    VideoPlayer(video: Video.dummy, markVideoWatched: {})
}
