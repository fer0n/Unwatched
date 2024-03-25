//
//  DebugView.swift
//  Unwatched
//

import SwiftUI

struct DebugView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(Alerter.self) var alerter

    @AppStorage(Const.monitorBackgroundFetchesNotification) var monitorBackgroundFetches: Bool = false
    @AppStorage(Const.refreshOnStartup) var refreshOnStartup: Bool = true
    @AppStorage(Const.themeColor) var theme: ThemeColor = Color.defaultTheme

    @State var cleanupInfo: RemovedDuplicatesInfo?
    @State var logs = LogManager()
    @State var exportShown = false

    var body: some View {
        List {
            Section("videoSettings") {
                Toggle(isOn: $refreshOnStartup) {
                    Text("refreshOnStartup")
                }
            }

            Section("notifications") {
                Toggle(isOn: $monitorBackgroundFetches) {
                    Text("monitorBackgroundFetches")
                }
            }

            Section("icloudSync") {
                AsyncButton {
                    let container = modelContext.container
                    let task = CleanupService.cleanupDuplicates(container)
                    cleanupInfo = await task.value
                } label: {
                    Text("removeDuplicates")
                }
                .tint(theme.color)

                if let info = cleanupInfo {
                    Text("removedDuplicates \(info.countVideos) \(info.countQueueEntries) \(info.countInboxEntries) \(info.countSubscriptions) \(info.countImages)")
                        .foregroundStyle(.secondary)
                }
            }

            Section("logs") {
                Button {
                    logs.export()
                    exportShown = true
                } label: {
                    Text("exportLogs")
                }
                .sheet(isPresented: $exportShown) {
                    ShareView(items: [logs.entries.joined(separator: "\n")])
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
        .navigationTitle("debug")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    DebugView()
        .modelContainer(DataController.previewContainer)
        .environment(Alerter())
}
