//
//  DebugView.swift
//  Unwatched
//

import SwiftUI

struct DebugView: View {
    @Environment(\.modelContext) var modelContext
    @AppStorage(Const.monitorBackgroundFetches) var monitorBackgroundFetches: Bool = false
    @AppStorage(Const.refreshOnStartup) var refreshOnStartup: Bool = true

    @State var cleanupInfo: RemovedDuplicatesInfo?

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
                .foregroundStyle(.teal)

                if let info = cleanupInfo {
                    Text("removedDuplicates \(info.countVideos) \(info.countQueueEntries) \(info.countInboxEntries) \(info.countSubscriptions) \(info.countImages)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint(.teal)
        .onChange(of: monitorBackgroundFetches) {
            if monitorBackgroundFetches {
                NotificationManager.askNotificationPermission()
            }
        }
        .navigationTitle("debug")
        .navigationBarTitleDisplayMode(.inline)
    }

}

#Preview {
    DebugView()
        .modelContainer(DataController.previewContainer)
}
