//
//  AppDelegate.swift
//  Unwatched
//

import Foundation
import WebKit

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var navManager: NavigationManager?
    let notificationCenter = UNUserNotificationCenter.current()

    func woraroundInitialWebViewDelay() {
        let webView = WKWebView()
        webView.loadHTMLString("", baseURL: nil)
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        woraroundInitialWebViewDelay()
        notificationCenter.delegate = self
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("Received in-App notification")
        completionHandler([])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let destination = userInfo[Const.tapDestination] as? NavigationTab.RawValue,
           let tab = NavigationTab(rawValue: destination) {
            Task { @MainActor in
                navManager?.navigateTo(tab)
            }
            print("Notification destination: \(destination))")
        } else {
            print("Tap on notification without destination")
        }
        completionHandler()
    }
}
