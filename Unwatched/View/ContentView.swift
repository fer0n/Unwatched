//
//  ContentView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // This will hold the videos loaded from the RSS feeds
    @State private var videos: [Video] = []
    var videoManager = VideoManager();

    @State private var showingSheet = false
    @State private var sheetDetent = PresentationDetent.medium
    @State private var selectedVideo: Video? = nil

    var body: some View {
       List(videoManager.videos) { video in
           VideoListItem(video: video)
            .onTapGesture {
                selectedVideo = video
                showingSheet = true
            }
       }
        .onAppear {
            Task {
                await videoManager.loadVideos()
            }
        }
        .sheet(isPresented: $showingSheet) {
            VideoPlayer(video: selectedVideo)
            .presentationDetents(
                [.medium, .large],
                selection: $sheetDetent
             )
        }
    }
}





// This is a placeholder function, replace with your actual data loading code
func loadVideosFromRSS(feedUrl: String) -> [Video] {
    // Load videos from the RSS feed and return them
    return []
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
