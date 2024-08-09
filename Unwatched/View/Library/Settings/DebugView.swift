//
//  DebugView.swift
//  Unwatched
//

import SwiftUI

struct DebugView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player
    @Environment(Alerter.self) var alerter

    @AppStorage(Const.monitorBackgroundFetchesNotification) var monitorBackgroundFetches: Bool = false
    @AppStorage(Const.refreshOnClose) var refreshOnClose: Bool = false

    @AppStorage(Const.refreshOnStartup) var refreshOnStartup: Bool = true
    @AppStorage(Const.themeColor) var theme: ThemeColor = Color.defaultTheme
    @AppStorage(Const.showTutorial) var showTutorial: Bool = true

    @State var cleanupInfo: RemovedDuplicatesInfo?

    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

            MyForm {
                MySection {
                    Button {
                        showTutorial = true
                        player.video = nil
                    } label: {
                        Text("showTutorial")
                    }
                    .disabled(showTutorial == true && player.video == nil)
                }

                MySection("videoSettings") {
                    Toggle(isOn: $refreshOnStartup) {
                        Text("refreshOnStartup")
                    }
                }

                MySection("notifications") {
                    Toggle(isOn: $monitorBackgroundFetches) {
                        Text("monitorBackgroundFetches")
                    }
                    Toggle(isOn: $refreshOnClose) {
                        Text("refreshOnClose")
                    }
                }

                MySection("icloudSync") {
                    AsyncButton {
                        let container = modelContext.container
                        let task = CleanupService.cleanupDuplicates(container)
                        cleanupInfo = await task.value
                    } label: {
                        Text("removeDuplicates")
                    }
                    .tint(theme.color)

                    if let info = cleanupInfo {
                        Text("""
                        removedDuplicates
                        \(info.countVideos)
                        \(info.countQueueEntries)
                        \(info.countInboxEntries)
                        \(info.countSubscriptions)
                        \(info.countImages)
                        """)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task(id: monitorBackgroundFetches) {
            if monitorBackgroundFetches {
                do {
                    try await NotificationManager.askNotificationPermission()
                } catch {
                    alerter.showError(error)
                }
            }
        }
        .myNavigationTitle("debug")
    }
}

#Preview {
    DebugView()
        .modelContainer(DataController.previewContainer)
        .environment(Alerter())
}
