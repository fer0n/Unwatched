//
//  VideoPlayer.swift
//  Unwatched
//

import SwiftUI

struct VideoPlayer: View {
    var video: Video?
    @State private var playbackSpeed: Float = 1.0
    
    var body: some View {
        if let video = video {
            Text(video.title)
           WebViewWrapper(videoID: video.youtubeId, playbackSpeed: $playbackSpeed)
               .frame(width: 400, height: 300)
            Slider(value: $playbackSpeed, in: 0.5...2.0, step: 0.1)
                .padding()
        } else {
            Text("No video selected")
        }
    }
}

//#Preview {
//    VideoPlayer()
//}

