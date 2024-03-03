//
//  SetupView.swift
//  Unwatched
//

import SwiftUI
import OSLog

private let log = Logger(subsystem: Const.bundleId, category: "SetupView")

struct SetupView: View {
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.modelContext) var modelContext

    @State var navManager = NavigationManager.load()
    @State var sheetPos = SheetPositionReader.load()
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
            .environment(sheetPos)
            .onAppear {
                let container = modelContext.container
                refresher.container = container
                player.container = container
                restoreNowPlayingVideo()
            }
            .task(id: scenePhase) {
                if scenePhase == .active {
                    player.isInBackground = false
                    log.info("Active")
                    await refresher.refreshOnStartup()
                    refresher.handleAutoBackup(UIDevice.current.name)
                } else if scenePhase == .background {
                    log.info("background")
                    player.isInBackground = true
                    Task {
                        await saveData()
                    }
                }
            }
    }

    func restoreNowPlayingVideo() {
        log.info("restoreVideo")
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
        navManager.save()
        sheetPos.save()

        let videoId = player.video?.persistentModelID
        let data = try? JSONEncoder().encode(videoId)
        UserDefaults.standard.setValue(data, forKey: Const.nowPlayingVideo)
        let container = modelContext.container
        await imageCacheManager.persistCache(container)
        log.info("saved state")
    }
}

#Preview {
    SetupView()
}
