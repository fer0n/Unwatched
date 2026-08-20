//
//  InboxCardDrag.swift
//  Unwatched
//

import SwiftUI

extension View {
    /// Drag for swiping an inbox card away, on macOS also a two-finger trackpad swipe
    ///
    /// A UIKit pan rather than a `DragGesture`: that one only takes over once the card's own taps
    /// have failed, so the card jumps, and simultaneously it fights the controls inside the card.
    ///
    /// - Parameter isEnabled: on macOS the two-finger swipe reaches the stack through an event
    ///   monitor, which `allowsHitTesting` can't keep away from an empty stack
    func inboxCardDrag(
        isEnabled: Bool,
        onChange: @escaping (CGSize) -> Void,
        onEnd: @escaping (_ translation: CGSize, _ velocity: CGSize) -> Void
    ) -> some View {
        #if os(macOS)
        modifier(InboxCardDragFallback(onChange: onChange, onEnd: onEnd))
            .background(
                InboxCardScrollSwipe(isEnabled: isEnabled, onChange: onChange, onEnd: onEnd)
            )
        #elseif os(visionOS)
        modifier(InboxCardDragFallback(onChange: onChange, onEnd: onEnd))
        #else
        gesture(InboxCardDrag(onChange: onChange, onEnd: onEnd))
        #endif
    }
}

#if !os(macOS) && !os(visionOS)
private struct InboxCardDrag: UIGestureRecognizerRepresentable {
    let onChange: (CGSize) -> Void
    let onEnd: (CGSize, CGSize) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began:
            // don't pass on the head start the pan needed to recognize
            recognizer.setTranslation(.zero, in: nil)
            onChange(.zero)
        case .changed:
            onChange(Self.translation(recognizer))
        case .ended:
            let velocity = recognizer.velocity(in: nil)
            onEnd(
                Self.translation(recognizer),
                CGSize(width: velocity.x, height: velocity.y)
            )
        case .cancelled, .failed:
            onEnd(.zero, .zero)
        default:
            break
        }
    }

    /// Measured in the window, the card itself moves along while it's being dragged
    private static func translation(_ recognizer: UIPanGestureRecognizer) -> CGSize {
        let translation = recognizer.translation(in: nil)
        return CGSize(width: translation.x, height: translation.y)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        /// Let the chapter list scroll first, its own pan fails for anything it can't follow
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRequireFailureOf other: UIGestureRecognizer
        ) -> Bool {
            guard let view = gestureRecognizer.view, let otherView = other.view else { return false }
            return otherView is UIScrollView && otherView.isDescendant(of: view)
        }
    }
}
#else
/// AppKit and visionOS have no pan recognizer worth bridging, measure the drag from where
/// SwiftUI hands it over
private struct InboxCardDragFallback: ViewModifier {
    let onChange: (CGSize) -> Void
    let onEnd: (CGSize, CGSize) -> Void

    @State private var start: CGSize?

    func body(content: Content) -> some View {
        content.gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let start = start ?? value.translation
                    if self.start == nil {
                        self.start = start
                    }
                    onChange(value.translation - start)
                }
                .onEnded { value in
                    let start = start ?? .zero
                    self.start = nil
                    onEnd(value.translation - start, value.velocity)
                }
        )
    }
}
#endif
