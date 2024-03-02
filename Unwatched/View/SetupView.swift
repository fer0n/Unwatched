//
//  SetupView.swift
//  Unwatched
//

import SwiftUI

struct SetupView: View {
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.modelContext) var modelContext

    @State var navManager = NavigationManager.load()
    @State var player = PlayerManager()
    @State var refresher = RefreshManager()
    @State var imageCacheManager = ImageCacheManager()

    @Environment(\.horizontalSizeClass) var horizontalSizeClass: UserInterfaceSizeClass?

    var body: some View {
        ContentView()
            .environment(player)
            .environment(navManager)
            .environment(imageCacheManager)
            .environment(refresher)
            .onAppear {
                let container = modelContext.container
                refresher.container = container
                player.container = container
                restoreNowPlayingVideo()
            }
            .task(id: scenePhase) {
                if scenePhase == .active {
                    player.isInBackground = false
                    print("Active")
                    await refresher.refreshOnStartup()
                    refresher.handleAutoBackup(UIDevice.current.name)
                } else if scenePhase == .background {
                    print("background")
                    player.isInBackground = true
                    Task {
                        await saveData()
                    }
                }
            }
    }

    func restoreNowPlayingVideo() {
        print("restoreVideo")
        var video: Video?

        if let data = UserDefaults.standard.data(forKey: Const.nowPlayingVideo),
           let videoId = try? JSONDecoder().decode(Video.ID.self, from: data) {
            if player.video?.persistentModelID == videoId {
                // current video is the one stored, all good
                return
            }
            video = modelContext.model(for: videoId) as? Video
        }

        if let video = video {
            player.setNextVideo(video, .nextUp)
        } else {
            player.loadTopmostVideoFromQueue()
        }
    }

    func saveData() async {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(navManager) {
            UserDefaults.standard.set(encoded, forKey: Const.navigationManager)
        }

        let videoId = player.video?.persistentModelID
        let data = try? JSONEncoder().encode(videoId)
        UserDefaults.standard.setValue(data, forKey: Const.nowPlayingVideo)
        let container = modelContext.container
        await imageCacheManager.persistCache(container)
        print("saved state")
    }
}

#Preview {
    SetupView()
}
