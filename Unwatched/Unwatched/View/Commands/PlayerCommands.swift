//
//  PlayerCommands.swift
//  Unwatched
//

import UnwatchedShared
import SwiftUI

struct PlayerCommands: Commands {
    var body: some Commands {
        CommandMenu("playback") {
            Section {
                PlayerShortcut.playPause.render()
                PlayerShortcut.playPause.render(isAlt: true)

                #if os(macOS)
                PlayerShortcut.seekBackward5.render()
                PlayerShortcut.seekForward5.render()
                #endif

                PlayerShortcut.seekBackward10.render()
                PlayerShortcut.seekForward10.render()

                PlayerShortcut.previousChapter.render(isAlt: true)
                PlayerShortcut.nextChapter.render(isAlt: true)

                #if os(macOS)
                PlayerShortcut.previousChapter.render()
                PlayerShortcut.nextChapter.render()
                #endif
            }

            Section("playbackSpeed") {
                #if os(macOS)
                PlayerShortcut.speedUp.render()
                PlayerShortcut.slowDown.render()
                #endif

                PlayerShortcut.speedUp.render(isAlt: true)
                PlayerShortcut.slowDown.render(isAlt: true)

                PlayerShortcut.temporarySlowDown.render()
                PlayerShortcut.temporarySpeedUp.render()
            }
        }

        CommandMenu("video") {
            PlayerShortcut.markWatched.render()
            PlayerShortcut.nextVideo.render()
        }
    }
}
