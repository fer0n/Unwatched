//
//  PlayerGestureOverlay.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

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
                                        gestureState
                                            .handleTouchEnd(
                                                value: value,
                                                in: geometry.size,
                                                lockedAxis: axis
                                            ) { gesture in
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

        if let name = gesture.analyticsName {
            Signal.gesture(name)
        }

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
        case .swipeControlsEdge: openDescription()
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

    private func openDescription() {
        hapticTrigger.toggle()
        AutoHideVM.shared.openDescriptionPopover()
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

extension PlayerGestureOverlay {
    enum GestureType {
        case tap,
             doubleTapLeft,
             doubleTapRight,
             swipeLeft,
             swipeRight,
             swipeUp,
             swipeDown,
             swipeControlsEdge,
             centerTap,
             longPressLeft,
             longPressRight,
             longPressEnd

        /// Low-cardinality analytics id, or nil for gestures we don't track: `.tap` toggles
        /// the controls constantly (noise) and `.longPressEnd` is just the release of a
        /// long-press that's already counted on its start.
        var analyticsName: String? {
            switch self {
            case .tap, .longPressEnd: return nil
            case .centerTap: return "centerTap"
            case .doubleTapLeft: return "doubleTapLeft"
            case .doubleTapRight: return "doubleTapRight"
            case .swipeLeft: return "swipeLeft"
            case .swipeRight: return "swipeRight"
            case .swipeUp: return "swipeUp"
            case .swipeDown: return "swipeDown"
            case .swipeControlsEdge: return "swipeControlsEdge"
            case .longPressLeft: return "longPressLeft"
            case .longPressRight: return "longPressRight"
            }
        }
    }
}

#Preview {
    Color.blue
        .frame(width: 600, height: 500)
        .modifier(PlayerGestureOverlay())
}
