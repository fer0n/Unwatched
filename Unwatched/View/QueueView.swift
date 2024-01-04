//
//  QueueView.swift
//  Unwatched
//

import SwiftUI

struct QueueView: View {
    var onVideoTap: (_ video: Video) -> Void
    @Environment(VideoManager.self) var videoManager

    var body: some View {
        List(videoManager.videos) { video in
            VideoListItem(video: video)
                .onTapGesture {
                    onVideoTap(video)
                }
        }
        .clipped()
        .listStyle(PlainListStyle())
    }
}

 #Preview {
     QueueView(onVideoTap: { _ in })
         .environment(VideoManager.dummy)
 }
