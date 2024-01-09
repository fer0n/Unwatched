//
//  ContentView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

enum Tab {
    case videoPlayer
    case inbox
    case queue
    case library
}

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @State var navManager = NavigationManager()
    @Query var subscriptions: [Subscription]
    @Query var queue: [QueueEntry]
    @Query var inbox: [InboxEntry]

    @MainActor
    init() {
        UITabBar.appearance().barTintColor = UIColor(Color.backgroundColor)
        UITabBar.appearance().backgroundImage = UIImage()
        UITabBar.appearance().backgroundColor = UIColor(Color.backgroundColor)
    }

    func markVideoWatched(video: Video) {
        VideoService.markVideoWatched(
            video, modelContext: modelContext
        )
    }

    func loadNewVideos() {
        VideoService.loadNewVideosInBg(subscriptions: subscriptions,
                                       modelContext: modelContext)
    }

    var body: some View {
        @Bindable var navManager = navManager
        TabView(selection: $navManager.tab) {
            VStack {
                Text("VideoPlayer – Should never be visible")
            }
            .tabItem {
                Image(systemName: "chevron.up.circle")
            }
            .tag(Tab.videoPlayer)

            QueueView(loadNewVideos: loadNewVideos)
                .tabItem {
                    Image(systemName: "rectangle.stack")
                }
                .tag(Tab.queue)

            InboxView(loadNewVideos: loadNewVideos)
                .tabItem {
                    Image(systemName: inbox.isEmpty ? "tray" : "tray.full")
                }
                .tag(Tab.inbox)

            LibraryView(loadNewVideos: loadNewVideos)
                .tabItem {
                    Image(systemName: "books.vertical")
                }
                .tag(Tab.library)
        }
        .onChange(of: navManager.tab) {
            if navManager.tab == .videoPlayer {
                navManager.tab = navManager.previousTab
                navManager.video = navManager.previousVideo
            }
            navManager.previousTab = navManager.tab
        }
        .sheet(item: $navManager.video) { video in
            ZStack {
                Color.backgroundColor.edgesIgnoringSafeArea(.all)
                VideoPlayer(video: video, markVideoWatched: {
                    markVideoWatched(video: video)
                })
            }
        }
        .environment(navManager)
    }
}

struct ContentView_Previews: PreviewProvider {

    static var previews: some View {
        ContentView()
    }
}
