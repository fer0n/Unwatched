//
//  ContentView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(VideoManager.self) var videoManager

    @State private var sheetDetent = PresentationDetent.medium
    @State var selectedVideo: Video?
    @State var lastVideo: Video?
    @State var selection = "Queue"
    @State var previousSelection = "Queue"

    init() {
        UITabBar.appearance().barTintColor = UIColor(Color.backgroundColor)
        UITabBar.appearance().isTranslucent = false
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
            Text("Library")
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
