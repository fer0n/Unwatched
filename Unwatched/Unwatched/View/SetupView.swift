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
    @State var undoManager = TinyUndoManager()

    var body: some View {
        ContentView()
            .tint(theme.color)
            .environment(sheetPos)
            .environment(alerter)
            .watchNotificationHandler()
            .environment(navManager)
            .environment(\.originalColorScheme, colorScheme)
            .environment(imageCacheManager)
            .environment(undoManager)
            .alert(isPresented: $alerter.isShowingAlert) {
                alerter.alert ?? Alert(title: Text(verbatim: ""))
            }
            #if os(iOS)
            .onChange(of: scenePhase, initial: true) {
                switch scenePhase {
                case .active:
                    NotificationManager.handleNotifications(checkDeferred: true)

                    Log.info("scenePhase: active")
                    Task {
                        refresher.handleAutoBackup()
                        await refresher.handleBecameActive()
                    }
                case .background:
                    Log.info("scenePhase: background")
                    SetupView.handleAppClosed()
                default:
                    break
                }
            }
            #endif
            #if os(macOS)
            .macOSActiveStateChange {
                Log.info("macOSActive: active")
                Task {
                    refresher.handleAutoBackup()
                    await refresher.handleBecameActive()
                }
            } handleResignActive: {
                Log.info("macOSActive: inActive")
                SetupView.handleAppClosed()
            }
            #endif
            .onAppear {
                navManager.openWindow = openWindow
            }
    }

    static func handleAppClosed() {
        Log.info("handleAppClosed")
        #if os(iOS)
        NotificationManager.handleNotifications()
        #endif
        Task {
            await saveData()
        }
        RefreshManager.shared.handleBecameInactive()

        #if os(iOS)
        RefreshManager.shared.scheduleVideoRefresh()
        #endif
    }

    static func saveData() async {
        NavigationManager.shared.save()
        SheetPositionReader.shared.save()
        PlayerManager.shared.save()
        await ImageCacheManager.shared.persistCache()
        Log.info("saved state")
    }

    static func setupVideo() {
        if RefreshManager.shared.consumeTriggerPasteAction() {
            NotificationCenter.default.post(name: .pasteAndWatch, object: nil)
        } else {
            // avoid fetching another video first
            PlayerManager.shared.restoreNowPlayingVideo()
        }
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
