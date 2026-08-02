//
//  InboxCardScrollSwipe.swift
//  Unwatched
//

#if os(macOS)
import SwiftUI

/// Swiping the card with two fingers on a trackpad, which arrives as scroll events
///
/// A local event monitor rather than `scrollWheel(with:)`, so the view stays click-through:
/// an `NSView` over the card would swallow the taps meant for the controls inside it.
struct InboxCardScrollSwipe: NSViewRepresentable {
    let isEnabled: Bool
    let onChange: (CGSize) -> Void
    let onEnd: (CGSize, CGSize) -> Void

    func makeNSView(context: Context) -> SwipeView {
        let view = SwipeView()
        update(view)
        return view
    }

    func updateNSView(_ nsView: SwipeView, context: Context) {
        update(nsView)
    }

    private func update(_ view: SwipeView) {
        view.isEnabled = isEnabled
        view.onChange = onChange
        view.onEnd = onEnd
    }

    class SwipeView: NSView {
        var onChange: ((CGSize) -> Void)?
        var onEnd: ((CGSize, CGSize) -> Void)?
        var isEnabled = false {
            didSet {
                if !isEnabled {
                    translation = nil
                }
            }
        }

        private var monitor: Any?
        private var translation: CGSize?
        private var velocity: CGSize = .zero
        private var lastTimestamp: TimeInterval = 0
        private var swallowsMomentum = false

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                removeMonitor()
            } else if monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                    self?.handle(event) == true ? nil : event
                }
            }
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        private func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        /// Whether the event became part of a swipe and should reach nothing else
        private func handle(_ event: NSEvent) -> Bool {
            if event.phase.contains(.began) {
                // a mouse wheel comes without phases, it never starts a swipe
                swallowsMomentum = false
                guard isEnabled, isEventInside(event), !isOverInnerScrollView(event) else {
                    return false
                }
                translation = .zero
                velocity = .zero
                lastTimestamp = event.timestamp
                onChange?(.zero)
                return true
            }

            if !event.momentumPhase.isEmpty {
                // the tail of a swipe that was decided when the fingers left
                return swallowsMomentum
            }

            guard var current = translation else { return false }

            if event.phase.contains(.changed) {
                current.width += event.scrollingDeltaX
                current.height += event.scrollingDeltaY
                translation = current
                trackVelocity(event)
                onChange?(current)
                return true
            }
            if event.phase.contains(.ended) {
                translation = nil
                swallowsMomentum = true
                onEnd?(current, velocity)
                return true
            }
            if event.phase.contains(.cancelled) {
                translation = nil
                onEnd?(.zero, .zero)
                return true
            }
            return false
        }

        /// Smoothed, a single event's delta is too jittery to flick on
        private func trackVelocity(_ event: NSEvent) {
            let elapsed = event.timestamp - lastTimestamp
            lastTimestamp = event.timestamp
            guard elapsed > 0, elapsed < 0.1 else {
                velocity = .zero
                return
            }
            velocity = velocity * 0.4
                + CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY) * (0.6 / elapsed)
        }

        private func isEventInside(_ event: NSEvent) -> Bool {
            guard let window, event.window === window, !isHiddenOrHasHiddenAncestor else {
                return false
            }
            return visibleRect.contains(convert(event.locationInWindow, from: nil))
        }

        /// Scrollable content within the card, the chapter chips, keeps its own two-finger scrolling
        private func isOverInnerScrollView(_ event: NSEvent) -> Bool {
            guard let hit = window?.contentView?.hitTest(event.locationInWindow),
                  let scrollView = hit.enclosingScrollView else {
                return false
            }
            return bounds.contains(scrollView.convert(scrollView.bounds, to: self))
        }
    }
}
#endif
