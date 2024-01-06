//
//  ContentView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(VideoManager.self) var videoManager
    @Environment(\.modelContext) var modelContext
    @Query var subscriptions: [Subscription]
    @Query var queue: [QueueEntry]

    @State private var sheetDetent = PresentationDetent.medium
    @State var selectedVideo: Video?
    @State var lastVideo: Video?
    @State var selection = "Queue"
    @State var previousSelection = "Queue"

    init() {
        UITabBar.appearance().barTintColor = UIColor(Color.backgroundColor)
        UITabBar.appearance().backgroundImage = UIImage()
    }

    func loadNewVideos() async {
        print("loadNewVideos")
        let subVideos = await videoManager.loadVideos(
            subscriptions: subscriptions
        )
        print("subVideos", subVideos)
        videoManager.insertSubscriptionVideos(subVideos, insertVideo: { video in
            print("insert video", video)
            modelContext.insert(video)
        })
        for subVideo in subVideos {
            QueueManager.addVideosToQueue(queue, videos: subVideo.videos, insertQueueEntry: { queueEntry in
                modelContext.insert(queueEntry)
            })
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

            Text("Inbox")
                .tabItem {
                    Image(systemName: "tray")
                }
                .tag("Inbox")

            LibraryView()
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
                VideoPlayer(video: video)
                    .presentationDetents(
                        [.medium, .large],
                        selection: $sheetDetent
                    )
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {

    static var previews: some View {
        ContentView()
            .environment(VideoManager())
    }
}
