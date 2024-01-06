//
//  ContentView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @Query var subscriptions: [Subscription]
    @Query var queue: [QueueEntry]
    @Query var inbox: [InboxEntry]

    @State var selectedVideo: Video?
    @State var lastVideo: Video?
    @State var selection = "Queue"
    @State var previousSelection = "Queue"

    init() {
        UITabBar.appearance().barTintColor = UIColor(Color.backgroundColor)
        UITabBar.appearance().backgroundImage = UIImage()
        UITabBar.appearance().backgroundColor = UIColor(Color.backgroundColor)
    }

    func markVideoWatched(video: Video) {
        print("markVideoWatched", video)
        if let queueEntry = queue.first(where: { entry in
            entry.video.youtubeId == video.youtubeId
        }) {
            print("queueEntry", queueEntry)
            VideoManager.markVideoWatched(
                queueEntry: queueEntry,
                queue: queue,
                modelContext: modelContext
            )
        }
    }

    func loadNewVideos() async {
        Task {
            await VideoManager.loadVideos(
                subscriptions: subscriptions,
                defaultVideoPlacement: .inbox,
                queue: queue,
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

            QueueView(
                onVideoTap: { video in
                    selectedVideo = video
                    lastVideo = video
                },
                loadNewVideos: loadNewVideos)
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
                selectedVideo = lastVideo
            }
            previousSelection = selection
        }
        .onAppear {
            Task {
                await loadNewVideos()
            }
        }
        .sheet(item: $selectedVideo) { video in
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
