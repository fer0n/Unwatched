//
//  SetupView.swift
//  Unwatched
//

import SwiftUI
import BackgroundTasks
import OSLog

struct SetupView: View {
    @AppStorage(Const.themeColor) var theme: ThemeColor = .teal

    @Environment(\.scenePhase) var scenePhase
    @Environment(\.modelContext) var modelContext
    @Environment(\.horizontalSizeClass) var horizontalSizeClass: UserInterfaceSizeClass?

    @State var sheetPos = SheetPositionReader.load()
    @State var player = PlayerManager()
    @State var refresher = RefreshManager()
    @State var imageCacheManager = ImageCacheManager()
    @State var alerter: Alerter = Alerter()
    @State var navManager = NavigationManager.load()

    let appDelegate: AppDelegate

    var body: some View {
        ContentView()
            .tint(theme.color)
            .environment(player)
            .environment(imageCacheManager)
            .environment(refresher)
            .environment(sheetPos)
            .environment(alerter)
            .environment(navManager)
            .alert(isPresented: $alerter.isShowingAlert) {
                alerter.alert ?? Alert(title: Text(verbatim: ""))
            }
            .onAppear {
                setUpAppDelegate()

                let container = modelContext.container
                refresher.container = container
                player.container = container
                restoreNowPlayingVideo()
            }
            .task(id: scenePhase) {
                switch scenePhase {
                case .active:
                    player.isInBackground = false
                    NotificationManager.clearNotifications()
                    Logger.log.info("active")
                    await refresher.handleBecameActive()
                    refresher.handleAutoBackup(UIDevice.current.name)
                case .background:
                    Logger.log.info("background")
                    player.isInBackground = true
                    Task {
                        await saveData()
                    }
                    refresher.handleBecameInactive()
                    RefreshManager.scheduleVideoRefresh()
                case .inactive:
                    Logger.log.info("inactive")
                    saveCurrentVideo()
                default:
                    break
                }
            }
    }

    func setUpAppDelegate() {
        appDelegate.navManager = navManager
    }

    func restoreNowPlayingVideo() {
        Logger.log.info("restoreVideo")
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
        let container = modelContext.container
        await imageCacheManager.persistCache(container)
        Logger.log.info("saved state")
    }

    func saveCurrentVideo() {
        let videoId = player.video?.persistentModelID
        let data = try? JSONEncoder().encode(videoId)
        UserDefaults.standard.setValue(data, forKey: Const.nowPlayingVideo)
    }
}

#Preview {
    SetupView(appDelegate: AppDelegate())
}
