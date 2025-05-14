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
                PlayerShortcut.playPause.render(isAlt: true)
                PlayerShortcut.seekBackward.render(isAlt: true)
                PlayerShortcut.seekForward.render(isAlt: true)
                PlayerShortcut.previousChapter.render(isAlt: true)
                PlayerShortcut.nextChapter.render(isAlt: true)
            }

            Section("alternative") {
                PlayerShortcut.playPause.render()
                #if os(macOS)
                PlayerShortcut.seekBackward.render()
                PlayerShortcut.seekForward.render()
                PlayerShortcut.previousChapter.render()
                PlayerShortcut.nextChapter.render()
                #endif
            }

            Section("playbackSpeed") {
                #if os(macOS)
                PlayerShortcut.speedUp.render()
                #endif
                PlayerShortcut.speedUp.render(isAlt: true)
                #if os(macOS)
                PlayerShortcut.slowDown.render()
                #endif
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
