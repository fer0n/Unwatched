//
//  DebugView.swift
//  Unwatched
//

import SwiftUI

struct DebugView: View {
    @AppStorage(Const.monitorBackgroundFetches) var monitorBackgroundFetches: Bool = false
    @AppStorage(Const.refreshOnStartup) var refreshOnStartup: Bool = true

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
}
