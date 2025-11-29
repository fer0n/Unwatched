//
//  PlayerGestureOverlay.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PlayerGestureOverlay: ViewModifier {
    @Environment(PlayerManager.self) var player
    @State private var gestureState = GestureTrackingState()

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                .onChanged { value in
                                    gestureState.handleTouchMove(value: value, in: geometry.size)
                                }
                                .onEnded { value in
                                    gestureState.handleTouchEnd(value: value, in: geometry.size) { gesture in
                                        handleGesture(gesture)
                                    }
                                }
                                .onChanged { value in
                                    gestureState.handleTouchStart(value: value, in: geometry.size)
                                }
                        )
                }
            }
    }

    func handleGesture(_ gesture: GestureType) {
        switch gesture {
        case .centerTap:
            let isPlaying = player.isPlaying
            OverlayFullscreenVM.shared.show(isPlaying ? .pause : .play)
            player.handlePlayButton()
        case .tap:
            AutoHideVM.shared.handlePlayerInteraction()
        case .doubleTapLeft:
            seekBackward()
        case .swipeRight:
            guard Const.swipeGestureRight.bool ?? true else {
                return
            }
            if player.goToPreviousChapter() {
                OverlayFullscreenVM.shared.show(.previous)
            }
        case .doubleTapRight:
            seekForward()
        case .swipeLeft:
            guard Const.swipeGestureLeft.bool ?? true else {
                return
            }
            if player.goToNextChapter() {
                OverlayFullscreenVM.shared.show(.next)
            }
        case .swipeUp:
            guard Const.swipeGestureUp.bool ?? true else {
                return
            }
            let appliedSpeed = PlayerManager.shared.tempSpeedChange(faster: true)
            OverlayFullscreenVM.shared.show(appliedSpeed ? .speedUp : .regularSpeed)
        case .swipeDown:
            guard Const.swipeGestureDown.bool ?? true else {
                return
            }
            let appliedSpeed = PlayerManager.shared.tempSpeedChange(faster: false)
            OverlayFullscreenVM.shared.show(appliedSpeed ? .slowDown : .regularSpeed)
        }
    }

    func seekBackward() {
        if player.seekBackward() {
            OverlayFullscreenVM.shared.show(.seekBackward)
            AutoHideVM.shared.reset()
        }
    }

    func seekForward() {
        if player.seekForward() {
            OverlayFullscreenVM.shared.show(.seekForward)
            AutoHideVM.shared.reset()
        }
    }
}

@Observable
class GestureTrackingState {
    @ObservationIgnored private var touchStartTime: Date?
    @ObservationIgnored private var touchStartLocation: CGPoint?
    @ObservationIgnored private var isSwiping = false
    @ObservationIgnored private var longTouchSent = false
    @ObservationIgnored private var centerTouch = false
    @ObservationIgnored private let longPressThreshold: TimeInterval = 0.3
    @ObservationIgnored private let swipeThreshold: CGFloat = 50
    @ObservationIgnored private let doubleTapInterval: TimeInterval = 0.3
    @ObservationIgnored private var lastTapDate: Date?
    @ObservationIgnored private var consecutiveSingleTaps: Int = 0
    @ObservationIgnored private var pendingTapTask: Task<Void, Never>?
    @ObservationIgnored private var pendingTapLocation: CGPoint?

    func handleTouchStart(value: DragGesture.Value, in size: CGSize) {
        if touchStartLocation == nil {
            touchStartTime = Date()
            touchStartLocation = value.startLocation
            isSwiping = false
            longTouchSent = false
            centerTouch = false
            let maxTouchSize = min(100, size.width * 0.15)
            let midX = size.width / 2
            let midY = size.height / 2
            let isHorizontalCenter = abs(value.startLocation.x - midX) < maxTouchSize
            let isVerticalCenter = abs(value.startLocation.y - midY) < maxTouchSize
            if isHorizontalCenter && isVerticalCenter {
                centerTouch = true
            }
        }
    }

    func handleTouchMove(value: DragGesture.Value, in size: CGSize) {
        guard let start = touchStartLocation else { return }
        let deltaX = value.location.x - start.x
        let deltaY = value.location.y - start.y
        if !isSwiping && (abs(deltaX) > 10 || abs(deltaY) > 10) {
            isSwiping = true
        }
    }

    @MainActor
    func handleTouchEnd(
        value: DragGesture.Value,
        in size: CGSize,
        gestureHandler: @escaping (
            PlayerGestureOverlay.GestureType
        ) -> Void
    ) {
        guard let start = touchStartLocation else { return }
        let end = value.location
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let maxTouchSize = min(100, size.width * 0.15)
        let midX = size.width / 2
        let midY = size.height / 2
        let isHorizontalCenter = abs(end.x - midX) < maxTouchSize
        let isVerticalCenter = abs(end.y - midY) < maxTouchSize
        let now = Date()
        if isSwiping {
            if abs(deltaX) > abs(deltaY) {
                if deltaX > swipeThreshold {
                    gestureHandler(.swipeRight)
                } else if deltaX < -swipeThreshold {
                    gestureHandler(.swipeLeft)
                }
            } else {
                if deltaY > swipeThreshold {
                    gestureHandler(.swipeDown)
                } else if deltaY < -swipeThreshold {
                    gestureHandler(.swipeUp)
                }
            }
            resetTouch()
            return
        }
        if centerTouch && isHorizontalCenter && isVerticalCenter {
            gestureHandler(.centerTap)
            resetTouch()
            return
        }
        // Double tap detection: trigger tap and double tap immediately, no delay
        if let lastTap = lastTapDate, now.timeIntervalSince(lastTap) < doubleTapInterval {
            consecutiveSingleTaps += 1
            pendingTapTask?.cancel() // Cancel pending tap
            gestureHandler(.tap)
            let side: PlayerGestureOverlay.GestureType = (end.x < midX) ? .doubleTapLeft : .doubleTapRight
            gestureHandler(side)
        } else {
            consecutiveSingleTaps = 0
            // Schedule tap after doubleTapInterval using Task
            pendingTapLocation = end
            pendingTapTask?.cancel()
            pendingTapTask = Task {
                do {
                    try await Task.sleep(for: .seconds(doubleTapInterval))
                    gestureHandler(.tap)
                    pendingTapLocation = nil
                } catch {}
            }
        }
        lastTapDate = now
        resetTouch()
    }

    private func resetTouch() {
        touchStartLocation = nil
        touchStartTime = nil
        isSwiping = false
        longTouchSent = false
        centerTouch = false
    }
}

extension PlayerGestureOverlay {
    enum GestureType {
        case tap,
             doubleTapLeft,
             doubleTapRight,
             swipeLeft,
             swipeRight,
             swipeUp,
             swipeDown,
             centerTap
    }
}

#Preview {
    Color.blue
        .frame(width: 600, height: 500)
        .modifier(PlayerGestureOverlay())
}
