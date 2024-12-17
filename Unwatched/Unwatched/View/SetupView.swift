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
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.horizontalSizeClass) var horizontalSizeClass: UserInterfaceSizeClass?
    @Environment(RefreshManager.self) var refresher
    @Environment(\.colorScheme) var colorScheme
    @Environment(PlayerManager.self) var player

    @State var imageCacheManager = ImageCacheManager()
    @State var sheetPos = SheetPositionReader.shared
    @State var alerter: Alerter = Alerter()
    @State var navManager = NavigationManager.load()

    let appDelegate: AppDelegate

    var body: some View {
        ContentView()
            .tint(theme.color)
            .environment(sheetPos)
            .environment(alerter)
            .watchNotificationHandler()
            .environment(navManager)
            .environment(\.originalColorScheme, colorScheme)
            .environment(imageCacheManager)
            .alert(isPresented: $alerter.isShowingAlert) {
                alerter.alert ?? Alert(title: Text(verbatim: ""))
            }
            .onAppear {
                appDelegate.navManager = navManager
            }
            .onChange(of: scenePhase) {
                switch scenePhase {
                case .active:
                    NotificationManager.clearNotifications()
                    Logger.log.info("active")
                    Task {
                        refresher.handleAutoBackup(UIDevice.current.name)
                        await refresher.handleBecameActive()
                    }
                case .background:
                    Logger.log.info("background")
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
    }

    func saveData() async {
        navManager.save()
        sheetPos.save()
        player.save()
        await imageCacheManager.persistCache()
        Logger.log.info("saved state")
    }
}

#Preview {
    SetupView(appDelegate: AppDelegate())
        .modelContainer(DataProvider.previewContainer)
}
