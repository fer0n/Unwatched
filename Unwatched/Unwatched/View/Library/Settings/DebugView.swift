//
//  DebugView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct DebugView: View {
    @AppStorage(Const.monitorBackgroundFetchesNotification) var monitorBackgroundFetches: Bool = false
    @AppStorage(Const.backgroundPlayback) var backgroundPlayback: Bool = true
    @Environment(NavigationManager.self) var navManager

    #if os(iOS)
    @Environment(Alerter.self) var alerter
    #endif

    var body: some View {
        ZStack {
            MyBackgroundColor()

            MyForm {
                MySection {
                    Button {
                        navManager.presentSettingsSplash()
                    } label: {
                        Text("showSettingsSplash")
                    }
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

                YoutubeApiKeyView()

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
        .environment(Alerter())
        .environment(NavigationManager())
}
