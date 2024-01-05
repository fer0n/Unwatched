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

    @State private var sheetDetent = PresentationDetent.medium
    @State var selectedVideo: Video?
    @State var lastVideo: Video?
    @State var selection = "Queue"
    @State var previousSelection = "Queue"

    init() {
        UITabBar.appearance().barTintColor = UIColor(Color.backgroundColor)
        UITabBar.appearance().backgroundImage = UIImage()
    }

    func loadNewVideos() {
        print("loadNewVideos")
        print("subscriptions", subscriptions)
        Task {
            let subVideos = await videoManager.loadVideos(
                subscriptions: subscriptions
            )
            videoManager.insertSubscriptionVideos(subVideos, insertVideo: { video in
                modelContext.insert(video)
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

            QueueView(onVideoTap: { video in
                selectedVideo = video
                lastVideo = video
            })
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
            loadNewVideos()
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
