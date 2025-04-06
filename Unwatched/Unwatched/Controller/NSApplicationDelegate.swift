//
//  AppDelegateMac.swift
//  Unwatched
//

#if os(macOS)
import Foundation
import AppKit
import OSLog
import UnwatchedShared

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, NSWindowDelegate {
    let mainWindow: NSWindow?

    override init() {
        mainWindow = nil
        super.init()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Logger.log.info("applicationWillTerminate")
        SetupView.handleAppClosed()
        persistWindowFrame()
        Logger.log.info("applicationWillTerminate done")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set window delegate to receive close notifications
        NSApp.windows.first?.delegate = self

        restoreWindowFrame()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        persistWindowFrame()
        return true
    }

    @MainActor
    func restoreWindowFrame() {
        if let frameDescription = UserDefaults.standard.string(forKey: Const.mainWindowFrame) {
            mainWindow?.setFrame(from: frameDescription)
        }
    }

    @MainActor
    func persistWindowFrame() {
        if let mainWindow = NSApp.windows.first {
            UserDefaults.standard.set(mainWindow.frameDescriptor, forKey: Const.mainWindowFrame)
        }
    }
}
#endif
