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
    @Query var queue: [QueueEntry]
    @Query(animation: .default) var inbox: [InboxEntry]

    @State var chapterManager = ChapterManager()
    @AppStorage(Const.subscriptionSortOrder) var subscriptionSortOrder: SubscriptionSorting = .recentlyAdded

    @MainActor
    init() {
        UITabBar.appearance().barTintColor = UIColor(Color.backgroundColor)
        UITabBar.appearance().backgroundImage = UIImage()
        UITabBar.appearance().backgroundColor = UIColor(Color.backgroundColor)
    }

    var body: some View {
        @Bindable var navManager = navManager
        TabView(selection: $navManager.tab) {
            VStack {
                Text("VideoPlayer – Should never be visible")
            }
            .tabItem {
                Image(systemName: Const.videoPlayerTabSF)
            }
            .tag(Tab.videoPlayer)

            QueueView(loadNewVideos: loadNewVideos)
                .tabItem {
                    Image(systemName: Const.queueTagSF)
                }
                .tag(Tab.queue)

            InboxView(loadNewVideos: loadNewVideos)
                .tabItem {
                    Image(systemName: inbox.isEmpty ? Const.inboxTabEmptySF : Const.inboxTabFullSF)
                }
                .tag(Tab.inbox)

            LibraryView(loadNewVideos: loadNewVideos, sort: $subscriptionSortOrder)
                .tabItem {
                    Image(systemName: Const.libraryTabSF)
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
                VideoPlayer(video: video,
                            markVideoWatched: {
                                markVideoWatched(video: video)
                            },
                            chapterManager: chapterManager
                )
            }
            .animation(nil, value: UUID())
        }
        .environment(navManager)
        // .onAppear {
        // _ = VideoService.loadNewVideosInBg(modelContext: modelContext)
        // }
    }

    func markVideoWatched(video: Video) {
        VideoService.markVideoWatched(
            video, modelContext: modelContext
        )
    }

    func loadNewVideos() async {
        let task = VideoService.loadNewVideosInBg(modelContext: modelContext)
        try? await task.value
    }
}

struct ContentView_Previews: PreviewProvider {

    static var previews: some View {
        ContentView()
    }
}
