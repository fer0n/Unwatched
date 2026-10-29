//
//  PlayerShortcut.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared
import OSLog

enum PlayerShortcut: String, CaseIterable {
    case playPause
    case seekForwardArrow
    case seekBackwardArrow
    case seekForwardCustom
    case seekBackwardCustom
    case nextChapter
    case previousChapter
    case hideControls
    case temporarySpeedUp
    case temporarySlowDown
    case markWatched
    case clearVideo
    case nextVideo
    case speedUp
    case slowDown
    case reloadPlayer
    case refresh
    case toggleFullscreen
    case goToQueue
    case goToInbox
    case goToLibrary
    case goToSearch
    case goToBrowser
    case openInAppBrowser
    case openInExternalBrowser

    var title: LocalizedStringKey {
        switch self {
        case .playPause: return "playPause"
        case .seekForwardArrow: return "seekForward\(Int(PlayerManager.defaultArrowKeySeekSeconds))"
        case .seekBackwardArrow: return "seekBackward\(Int(PlayerManager.defaultArrowKeySeekSeconds))"
        case .seekForwardCustom: return "seekForward\(Int(PlayerManager.defaultSeekSeconds))"
        case .seekBackwardCustom: return "seekBackward\(Int(PlayerManager.defaultSeekSeconds))"
        case .nextChapter: return "nextChapter"
        case .previousChapter: return "previousChapter"
        case .hideControls: return "toggleSidebar"
        case .temporarySpeedUp: return "temporarySpeedUp"
        case .temporarySlowDown: return "temporarySlowDown"
        case .markWatched: return "markWatched"
        case .clearVideo: return "clearVideo"
        case .nextVideo: return "nextVideo"
        case .speedUp: return "speedUp"
        case .slowDown: return "slowDown"
        case .reloadPlayer: return "reloadPlayer"
        case .toggleFullscreen: return "toggleFullscreen"
        case .refresh: return "refresh"
        case .goToQueue: return NavigationTab.queue.stringKey
        case .goToInbox: return NavigationTab.inbox.stringKey
        case .goToLibrary: return NavigationTab.library.stringKey
        case .goToSearch: return NavigationTab.search.stringKey
        case .goToBrowser: return NavigationTab.browser.stringKey
        case .openInAppBrowser: return "openInAppBrowser"
        case .openInExternalBrowser: return "openInExternalBrowser"
        }
    }

    var keyboardShortcuts: [KeyboardShortcut] {
        switch self {
        case .playPause: return [KeyboardShortcut(.space, modifiers: []), KeyboardShortcut("k", modifiers: [])]
        case .seekForwardArrow: return [KeyboardShortcut(.rightArrow, modifiers: [])]
        case .seekBackwardArrow: return [KeyboardShortcut(.leftArrow, modifiers: [])]
        case .seekForwardCustom: return [KeyboardShortcut("l", modifiers: [])]
        case .seekBackwardCustom: return [KeyboardShortcut("j", modifiers: [])]
        case .nextChapter:
            return [KeyboardShortcut(.rightArrow, modifiers: .command), KeyboardShortcut("l", modifiers: .command)]
        case .previousChapter:
            return [KeyboardShortcut(.leftArrow, modifiers: .command), KeyboardShortcut("j", modifiers: .command)]
        case .hideControls: return [KeyboardShortcut("t", modifiers: [])]
        case .temporarySpeedUp: return [KeyboardShortcut("d", modifiers: [])]
        case .temporarySlowDown: return [KeyboardShortcut("s", modifiers: [])]
        case .markWatched: return [KeyboardShortcut("w", modifiers: .shift)]
        case .clearVideo: return [KeyboardShortcut("c", modifiers: .shift)]
        case .nextVideo: return [KeyboardShortcut("n", modifiers: .shift)]
        case .speedUp: return [KeyboardShortcut(.upArrow, modifiers: []), KeyboardShortcut(">", modifiers: [])]
        case .slowDown: return [KeyboardShortcut(.downArrow, modifiers: []), KeyboardShortcut("<", modifiers: [])]
        case .reloadPlayer: return [KeyboardShortcut("r", modifiers: [.command, .shift])]
        case .toggleFullscreen: return [KeyboardShortcut("f", modifiers: [])]
        case .refresh: return [KeyboardShortcut("r", modifiers: [.command])]
        case .goToQueue: return [KeyboardShortcut("1", modifiers: [.command])]
        case .goToInbox: return [KeyboardShortcut("2", modifiers: [.command])]
        case .goToLibrary: return [KeyboardShortcut("3", modifiers: [.command])]
        case .goToSearch: return [KeyboardShortcut("4", modifiers: [.command])]
        case .goToBrowser: return [KeyboardShortcut("5", modifiers: [.command])]
        case .openInAppBrowser: return [KeyboardShortcut("o", modifiers: [])]
        case .openInExternalBrowser: return [KeyboardShortcut("o", modifiers: [.shift])]
        }
    }

    static var interceptKeysJS: String {
        let allShortcuts = PlayerShortcut.allCases.flatMap { shortcut in
            shortcut.keyboardShortcuts.map { combo in
                let jsKey = combo.key.asJavaScriptKey.lowercased()
                let modifiers = combo.modifiers.isEmpty ? "[]" :
                    combo.modifiers.contains(.command) ? "['Meta']" :
                    combo.modifiers.contains(.shift) ? "['Shift']" :
                    "[]"
                return "{ key: '\(jsKey)', modifiers: \(modifiers) }"
            }
        }
        return "[\(allShortcuts.joined(separator: ","))]"
    }

    static func fromKeyCombo(key: KeyEquivalent, modifiers: EventModifiers) -> PlayerShortcut? {
        for shortcut in PlayerShortcut.allCases where shortcut.keyboardShortcuts.contains(where: {
            $0.key == key && $0.modifiers == modifiers
        }) {
            return shortcut
        }
        return nil
    }

    static func parseKey(_ key: String) -> KeyEquivalent? {
        if key.count == 1, let char = key.lowercased().first {
            return KeyEquivalent(char)
        }

        switch key {
        case "ArrowLeft": return .leftArrow
        case "ArrowRight": return .rightArrow
        case "ArrowUp": return .upArrow
        case "ArrowDown": return .downArrow
        default: return nil
        }
    }

    @MainActor
    // swiftlint:disable:next cyclomatic_complexity
    func trigger() {
        let player = PlayerManager.shared
        switch self {
        case .playPause:
            player.handlePlayButton()
        case .seekForwardArrow:
            if player.seekForward(player.arrowKeySeekSeconds) {
                OverlayFullscreenVM.shared.show(.seekForward)
            }
        case .seekBackwardArrow:
            if player.seekBackward(player.arrowKeySeekSeconds) {
                OverlayFullscreenVM.shared.show(.seekBackward)
            }
        case .seekForwardCustom:
            if player.seekForward() {
                OverlayFullscreenVM.shared.show(.seekForward)
            }
        case .seekBackwardCustom:
            if player.seekBackward() {
                OverlayFullscreenVM.shared.show(.seekBackward)
            }
        case .previousChapter:
            if player.goToPreviousChapter() {
                OverlayFullscreenVM.shared.show(.previous)
            }
        case .nextChapter:
            if player.goToNextChapter() {
                OverlayFullscreenVM.shared.show(.next)
            }
        case .hideControls:
            hideControls()
        case .temporarySpeedUp:
            _ = player.tempSpeedChange(faster: true)
        case .temporarySlowDown:
            _ = player.tempSpeedChange()
        case .markWatched:
            markVideoWatched()
            OverlayFullscreenVM.shared.show(.watched)
        case .clearVideo:
            clearVideo()
            OverlayFullscreenVM.shared.show(.cleared)
        case .nextVideo:
            markVideoWatched(playNext: true)
            OverlayFullscreenVM.shared.show(.nextVideo)
        case .speedUp:
            AutoHideVM.shared.setShowControls()
            player.debouncedSpeedUp()
        case .slowDown:
            AutoHideVM.shared.setShowControls()
            player.debouncedSlowDown()
        case .reloadPlayer:
            player.hotReloadPlayer()
        case .toggleFullscreen:
            #if os(macOS)
            if let mainWindow = NSApp.windows.first {
                mainWindow.toggleFullScreen(nil)
                mainWindow.makeKey()
            }
            #else
            hideControls()
            #endif
        case .refresh:
            Task { @MainActor in
                await RefreshManager.shared.refreshAll(hardRefresh: false)
            }
        case .goToQueue:
            NavigationManager.shared.navigateTo(.queue)
        case .goToInbox:
            NavigationManager.shared.navigateTo(.inbox)
        case .goToLibrary:
            NavigationManager.shared.navigateTo(.library)
        case .goToSearch:
            NavigationManager.shared.navigateTo(.search)
        case .goToBrowser:
            NavigationManager.shared.openUrlInApp(nil)
        case .openInAppBrowser:
            if let url = PlayerManager.shared.video?.url?.absoluteString {
                NavigationManager.shared.openUrlInApp(.url(url))
            }
        case .openInExternalBrowser:
            if let video = PlayerManager.shared.video,
               let urlText = UrlService.getShareUrl(video, timestamp: PlayerManager.shared.currentTime),
               let url = URL(string: urlText) {
                UrlService.open(url)
            }
        }
    }

    @MainActor
    func hideControls() {
        #if os(iOS)
        withAnimation {
            let hideControlsFullscreen = UserDefaults.standard.bool(forKey: Const.hideControlsFullscreen)
            UserDefaults.standard.set(!hideControlsFullscreen, forKey: Const.hideControlsFullscreen)
        }
        #else
        NavigationManager.shared.toggleSidebar()
        #endif
    }

    @MainActor
    func markVideoWatched(playNext: Bool = false) {
        let player = PlayerManager.shared

        if let video = player.video {
            let context = DataProvider.newContext()
            withAnimation {
                VideoService.setVideoWatched(video, modelContext: context)
            }
            player.autoSetNextVideo(playNext ? .userInteraction : .nextUp, context)

            _ = VideoService.setVideoWatchedAsync(video.id)
            try? context.save()

            TinyUndoManager.shared.registerAction(.moveToQueue([video.id], position: 0))
        }
    }

    @MainActor
    func clearVideo() {
        let player = PlayerManager.shared

        if let video = player.video {
            let context = DataProvider.newContext()
            player.clearVideo(context)
            try? context.save()

            TinyUndoManager.shared.registerAction(.moveToQueue([video.id], position: 0))
        }
    }

    @ViewBuilder
    func render(isAlt: Bool = false) -> some View {
        if let shortcut = isAlt ? keyboardShortcuts.last : primary {
            Button(title) {
                trigger()
            }
            .keyboardShortcut(shortcut)
        }
    }
}

extension PlayerShortcut {
    var primary: KeyboardShortcut? {
        keyboardShortcuts.first
    }
}

extension View {
    func help(_ title: String, shortcut: PlayerShortcut) -> some View {
        help(title, shortcut: shortcut.primary)
    }
}

private extension KeyEquivalent {
    var asJavaScriptKey: String {
        switch self {
        case .leftArrow: return "ArrowLeft"
        case .rightArrow: return "ArrowRight"
        case .upArrow: return "ArrowUp"
        case .downArrow: return "ArrowDown"
        case .space: return " "
        default: return "\(self.character)"
        }
    }
}
