//
//  SetupView.swift
//  Unwatched
//

import SwiftUI

struct SetupView: View {
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.modelContext) var modelContext

    @State var navManager: NavigationManager = {
        return loadNavigationManager()
    }()
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
                refresher.handleAutoBackup()
            }
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    print("Active")
                    refresher.refreshOnStartup()
                } else if scenePhase == .background {
                    print("background")
                    saveData()
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

    static func loadNavigationManager() -> NavigationManager {
        print("loadNavigationManager")
        if let savedNavManager = UserDefaults.standard.data(forKey: Const.navigationManager) {
            if let loadedNavManager = try? JSONDecoder().decode(
                NavigationManager.self,
                from: savedNavManager
            ) {
                return loadedNavManager
            } else {
                print("navmanager not found")
            }
        }
        return NavigationManager()
    }

    func saveData() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(navManager) {
            UserDefaults.standard.set(encoded, forKey: Const.navigationManager)
        }

        let videoId = player.video?.persistentModelID
        let data = try? JSONEncoder().encode(videoId)
        UserDefaults.standard.setValue(data, forKey: Const.nowPlayingVideo)
        let container = modelContext.container
        imageCacheManager.persistCache(container)
        print("saved state")
    }
}

#Preview {
    SetupView()
}
