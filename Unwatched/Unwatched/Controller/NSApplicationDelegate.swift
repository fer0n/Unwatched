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
    weak var mainWindow: NSWindow?

    func applicationWillTerminate(_ notification: Notification) {
        Log.info("applicationWillTerminate start")
        SetupView.handleAppClosed()
        persistWindowFrame()
        Log.info("applicationWillTerminate done")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.info("applicationDidFinishLaunching")
        setupWindowDelegate()

        restoreWindowFrame()
        handleFullscreenOnLaunch()
    }

    @MainActor
    func setupWindowDelegate() {
        if mainWindow == nil {
            mainWindow = NSApp.keyWindow ?? NSApp.windows.first
            mainWindow?.delegate = self
        }
    }

    @MainActor
    func handleAppear() {
        Log.info("handleAppear")
        setupWindowDelegate()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        Log.info("windowShouldClose")
        NSApplication.shared.terminate(self)
        return true
    }

    @MainActor
    func restoreWindowFrame() {
        Log.info("restoreWindowFrame")
        if let frameDescription = UserDefaults.standard.string(forKey: Const.mainWindowFrame) {
            mainWindow?.setFrame(from: frameDescription)
        }
    }

    @MainActor
    func persistWindowFrame() {
        Log.info("persistWindowFrame")
        if let mainWindow {
            UserDefaults.standard.set(mainWindow.frameDescriptor, forKey: Const.mainWindowFrame)
        }
    }

    @MainActor
    func windowWillEnterFullScreen(_ notification: Notification) {
        Log.info("windowWillEnterFullScreen")
        handleEnterFullscreen()
    }

    @MainActor
    func windowWillExitFullScreen(_ notification: Notification) {
        Log.info("windowWillExitFullScreen")
        NavigationManager.shared.toggleSidebar(show: true)
        NavigationManager.shared.isMacosFullscreen = false
    }

    @MainActor
    func handleEnterFullscreen() {
        Log.info("handleEnterFullscreen")
        NavigationManager.shared.toggleSidebar(show: false)
        NavigationManager.shared.isMacosFullscreen = true
    }

    @MainActor
    func handleFullscreenOnLaunch() {
        Log.info("handleFullscreenOnLaunch")
        let isFullscreen = mainWindow?.styleMask.contains(.fullScreen) == true
        if isFullscreen {
            handleEnterFullscreen()
        }
    }
}
#endif
