//
//  BackgroundSeekRecognizer.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PlayerBackgroundGestureRecognizer: View {
    @Environment(PlayerManager.self) var player

    @State var hapticToggle: Bool = false

    // tap
    @State private var tapCount = 0
    @State private var lastTapTime = Date()

    // long press
    @State var longPressed: Bool = false
    let minDuration: Double = 0.2
    let maxDistance: Double = 3

    var body: some View {
        HStack(spacing: 0) {
            Color.playerBackground
                .onTapGesture {
                    handleTap(isLeftSide: true)
                }
                .onLongPressGesture(minimumDuration: minDuration, maximumDistance: maxDistance) {
                    handleLongPressEnded(slowDown: true)
                } onPressingChanged: { value in
                    handleLongPressChanged(value)
                }

            Color.playerBackground
                .onTapGesture {
                    handleTap(isLeftSide: false)
                }
                .onLongPressGesture(minimumDuration: minDuration, maximumDistance: maxDistance) {
                    handleLongPressEnded(slowDown: false)
                } onPressingChanged: { value in
                    handleLongPressChanged(value)
                }
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
    }

    private func handleTap(isLeftSide: Bool) {
        let now = Date()
        if now.timeIntervalSince(lastTapTime) < 0.3 {
            // Increment skip time on rapid taps
            tapCount += 1
        } else {
            // Reset on slower taps
            tapCount = 1

        }
        lastTapTime = now

        if tapCount <= 1 {
            return
        }

        if isLeftSide {
            if player.seekBackward() {
                hapticToggle.toggle()
                OverlayFullscreenVM.shared.show(.seekBackward)
            }
        } else {
            if player.seekForward() {
                hapticToggle.toggle()
                OverlayFullscreenVM.shared.show(.seekForward)
            }
        }
    }

    func handleLongPressEnded(slowDown: Bool) {
        longPressed = true
        if slowDown {
            player.temporarySlowDown()
        } else {
            player.temporarySpeedUp()
        }
    }

    func handleLongPressChanged(_ value: Bool) {
        if !value && longPressed {
            longPressed = false
            player.resetTemporaryPlaybackSpeed()
        }
    }
}
