//
//  SetupView.swift
//  Unwatched
//

import SwiftUI
import BackgroundTasks
import SwiftData
import OSLog
import UnwatchedShared

struct SetupView: View {
    @AppStorage(Const.themeColor) var theme: ThemeColor = .teal
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.horizontalSizeClass) var horizontalSizeClass: UserInterfaceSizeClass?
    @Environment(PlayerManager.self) var player
    @Environment(RefreshManager.self) var refresher
    @Environment(ImageCacheManager.self) var imageCacheManager
    @Environment(\.colorScheme) var colorScheme

    @State var sheetPos = SheetPositionReader.load()
    @State var alerter: Alerter = Alerter()
    @State var navManager = NavigationManager.load()

    let appDelegate: AppDelegate

    var body: some View {
        ContentView()
            .tint(theme.color)
            .environment(sheetPos)
            .environment(alerter)
            .environment(navManager)
            .environment(\.originalColorScheme, colorScheme)
            .alert(isPresented: $alerter.isShowingAlert) {
                alerter.alert ?? Alert(title: Text(verbatim: ""))
            }
            .onAppear {
                let container = modelContext.container
                appDelegate.navManager = navManager
                appDelegate.container = container
                refresher.container = container
            }
            .onChange(of: scenePhase) {
                switch scenePhase {
                case .active:
                    player.isInBackground = false
                    NotificationManager.clearNotifications()
                    Logger.log.info("active")
                    Task {
                        refresher.handleAutoBackup(UIDevice.current.name)
                        await refresher.handleBecameActive()
                    }
                case .background:
                    Logger.log.info("background")
                    player.isInBackground = true
                    NotificationManager.clearNotifications()
                    Task {
                        await saveData()
                    }
                    refresher.handleBecameInactive()
                    refresher.scheduleVideoRefresh()
                default:
                    break
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .watchInUnwatched)) {
                handleWatchInUnwatched($0)
            }
    }

    func saveData() async {
        navManager.save()
        sheetPos.save()
        await imageCacheManager.persistCache()
        Logger.log.info("saved state")
    }

    func handleWatchInUnwatched(_ notification: NotificationCenter.Publisher.Output) {
        if let userInfo = notification.userInfo, let youtubeUrl = userInfo["youtubeUrl"] as? URL {
            let container = modelContext.container
            let task = VideoService.addForeignUrls(
                [youtubeUrl],
                in: .queue,
                at: 0,
                container: container
            )
            player.loadTopmostVideoFromQueue(after: task, modelContext: modelContext, source: .userInteraction)
            navManager.handlePlay()
        }
    }
}

#Preview {
    SetupView(appDelegate: AppDelegate())
        .modelContainer(DataController.previewContainer)
}
