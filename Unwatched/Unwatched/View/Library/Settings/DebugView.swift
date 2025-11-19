//
//  DebugView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct DebugView: View {
    @AppStorage(Const.monitorBackgroundFetchesNotification) var monitorBackgroundFetches: Bool = false
    @AppStorage(Const.showTutorial) var showTutorial: Bool = true
    @AppStorage(Const.backgroundPlayback) var backgroundPlayback: Bool = true

    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player

    #if os(iOS)
    @Environment(Alerter.self) var alerter
    #endif

    var body: some View {
        ZStack {
            MyBackgroundColor(macOS: false)

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

                #if os(iOS)
                MySection("playback") {
                    Toggle(isOn: $backgroundPlayback) {
                        Text("backgroundPlayback")
                    }
                }
                #endif

                DebugLoggerView()
            }
        }
        #if os(iOS)
        .task(id: monitorBackgroundFetches) {
            if monitorBackgroundFetches {
                do {
                    try await NotificationManager.askNotificationPermission()
                } catch {
                    alerter.showError(error)
                }
            }
        }
        #endif
        .myNavigationTitle("debug")
    }
}

#Preview {
    DebugView()
        .modelContainer(DataProvider.previewContainer)
        .environment(Alerter())
        .environment(PlayerManager())
}
