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
    case temporarySpeed
    case markWatched
    case nextVideo

    var title: LocalizedStringKey {
        switch self {
        case .playPause: return "playPause"
        case .seekForward: return "seekForward"
        case .seekBackward: return "seekBackward"
        case .nextChapter: return "nextChapter"
        case .previousChapter: return "previousChapter"
        case .hideControls: return "toggleSidebar"
        case .temporarySpeed: return "toggleTemporarySpeed"
        case .markWatched: return "markWatched"
        case .nextVideo: return "nextVideo"
        }
    }

    var keyboardShortcuts: [(key: KeyEquivalent, modifier: EventModifiers)] {
        switch self {
        case .playPause: return [(.space, []), ("k", [])]
        case .seekForward: return [(.rightArrow, []), ("l", [])]
        case .seekBackward: return [(.leftArrow, []), ("j", [])]
        case .nextChapter: return [(.rightArrow, .command), ("l", .command)]
        case .previousChapter: return [(.leftArrow, .command), ("j", .command)]
        case .hideControls: return [("f", [])]
        case .temporarySpeed: return [("s", [])]
        case .markWatched: return [("w", .shift)]
        case .nextVideo: return [("n", .shift)]
        }
    }

    static var interceptKeysJS: String {
        let allShortcuts = PlayerShortcut.allCases.flatMap { shortcut in
            shortcut.keyboardShortcuts.map { combo in
                let jsKey = combo.key.asJavaScriptKey
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
            #if os(iOS)
            withAnimation {
                let hideControlsFullscreen = UserDefaults.standard.bool(forKey: Const.hideControlsFullscreen)
                UserDefaults.standard.set(!hideControlsFullscreen, forKey: Const.hideControlsFullscreen)
            }
            #else
            NavigationManager.shared.toggleSidebar()
            #endif
        case .temporarySpeed:
            player.toggleTemporaryPlaybackSpeed()
        case .markWatched:
            markVideoWatched()
            OverlayFullscreenVM.shared.show(.watched)
        case .nextVideo:
            markVideoWatched(playNext: true)
            OverlayFullscreenVM.shared.show(.nextVideo)
        }
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
        case .space: return " "
        default: return "\(self.character)"
        }
    }
}
