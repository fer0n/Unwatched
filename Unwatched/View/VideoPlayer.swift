//
//  VideoPlayer.swift
//  Unwatched
//

import SwiftUI

struct VideoPlayer: View {
    @Environment(\.dismiss) var dismiss

    @Bindable var video: Video
    var markVideoWatched: () -> Void
    @State private var playbackSpeed: Float = 1.0

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
        .background(Color.accentColor)
        .foregroundColor(.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(video.title)
                .font(.system(size: 20, weight: .heavy))
                .multilineTextAlignment(.center)
                .padding(.vertical)

            WebViewWrapper(videoID: video.youtubeId, playbackSpeed: $playbackSpeed)
                .aspectRatio(16/9, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Spacer()
            Slider(value: $playbackSpeed, in: 0.5...2.0, step: 0.1)
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
