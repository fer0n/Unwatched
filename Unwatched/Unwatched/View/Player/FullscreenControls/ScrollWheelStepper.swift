//
//  ScrollWheelStepper.swift
//  Unwatched
//

import SwiftUI

#if os(macOS)
/// Turns scroll input over the view into single steps: one per wheel detent,
/// one per `pointsPerStep` of trackpad scrolling.
///
/// A local event monitor is used instead of `scrollWheel(with:)` so the view stays click-through:
/// an `NSView` on top would otherwise swallow the taps meant for the control below it.
struct ScrollWheelStepper: NSViewRepresentable {
    /// Trackpad distance per step. Higher means slower.
    var pointsPerStep: CGFloat = 22
    /// `-1` when scrolling up, `1` when scrolling down
    let onStep: (Int) -> Void

    func makeNSView(context: Context) -> WheelView {
        let view = WheelView()
        view.pointsPerStep = pointsPerStep
        view.onStep = onStep
        return view
    }

    func updateNSView(_ nsView: WheelView, context: Context) {
        nsView.pointsPerStep = pointsPerStep
        nsView.onStep = onStep
    }

    class WheelView: NSView {
        var pointsPerStep: CGFloat = 22
        var onStep: ((Int) -> Void)?

        private var monitor: Any?
        private var accumulated: CGFloat = 0

        /// stays click-through; scroll events are picked up by the monitor instead
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

        /// Returns true when the event was handled and should not be delivered to the scroll view below.
        private func handle(_ event: NSEvent) -> Bool {
            guard isEventInside(event) else {
                return false
            }

            if event.hasPreciseScrollingDeltas {
                handleTrackpad(event)
            } else if event.scrollingDeltaY != 0 {
                onStep?(event.scrollingDeltaY > 0 ? -1 : 1)
            }
            return true
        }

        private func handleTrackpad(_ event: NSEvent) {
            if event.phase == .began {
                accumulated = 0
            }
            guard event.momentumPhase.isEmpty else {
                // the flick after lifting the fingers would skip several steps
                return
            }

            accumulated += event.scrollingDeltaY
            while accumulated >= pointsPerStep {
                accumulated -= pointsPerStep
                onStep?(-1)
            }
            while accumulated <= -pointsPerStep {
                accumulated += pointsPerStep
                onStep?(1)
            }
        }

        private func isEventInside(_ event: NSEvent) -> Bool {
            guard let window, event.window === window, !isHiddenOrHasHiddenAncestor else {
                return false
            }
            let point = convert(event.locationInWindow, from: nil)
            // visibleRect instead of bounds: it's empty while the control is clipped or off screen
            return visibleRect.contains(point)
        }
    }
}
#endif
