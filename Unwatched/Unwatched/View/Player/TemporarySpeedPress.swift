//
//  TemporarySpeedPress.swift
//  Unwatched
//

import SwiftUI

struct TemporarySpeedPress: ViewModifier {
    let minDuration: Double
    let maxDistance: Double
    let onPress: () -> Void
    let onRelease: () -> Void

    func body(content: Content) -> some View {
        #if canImport(UIKit) && !os(visionOS)
        content
            .gesture(
                LongPressRecognizer(
                    minDuration: minDuration,
                    maxDistance: maxDistance,
                    onPress: onPress,
                    onRelease: onRelease
                )
            )
        #else
        content
            .onLongPressGesture(minimumDuration: minDuration, maximumDistance: maxDistance) {
                onPress()
            } onPressingChanged: { pressing in
                if !pressing { onRelease() }
            }
        #endif
    }
}

#if canImport(UIKit) && !os(visionOS)
private struct LongPressRecognizer: UIGestureRecognizerRepresentable {
    let minDuration: Double
    let maxDistance: Double
    let onPress: () -> Void
    let onRelease: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        UILongPressGestureRecognizer()
    }

    func updateUIGestureRecognizer(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        recognizer.minimumPressDuration = minDuration
        recognizer.allowableMovement = maxDistance
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began: onPress()
        case .ended, .cancelled: onRelease()
        default: break
        }
    }
}
#endif
