//
//  ContentView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var showVideoPlayerSheet = false
    @State private var sheetDetent = PresentationDetent.medium
    @State var selectedVideo: Video?
    @Environment(VideoManager.self) var videoManager
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
                showVideoPlayerSheet = true
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
                showVideoPlayerSheet = true
                selection = previousSelection
            }
            previousSelection = selection
        }

        .sheet(isPresented: $showVideoPlayerSheet) {
            VideoPlayer(video: selectedVideo)
                .presentationDetents(
                    [.medium, .large],
                    selection: $sheetDetent
                )
        }
        .onAppear {
            Task {
                await videoManager.loadVideos()
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
