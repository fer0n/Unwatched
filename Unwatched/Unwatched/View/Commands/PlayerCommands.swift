//
//  PlayerCommands.swift
//  Unwatched
//

import UnwatchedShared
import SwiftUI

struct PlayerCommands: Commands {
    var body: some Commands {
        CommandMenu("playerMenu") {
            PlayerShortcut.playPause.render()

            #if os(macOS)
            PlayerShortcut.seekBackward.render()
            PlayerShortcut.seekForward.render()
            PlayerShortcut.previousChapter.render()
            PlayerShortcut.nextChapter.render()
            Divider()
            #endif

            PlayerShortcut.playPause.render(isAlt: true)
            PlayerShortcut.seekBackward.render(isAlt: true)
            PlayerShortcut.seekForward.render(isAlt: true)
            PlayerShortcut.previousChapter.render(isAlt: true)
            PlayerShortcut.nextChapter.render(isAlt: true)

            Divider()

            PlayerShortcut.hideControls.render()
            PlayerShortcut.temporarySpeed.render()

            Divider()

            PlayerShortcut.markWatched.render()
            PlayerShortcut.nextVideo.render()
        }
    }
}
