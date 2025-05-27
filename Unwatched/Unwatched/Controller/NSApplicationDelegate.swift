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
    var mainWindow: NSWindow?

    override init() {
        mainWindow = nil
        super.init()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Log.info("applicationWillTerminate")
        SetupView.handleAppClosed()
        persistWindowFrame()
        Log.info("applicationWillTerminate done")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        mainWindow = NSApp.windows.first
        mainWindow?.delegate = self

        handleFullscreenOnLaunch()
        restoreWindowFrame()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        persistWindowFrame()
        return true
    }

    @MainActor
    func restoreWindowFrame() {
        if let mainWindow, let frameDescription = UserDefaults.standard.string(forKey: Const.mainWindowFrame) {
            mainWindow.setFrame(from: frameDescription)
        }
    }

    @MainActor
    func persistWindowFrame() {
        if let mainWindow {
            UserDefaults.standard.set(mainWindow.frameDescriptor, forKey: Const.mainWindowFrame)
        }
    }

    @MainActor
    func windowWillEnterFullScreen(_ notification: Notification) {
        handleEnterFullscreen()
    }

    @MainActor
    func windowWillExitFullScreen(_ notification: Notification) {
        NavigationManager.shared.toggleSidebar(show: true)
        NavigationManager.shared.isMacosFullscreen = false
    }

    @MainActor
    func handleEnterFullscreen() {
        NavigationManager.shared.toggleSidebar(show: false)
        NavigationManager.shared.isMacosFullscreen = true
    }

    @MainActor
    func handleFullscreenOnLaunch() {
        let isFullscreen = mainWindow?.styleMask.contains(.fullScreen) == true
        if isFullscreen {
            handleEnterFullscreen()
        }
    }
}
#endif
