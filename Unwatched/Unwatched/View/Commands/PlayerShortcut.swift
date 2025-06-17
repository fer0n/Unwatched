//
//  PlayerShortcut.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared
import OSLog

enum PlayerShortcut: String, CaseIterable {
    case playPause
    case seekForward
    case seekBackward
    case nextChapter
    case previousChapter
    case hideControls
    case temporarySpeedUp
    case temporarySlowDown
    case markWatched
    case nextVideo
    case speedUp
    case slowDown
    case reloadPlayer
    case refresh
    case toggleFullscreen

    case goToQueue
    case goToInbox
    case goToLibrary
    case goToBrowser

    var title: LocalizedStringKey {
        switch self {
        case .playPause: return "playPause"
        case .seekForward: return "seekForward"
        case .seekBackward: return "seekBackward"
        case .nextChapter: return "nextChapter"
        case .previousChapter: return "previousChapter"
        case .hideControls: return "toggleSidebar"
        case .temporarySpeedUp: return "temporarySpeedUp"
        case .temporarySlowDown: return "temporarySlowDown"
        case .markWatched: return "markWatched"
        case .nextVideo: return "nextVideo"
        case .speedUp: return "speedUp"
        case .slowDown: return "slowDown"
        case .reloadPlayer: return "reloadPlayer"
        case .toggleFullscreen: return "toggleFullscreen"
        case .refresh: return "refresh"
        case .goToQueue: return NavigationTab.queue.stringKey
        case .goToInbox: return NavigationTab.inbox.stringKey
        case .goToLibrary: return NavigationTab.library.stringKey
        case .goToBrowser: return NavigationTab.browser.stringKey
        }
    }

    var keyboardShortcuts: [(key: KeyEquivalent, modifier: EventModifiers)] {
        switch self {
        case .playPause: return [(.space, []), ("k", [])]
        case .seekForward: return [(.rightArrow, []), ("l", [])]
        case .seekBackward: return [(.leftArrow, []), ("j", [])]
        case .nextChapter: return [(.rightArrow, .command), ("l", .command)]
        case .previousChapter: return [(.leftArrow, .command), ("j", .command)]
        case .hideControls: return [("t", [])]
        case .temporarySpeedUp: return [("d", [])]
        case .temporarySlowDown: return [("s", [])]
        case .markWatched: return [("w", .shift)]
        case .nextVideo: return [("n", .shift)]
        case .speedUp: return [(.upArrow, []), (">", [])]
        case .slowDown: return [(.downArrow, []), ("<", [])]
        case .reloadPlayer: return [("r", [.command, .shift])]
        case .toggleFullscreen: return [("f", [])]
        case .refresh: return [("r", [.command])]
        case .goToQueue: return [("1", [.command])]
        case .goToInbox: return [("2", [.command])]
        case .goToLibrary: return [("3", [.command])]
        case .goToBrowser: return [("4", [.command])]
        }
    }

    static var interceptKeysJS: String {
        let allShortcuts = PlayerShortcut.allCases.flatMap { shortcut in
            shortcut.keyboardShortcuts.map { combo in
                let jsKey = combo.key.asJavaScriptKey.lowercased()
                let modifiers = combo.modifier.isEmpty ? "[]" :
                    combo.modifier.contains(.command) ? "['Meta']" :
                    combo.modifier.contains(.shift) ? "['Shift']" :
                    "[]"
                return "{ key: '\(jsKey)', modifiers: \(modifiers) }"
            }
        }
        return "[\(allShortcuts.joined(separator: ","))]"
    }

    static func fromKeyCombo(key: KeyEquivalent, modifiers: EventModifiers) -> PlayerShortcut? {
        for shortcut in PlayerShortcut.allCases where shortcut.keyboardShortcuts.contains(where: {
            $0.0 == key && $0.1 == modifiers
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
        case .seekForward:
            if player.seekForward() {
                OverlayFullscreenVM.shared.show(.seekForward)
            }
        case .seekBackward:
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
            player.tempSpeedChange(faster: true)
        case .temporarySlowDown:
            player.tempSpeedChange()
        case .markWatched:
            markVideoWatched()
            OverlayFullscreenVM.shared.show(.watched)
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
        case .goToBrowser:
            if Const.browserAsTab.bool ?? false {
                NavigationManager.shared.navigateTo(.browser)
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
            VideoService.setVideoWatched(video, modelContext: context)
            player.autoSetNextVideo(playNext ? .userInteraction : .nextUp, context)

            _ = VideoService.setVideoWatchedAsync(video.id)
            try? context.save()
        }
    }

    @ViewBuilder
    func render(isAlt: Bool = false) -> some View {
        if let shortcut = isAlt ? self.keyboardShortcuts.last : self.keyboardShortcuts.first {
            Button(self.title) {
                self.trigger()
            }
            .keyboardShortcut(shortcut.key, modifiers: shortcut.modifier)
        }
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
