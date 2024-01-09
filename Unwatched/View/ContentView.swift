//
//  ContentView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @State var selectedVideo = SelectedVideo()
    @Query var subscriptions: [Subscription]
    @Query var queue: [QueueEntry]
    @Query var inbox: [InboxEntry]

    @State var selection = "Queue"
    @State var previousSelection = "Queue"

    init() {
        UITabBar.appearance().barTintColor = UIColor(Color.backgroundColor)
        UITabBar.appearance().backgroundImage = UIImage()
        UITabBar.appearance().backgroundColor = UIColor(Color.backgroundColor)
    }

    func markVideoWatched(video: Video) {
        print("markVideoWatched", video)
        VideoManager.markVideoWatched(
            video, modelContext: modelContext
        )
    }

    func loadNewVideos() {
        Task {
            await VideoManager.loadVideos(
                subscriptions: subscriptions,
                defaultVideoPlacement: .inbox,
                modelContext: modelContext
            )
        }
    }

    var body: some View {
        TabView(selection: $selection) {
            VStack {
                Text("VideoPlayer – Should never be visible")
            }
            .tabItem {
                Image(systemName: "chevron.up.circle")
            }
            .tag("VideoPlayer")

            QueueView(loadNewVideos: loadNewVideos)
                .tabItem {
                    Image(systemName: "rectangle.stack")
                }
                .tag("Queue")

            InboxView(loadNewVideos: loadNewVideos)
                .tabItem {
                    Image(systemName: inbox.isEmpty ? "tray" : "tray.full")
                }
                .tag("Inbox")

            LibraryView(loadNewVideos: loadNewVideos)
                .tabItem {
                    Image(systemName: "books.vertical")
                }
                .tag("Library")
        }
        .onChange(of: selection) {
            if selection == "VideoPlayer" {
                selection = previousSelection
                selectedVideo.video = selectedVideo.lastVideo
            }
            previousSelection = selection
        }
        .environment(selectedVideo)
        .sheet(item: $selectedVideo.video) { video in
            ZStack {
                Color.backgroundColor.edgesIgnoringSafeArea(.all)
                VideoPlayer(video: video, markVideoWatched: {
                    markVideoWatched(video: video)
                })
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {

    static var previews: some View {
        ContentView()
    }
}

@Observable class SelectedVideo {
    var video: Video? {
        didSet {
            lastVideo = oldValue
        }
    }
    var lastVideo: Video?
}
