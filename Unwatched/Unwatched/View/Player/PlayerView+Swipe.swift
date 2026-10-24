//
//  PlayerView+Swipe.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

// live values throughout: callers may hold a stale closure
extension PlayerView {
    func handleSwipe(_ direction: SwipeDirecton) {
        switch direction {
        case .up:
            guard Const.swipeGestureUp.bool ?? true else { return }
            handleSwipeUp()
        case .down:
            guard Const.swipeGestureDown.bool ?? true else { return }
            handleSwipeDown()
        case .left:
            guard Const.swipeGestureLeft.bool ?? true else { return }
            handleChapterSwipe(forward: true)
        case .right:
            guard Const.swipeGestureRight.bool ?? true else { return }
            handleChapterSwipe(forward: false)
        }
    }

    private func handleSwipeUp() {
        #if os(visionOS)
        _ = PlayerManager.shared.tempSpeedChange(faster: true)
        #elseif os(iOS)
        if enableHideControls {
            setHideControlsFullscreen(true)
        } else if SheetPositionReader.shared.landscapeFullscreen || PlayerManager.shared.tallFullscreenActive {
            player.setShowMenu()
        } else if player.video == nil {
            return
        } else if PlayerManager.shared.isTallAspectRatio {
            player.setTallFullscreen(true)
        } else {
            OrientationManager.changeOrientation(to: .landscapeRight)
        }
        #endif
    }

    private func handleSwipeDown() {
        #if os(visionOS)
        _ = PlayerManager.shared.tempSpeedChange()
        #elseif os(iOS)
        if enableHideControls && (Const.hideControlsFullscreen.bool ?? false) {
            setHideControlsFullscreen(false)
        } else if SheetPositionReader.shared.landscapeFullscreen {
            OrientationManager.changeOrientation(to: .portrait)
        } else if PlayerManager.shared.tallFullscreenActive {
            if NavigationManager.shared.showMenu {
                NavigationManager.shared.showMenu = false
            } else {
                player.setTallFullscreen(false)
            }
        } else if player.video != nil {
            player.setPip(true)
        }
        #endif
    }

    private func handleChapterSwipe(forward: Bool) {
        #if os(visionOS)
        let seeked = forward ? PlayerManager.shared.seekForward() : PlayerManager.shared.seekBackward()
        if seeked {
            OverlayFullscreenVM.shared.show(forward ? .seekForward : .seekBackward)
        }
        #else
        guard !player.unstarted else { return }
        let changed = forward ? player.goToNextChapter() : player.goToPreviousChapter()
        if changed {
            overlayVM.show(forward ? .next : .previous)
        }
        #endif
    }

    private func setHideControlsFullscreen(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Const.hideControlsFullscreen)
    }
}
