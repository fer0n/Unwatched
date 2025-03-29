//
//  AppDelegateMac.swift
//  Unwatched
//

#if os(macOS)
import Foundation
import AppKit
import OSLog

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    func applicationWillTerminate(_ notification: Notification) {
        Logger.log.info("applicationWillTerminate")
        SetupView.handleAppClosed()
        Logger.log.info("applicationWillTerminate done")
    }
}
#endif
