//
//  VideoListItem.swift
//  Unwatched
//

import SwiftUI

struct VideoListItem: View {
    let video: Video

    var body: some View {
        // Define how each video should be displayed in the list
        // This is a placeholder, replace with your actual UI code
        Text("\(video.title) (\(video.youtubeId))")
    }
}

// #Preview {
//    VideoListItem()
// }
