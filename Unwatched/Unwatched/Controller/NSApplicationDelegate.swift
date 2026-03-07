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
        let isFakePip = UserDefaults.standard.bool(forKey: Const.isFakePip)
        if isFakePip, let window = mainWindow {
            // Save pip position for next pip session, but don't overwrite the regular window frame
            UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: Const.fakePipWindowFrame)
        } else {
            persistWindowFrame()
        }
        SetupView.handleAppClosed()
        Log.info("applicationWillTerminate done")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.info("applicationDidFinishLaunching")
        Signal.setup()
        setupWindowDelegate()

        restoreWindowFrame()
        handleFullscreenOnLaunch()

        SetupView.onLaunch()
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
        let isFakePip = UserDefaults.standard.bool(forKey: Const.isFakePip)
        if isFakePip,
           let frameString = UserDefaults.standard.string(forKey: Const.fakePipWindowFrame) {
            let frame = NSRectFromString(frameString)
            if frame.size != .zero {
                mainWindow?.setFrame(frame, display: true)
            }
            mainWindow?.level = .floating
            mainWindow?.contentMinSize = NSSize(width: 200, height: 112)
        } else if let frameDescription = UserDefaults.standard.string(forKey: Const.mainWindowFrame) {
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
