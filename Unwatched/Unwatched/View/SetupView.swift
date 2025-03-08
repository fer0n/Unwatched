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
    @Environment(\.openWindow) var openWindow

    @State var imageCacheManager = ImageCacheManager.shared
    @State var sheetPos = SheetPositionReader.shared
    @State var alerter: Alerter = Alerter()
    @State var navManager = NavigationManager.shared

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
            .onChange(of: scenePhase, initial: true) {
                switch scenePhase {
                case .active:
                    #if os(iOS)
                    NotificationManager.handleNotifications(checkDeferred: true)
                    #endif
                    Logger.log.info("active")
                    Task {
                        refresher.handleAutoBackup()
                        await refresher.handleBecameActive()
                    }
                case .background:
                    Logger.log.info("background")
                    #if os(iOS)
                    NotificationManager.handleNotifications()
                    #endif
                    Task {
                        await saveData()
                    }
                    refresher.handleBecameInactive()
                    refresher.scheduleVideoRefresh()
                default:
                    break
                }
            }
            .onAppear {
                navManager.openWindow = openWindow
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
    #if os(iOS)
    SetupView()
        .modelContainer(DataProvider.previewContainer)
    #else
    SetupView()
        .modelContainer(DataProvider.previewContainer)
    #endif
}
