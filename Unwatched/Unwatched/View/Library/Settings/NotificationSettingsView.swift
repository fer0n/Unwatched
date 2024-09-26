//
//  NotificationSettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct NotificationSettingsView: View {
    @Environment(Alerter.self) var alerter

    @AppStorage(Const.videoAddedToInboxNotification) var videoAddedToInbox: Bool = false
    @AppStorage(Const.videoAddedToQueueNotification) var videoAddedToQueue: Bool = false
    @AppStorage(Const.showNotificationBadge) var showNotificationBadge: Bool = false

    @State var notificationsDisabled = false

    var body: some View {

        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

            MyForm {
                MySection(footer: notificationsDisabled
                            ? "notificationsDisabledHelper"
                            : "notificationsHelper") {
                    Toggle(isOn: $videoAddedToInbox) {
                        Text("videoAddedToInbox")
                    }

                    Toggle(isOn: $videoAddedToQueue) {
                        Text("videoAddedToQueue")
                    }
                }

                MySection {
                    Toggle(isOn: $showNotificationBadge) {
                        Text("showNotificationBadge")
                    }
                }
            }
            .disabled(notificationsDisabled)
        }
        .onAppear {
            Task {
                notificationsDisabled = await NotificationManager.areNotificationsDisabled()
            }
        }
        .onChange(of: videoAddedToQueue) {
            if videoAddedToQueue {
                handleNotificationPermission()
            }
        }
        .onChange(of: videoAddedToInbox) {
            if videoAddedToInbox {
                handleNotificationPermission()
            }
        }
        .onChange(of: showNotificationBadge) {
            if showNotificationBadge {
                handleNotificationPermission()
            }
        }
        .myNavigationTitle("notifications")
    }

    func handleNotificationPermission() {
        Task {
            do {
                try await NotificationManager.askNotificationPermission()
            } catch {
                alerter.showError(error)
            }
        }
    }
}

#Preview {
    NotificationSettingsView()
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
        .environment(Alerter())
}
