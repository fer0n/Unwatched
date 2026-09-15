//
//  GestureTrackingState.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

enum SwipeAxis { case horizontal, vertical }

@Observable
class GestureTrackingState {
    @ObservationIgnored private var touchStartTime: Date?
    @ObservationIgnored private var touchStartLocation: CGPoint?
    @ObservationIgnored private var isSwiping = false
    @ObservationIgnored var longTouchSent = false
    @ObservationIgnored private var centerTouch = false
    /// Matches `PlayerBackgroundGestureRecognizer.minDuration`; a swipe cancels on movement anyway.
    @ObservationIgnored private let longPressThreshold: TimeInterval = 0.2
    @ObservationIgnored private let swipeThreshold: CGFloat = 50
    @ObservationIgnored private let doubleTapInterval: TimeInterval = 0.3
    @ObservationIgnored private var lastTapDate: Date?
    @ObservationIgnored private var longPressTask: Task<Void, Never>?
    @ObservationIgnored var isPinching = false
    @ObservationIgnored var lockedSwipeAxis: SwipeAxis?
    @ObservationIgnored private var edgeZoneSide: PlayerEdgeSwipe.Side?

    @MainActor
    func handleTouchStart(
        startLocation: CGPoint,
        in size: CGSize,
        gestureHandler: @escaping @MainActor (PlayerGestureOverlay.GestureType) -> Void
    ) {
        if touchStartLocation == nil {
            touchStartTime = Date()
            touchStartLocation = startLocation
            isSwiping = false
            longTouchSent = false
            centerTouch = false
            let maxTouchSize = min(100, size.width * 0.15)
            let midX = size.width / 2
            let midY = size.height / 2
            let isHorizontalCenter = abs(startLocation.x - midX) < maxTouchSize
            let isVerticalCenter = abs(startLocation.y - midY) < maxTouchSize
            if isHorizontalCenter && isVerticalCenter {
                centerTouch = true
            }
            let isLeft = startLocation.x < midX
            edgeZoneSide = PlayerEdgeSwipe.edgeZoneSide(
                startX: startLocation.x,
                width: size.width
            )
            longPressTask?.cancel()
            longPressTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(longPressThreshold))
                guard !Task.isCancelled, !isSwiping, !centerTouch, !isPinching else { return }
                longTouchSent = true
                gestureHandler(isLeft ? .longPressLeft : .longPressRight)
            }
        }
    }

    func handleTouchMove(location: CGPoint, in size: CGSize) {
        guard let start = touchStartLocation else { return }
        let deltaX = location.x - start.x
        let deltaY = location.y - start.y
        if !isSwiping && (abs(deltaX) > 10 || abs(deltaY) > 10) {
            isSwiping = true
            longPressTask?.cancel()
            longPressTask = nil
        }
    }

    @MainActor
    func handleTouchEnd(
        value: DragGesture.Value,
        in size: CGSize,
        lockedAxis: SwipeAxis? = nil,
        gestureHandler: @escaping (
            PlayerGestureOverlay.GestureType
        ) -> Void
    ) {
        guard let start = touchStartLocation else { return }
        let end = value.location
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        if longTouchSent {
            gestureHandler(.longPressEnd)
            resetTouch()
            return
        }
        guard !isPinching else {
            resetTouch()
            return
        }
        // no distance threshold here, unlike the chapter swipes
        if isSwiping, lockedAxis != .vertical, let side = edgeZoneSide,
           side.isInward(value.translation) {
            gestureHandler(.swipeControlsEdge)
            resetTouch()
            return
        }
        if isSwiping {
            switch lockedAxis {
            case .horizontal:
                handleHorizontalSwipe(deltaX: deltaX, gestureHandler: gestureHandler)
            case .vertical:
                handleVerticalSwipe(deltaY: deltaY, gestureHandler: gestureHandler)
            case nil:
                if abs(deltaX) > abs(deltaY) {
                    handleHorizontalSwipe(deltaX: deltaX, gestureHandler: gestureHandler)
                } else {
                    handleVerticalSwipe(deltaY: deltaY, gestureHandler: gestureHandler)
                }
            }
            resetTouch()
            return
        }
        handleTapEnd(end: end, in: size, gestureHandler: gestureHandler)
    }

    @MainActor
    private func handleTapEnd(
        end: CGPoint,
        in size: CGSize,
        gestureHandler: @escaping (PlayerGestureOverlay.GestureType) -> Void
    ) {
        let maxTouchSize = min(100, size.width * 0.15)
        let midX = size.width / 2
        let isCenter = abs(end.x - midX) < maxTouchSize
            && abs(end.y - size.height / 2) < maxTouchSize
        if centerTouch && isCenter {
            gestureHandler(.centerTap)
            resetTouch()
            return
        }

        let now = Date()
        if let lastTap = lastTapDate, now.timeIntervalSince(lastTap) < doubleTapInterval {
            // Second tap within interval: fire seek gesture only (.tap already fired on first tap)
            gestureHandler(end.x < midX ? .doubleTapLeft : .doubleTapRight)
        } else {
            // First tap: fire immediately with no delay
            gestureHandler(.tap)
        }
        lastTapDate = now
        resetTouch()
    }

    private func handleHorizontalSwipe(
        deltaX: CGFloat,
        gestureHandler: @escaping (PlayerGestureOverlay.GestureType) -> Void
    ) {
        if deltaX > swipeThreshold {
            gestureHandler(.swipeRight)
        } else if deltaX < -swipeThreshold {
            gestureHandler(.swipeLeft)
        }
    }

    private func handleVerticalSwipe(
        deltaY: CGFloat,
        gestureHandler: @escaping (PlayerGestureOverlay.GestureType) -> Void
    ) {
        if deltaY > swipeThreshold {
            gestureHandler(.swipeDown)
        } else if deltaY < -swipeThreshold {
            gestureHandler(.swipeUp)
        }
    }

    /// A press that already fired still owes its `.longPressEnd`, or the temporary speed stays on.
    @MainActor
    func cancelTouch(gestureHandler: @MainActor (PlayerGestureOverlay.GestureType) -> Void) {
        guard touchStartLocation != nil else { return }
        if longTouchSent {
            gestureHandler(.longPressEnd)
        }
        resetTouch()
    }

    func resetTouch() {
        longPressTask?.cancel()
        longPressTask = nil
        touchStartLocation = nil
        touchStartTime = nil
        isSwiping = false
        longTouchSent = false
        centerTouch = false
        lockedSwipeAxis = nil
        edgeZoneSide = nil
    }
}
