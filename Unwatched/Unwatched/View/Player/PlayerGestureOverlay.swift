//
//  PlayerGestureOverlay.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

private enum SwipeAxis { case horizontal, vertical }

private struct SwipeTransform {
    var scale: CGFloat = 1.0
    var anchor: UnitPoint = .center
    var offset: CGSize = .zero
}

struct PlayerGestureOverlay: ViewModifier {
    @Environment(PlayerManager.self) var player

    var handleSwipe: ((SwipeDirecton) -> Void)?
    var onTap: (() -> Void)?
    var onDoubleTap: (() -> Void)?
    var onChapterSwipe: (() -> Void)?
    /// Set to true by external gesture systems (e.g. two-finger zoom/pan) to suppress
    /// swipe and tap recognition while multi-touch is active.
    var isExternallyPinching: Bool = false
    var enabled: Bool = true

    @State private var gestureState = GestureTrackingState()
    @State private var swipeTransform = SwipeTransform()
    @State private var hapticTrigger = false

    // Must match GestureTrackingState.swipeThreshold so the visual wall aligns with action trigger
    private let swipeThreshold: CGFloat = 50

    func body(content: Content) -> some View {
        content
            .scaleEffect(enabled ? swipeTransform.scale : 1, anchor: swipeTransform.anchor)
            .offset(enabled ? swipeTransform.offset : .zero)
            .sensoryFeedback(Const.sensoryFeedback, trigger: hapticTrigger)
            .overlay {
                if enabled {
                    GeometryReader { geometry in
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                    .onChanged { value in
                                        guard !gestureState.isPinching && !isExternallyPinching else { return }
                                        gestureState.handleTouchStart(value: value, in: geometry.size) { gesture in
                                            handleGesture(gesture)
                                        }
                                        gestureState.handleTouchMove(value: value, in: geometry.size)
                                        applySwipeAnimation(translation: value.translation)
                                    }
                                    .onEnded { value in
                                        let axis = gestureState.lockedSwipeAxis
                                        resetSwipeAnimation()
                                        guard !isExternallyPinching else {
                                            gestureState.resetTouch()
                                            return
                                        }
                                        gestureState.handleTouchEnd(value: value, in: geometry.size, lockedAxis: axis) { gesture in
                                            handleGesture(gesture, lockedAxis: axis)
                                        }
                                    }
                            )
                            .simultaneousGesture(
                                MagnifyGesture()
                                    .onChanged { _ in
                                        gestureState.isPinching = true
                                        gestureState.resetTouch()
                                        resetSwipeAnimation()
                                    }
                                    .onEnded { _ in
                                        Task { @MainActor in
                                            try? await Task.sleep(for: .milliseconds(100))
                                            gestureState.isPinching = false
                                        }
                                    }
                            )
                    }
                }
            }
            // The actual zoom is driven by the UIKit ZoomPanModifier, which flips
            // `isExternallyPinching` the instant a second finger lands — well before the
            // SwiftUI MagnifyGesture recognizes. Mirror it into `isPinching` and cancel any
            // pending touch so a two-finger start can't fire the long-press (temporary speed).
            .onChange(of: isExternallyPinching) { _, pinching in
                if pinching {
                    gestureState.isPinching = true
                    gestureState.resetTouch()
                    resetSwipeAnimation()
                } else {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
                        gestureState.isPinching = false
                    }
                }
            }
    }

    private func applySwipeAnimation(translation: CGSize) {
        guard !gestureState.longTouchSent else { return }
        let dx = translation.width
        let dy = translation.height
        guard abs(dx) > 10 || abs(dy) > 10 else { return }

        if gestureState.lockedSwipeAxis == nil {
            gestureState.lockedSwipeAxis = abs(dx) >= abs(dy) ? .horizontal : .vertical
        }

        // Strip the axis-detection deadzone symmetrically so the animation starts
        // at zero and reverses cleanly through the gesture origin without a jump.
        let deadzone: CGFloat = 10
        let animDy = dy < 0 ? min(0, dy + deadzone) : max(0, dy - deadzone)

        var transform = SwipeTransform()
        if gestureState.lockedSwipeAxis == .vertical {
            if animDy < 0, handleSwipe == nil || !SheetPositionReader.shared.landscapeFullscreen {
                // swipe up → zoom in anchored at bottom (speed change, or portrait→landscape rotation)
                let progress = easeOutProgress(abs(animDy))
                transform.scale = 1.0 + progress * 0.12
                transform.anchor = .bottom
            } else if animDy > 0 {
                // swipe down → shrink + slide down
                let progress = easeOutProgress(animDy)
                transform.scale = 1.0 - progress * 0.06
                transform.anchor = .top
                transform.offset = CGSize(width: 0, height: progress * 20)
            }
        }
        swipeTransform = transform
    }

    private func resetSwipeAnimation() {
        gestureState.lockedSwipeAxis = nil
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            swipeTransform = SwipeTransform()
        }
    }

    private func easeOutProgress(_ distance: CGFloat) -> CGFloat {
        let ratio = min(distance / swipeThreshold, 1)
        return sin(ratio * .pi / 2)
    }

    private func handleGesture(
        _ gesture: GestureType,
        lockedAxis: SwipeAxis? = nil
    ) {
        if lockedAxis == .vertical && (gesture == .swipeLeft || gesture == .swipeRight) { return }
        if lockedAxis == .horizontal && (gesture == .swipeUp || gesture == .swipeDown) { return }

        switch gesture {
        case .centerTap:
            let isPlaying = player.isPlaying
            OverlayFullscreenVM.shared.show(isPlaying ? .pause : .play)
            player.handlePlayButton()
        case .tap:
            if let onTap { onTap() } else { AutoHideVM.shared.handlePlayerInteraction() }
        case .doubleTapLeft:  seekBackward()
        case .doubleTapRight: seekForward()
        case .swipeRight:     handleSwipeRight()
        case .swipeLeft:      handleSwipeLeft()
        case .swipeUp:        handleSwipeUp()
        case .swipeDown:      handleSwipeDown()
        case .longPressLeft:  player.temporarySlowDown()
        case .longPressRight: player.temporarySpeedUp()
        case .longPressEnd:   player.resetTemporaryPlaybackSpeed()
        }
    }

    private func handleSwipeRight() {
        guard Const.swipeGestureRight.bool ?? true else { return }
        if player.goToPreviousChapter() {
            hapticTrigger.toggle()
            OverlayFullscreenVM.shared.show(.previous)
            onChapterSwipe?()
        }
    }

    private func handleSwipeLeft() {
        guard Const.swipeGestureLeft.bool ?? true else { return }
        if player.goToNextChapter() {
            hapticTrigger.toggle()
            OverlayFullscreenVM.shared.show(.next)
            onChapterSwipe?()
        }
    }

    private func handleSwipeUp() {
        guard Const.swipeGestureUp.bool ?? true else { return }
        hapticTrigger.toggle()
        if let handleSwipe {
            handleSwipe(.up)
        } else {
            let appliedSpeed = PlayerManager.shared.tempSpeedChange(faster: true)
            OverlayFullscreenVM.shared.show(appliedSpeed ? .speedUp : .regularSpeed)
        }
    }

    private func handleSwipeDown() {
        guard Const.swipeGestureDown.bool ?? true else { return }
        hapticTrigger.toggle()
        if let handleSwipe {
            handleSwipe(.down)
        } else {
            let appliedSpeed = PlayerManager.shared.tempSpeedChange(faster: false)
            OverlayFullscreenVM.shared.show(appliedSpeed ? .slowDown : .regularSpeed)
        }
    }

    func seekBackward() {
        if player.seekBackward() {
            OverlayFullscreenVM.shared.show(.seekBackward)
            AutoHideVM.shared.reset()
            onDoubleTap?()
        }
    }

    func seekForward() {
        if player.seekForward() {
            OverlayFullscreenVM.shared.show(.seekForward)
            AutoHideVM.shared.reset()
            onDoubleTap?()
        }
    }
}

@Observable
class GestureTrackingState {
    @ObservationIgnored private var touchStartTime: Date?
    @ObservationIgnored private var touchStartLocation: CGPoint?
    @ObservationIgnored private var isSwiping = false
    @ObservationIgnored fileprivate var longTouchSent = false
    @ObservationIgnored private var centerTouch = false
    @ObservationIgnored private let longPressThreshold: TimeInterval = 0.3
    @ObservationIgnored private let swipeThreshold: CGFloat = 50
    @ObservationIgnored private let doubleTapInterval: TimeInterval = 0.3
    @ObservationIgnored private var lastTapDate: Date?
    @ObservationIgnored private var longPressTask: Task<Void, Never>?
    @ObservationIgnored var isPinching = false
    @ObservationIgnored fileprivate var lockedSwipeAxis: SwipeAxis?

    func handleTouchStart(
        value: DragGesture.Value,
        in size: CGSize,
        gestureHandler: @escaping @MainActor (PlayerGestureOverlay.GestureType) -> Void
    ) {
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
            let isLeft = value.startLocation.x < midX
            longPressTask?.cancel()
            longPressTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(longPressThreshold))
                guard !Task.isCancelled, !isSwiping, !centerTouch, !isPinching else { return }
                longTouchSent = true
                gestureHandler(isLeft ? .longPressLeft : .longPressRight)
            }
        }
    }

    func handleTouchMove(value: DragGesture.Value, in size: CGSize) {
        guard let start = touchStartLocation else { return }
        let deltaX = value.location.x - start.x
        let deltaY = value.location.y - start.y
        if !isSwiping && (abs(deltaX) > 10 || abs(deltaY) > 10) {
            isSwiping = true
            longPressTask?.cancel()
            longPressTask = nil
        }
    }

    @MainActor
    fileprivate func handleTouchEnd(
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
        let maxTouchSize = min(100, size.width * 0.15)
        let midX = size.width / 2
        let midY = size.height / 2
        let isHorizontalCenter = abs(end.x - midX) < maxTouchSize
        let isVerticalCenter = abs(end.y - midY) < maxTouchSize
        let now = Date()
        if longTouchSent {
            gestureHandler(.longPressEnd)
            resetTouch()
            return
        }
        guard !isPinching else {
            resetTouch()
            return
        }
        if isSwiping {
            switch lockedAxis {
            case .horizontal:
                if deltaX > swipeThreshold { gestureHandler(.swipeRight) } else if deltaX < -swipeThreshold { gestureHandler(.swipeLeft) }
            case .vertical:
                if deltaY > swipeThreshold { gestureHandler(.swipeDown) } else if deltaY < -swipeThreshold { gestureHandler(.swipeUp) }
            case nil:
                if abs(deltaX) > abs(deltaY) {
                    if deltaX > swipeThreshold { gestureHandler(.swipeRight) } else if deltaX < -swipeThreshold { gestureHandler(.swipeLeft) }
                } else {
                    if deltaY > swipeThreshold { gestureHandler(.swipeDown) } else if deltaY < -swipeThreshold { gestureHandler(.swipeUp) }
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
        if let lastTap = lastTapDate, now.timeIntervalSince(lastTap) < doubleTapInterval {
            // Second tap within interval: fire seek gesture only (.tap already fired on first tap)
            let side: PlayerGestureOverlay.GestureType = (end.x < midX) ? .doubleTapLeft : .doubleTapRight
            gestureHandler(side)
        } else {
            // First tap: fire immediately with no delay
            gestureHandler(.tap)
        }
        lastTapDate = now
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
             centerTap,
             longPressLeft,
             longPressRight,
             longPressEnd
    }
}

#Preview {
    Color.blue
        .frame(width: 600, height: 500)
        .modifier(PlayerGestureOverlay())
}
