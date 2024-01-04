//
//  VideoPlayer.swift
//  Unwatched
//

import SwiftUI

struct VideoPlayer: View {
    var video: Video?
    @State private var playbackSpeed: Float = 1.0

    var body: some View {
        VStack {
            if let video = video {
                WebViewWrapper(videoID: video.youtubeId, playbackSpeed: $playbackSpeed)
                    .aspectRatio(16/9, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                Text(video.title)
                    .font(.system(size: 20, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .padding(.vertical)
                Spacer()
                Slider(value: $playbackSpeed, in: 0.5...2.0, step: 0.1)
                    .padding(.vertical)
            } else {
                Text("No video selected")
            }
        }
        .padding(.top, 25)
        .padding(.horizontal)
    }
}

 #Preview {
     VideoPlayer(video: Video.dummy)
 }
