//
//  NotificationSettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct NotificationSettingsView: View {
    #if os(iOS)
    @Environment(Alerter.self) var alerter
    #endif

    @AppStorage(Const.videoAddedToInboxNotification) var videoAddedToInbox: Bool = false
    @AppStorage(Const.videoAddedToQueueNotification) var videoAddedToQueue: Bool = false
    @AppStorage(Const.showNotificationBadge) var showNotificationBadge: Bool = false
    @AppStorage(Const.showTabBarBadge) var showTabBarBadge: Bool = true

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
                    Toggle(isOn: $showTabBarBadge) {
                        Text("showTabBarBadge")
                    }
                }
            }
            .disabled(notificationsDisabled)
        }
        #if os(iOS)
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
        #endif
        .myNavigationTitle("notifications")
    }

    func handleNotificationPermission() {
        #if os(iOS)
        Task {
            do {
                try await NotificationManager.askNotificationPermission()
            } catch {
                alerter.showError(error)
            }
        }
        #endif
    }
}

#Preview {
    NotificationSettingsView()
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager())
        .environment(Alerter())
}
