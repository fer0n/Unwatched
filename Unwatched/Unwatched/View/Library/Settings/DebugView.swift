//
//  DebugView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct DebugView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player
    @Environment(Alerter.self) var alerter

    @AppStorage(Const.monitorBackgroundFetchesNotification) var monitorBackgroundFetches: Bool = false
    @AppStorage(Const.showVideoListOrder) var showVideoListOrder: Bool = false

    @AppStorage(Const.themeColor) var theme = ThemeColor()
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

                MySection("notifications") {
                    Toggle(isOn: $monitorBackgroundFetches) {
                        Text("monitorBackgroundFetches")
                    }
                }

                MySection("appearance") {
                    Toggle(isOn: $showVideoListOrder) {
                        Text("showVideoListOrder")
                    }
                }

                MySection("userData") {
                    AsyncButton {
                        let container = modelContext.container
                        let task = CleanupService.cleanupDuplicatesAndInboxDate(
                            container,
                            videoOnly: false
                        )
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
                        \(info.countChapters)
                        \(info.countSubscriptions)
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
        .environment(PlayerManager())
}
