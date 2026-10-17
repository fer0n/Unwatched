#if canImport(UIKit) && !os(visionOS)
import UIKit

/// Custom recognizer that tracks its own touches so it can stay alive across finger-count
/// changes. Pinch geometry is derived from the first two tracked touches directly (spread +
/// centroid) rather than `UIPinchGestureRecognizer.scale`, which lets the coordinator re-baseline
/// cleanly whenever a finger is added or removed instead of the centroid lurching to the
/// remaining finger.
final class PinchPanGestureRecognizer: UIGestureRecognizer {
    private(set) var trackedTouches: [UITouch] = []
    var activeCount: Int { trackedTouches.count }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        for t in touches where !trackedTouches.contains(t) { trackedTouches.append(t) }
        if trackedTouches.count >= 2 {
            state = (state == .possible) ? .began : .changed
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard trackedTouches.count >= 2 else { return }
        state = (state == .possible) ? .began : .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        trackedTouches.removeAll { touches.contains($0) }
        finishOrContinue(terminal: .ended)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        trackedTouches.removeAll { touches.contains($0) }
        finishOrContinue(terminal: .cancelled)
    }

    // End only once every finger is up; while ≥1 remains the gesture lives on (frozen if <2),
    // emitting `.changed` so the coordinator re-baselines for the new finger set.
    private func finishOrContinue(terminal: UIGestureRecognizer.State) {
        let wasActive = (state == .began || state == .changed)
        if trackedTouches.isEmpty {
            state = wasActive ? terminal : .failed
        } else if wasActive {
            state = .changed
        }
    }

    override func reset() {
        super.reset()
        trackedTouches.removeAll()
    }

    /// Centroid of the active touches (the first two), in window coords (shares SwiftUI's
    /// `.global`). Works with a single remaining finger too, which drives one-finger panning.
    var centroidPoint: CGPoint? {
        let pts = trackedTouches.prefix(2).map { $0.location(in: nil) }
        guard !pts.isEmpty else { return nil }
        let sx = pts.reduce(0) { $0 + $1.x }
        let sy = pts.reduce(0) { $0 + $1.y }
        return CGPoint(x: sx / CGFloat(pts.count), y: sy / CGFloat(pts.count))
    }

    /// Distance between the first two tracked touches (nil with fewer than two).
    var twoFingerSpread: CGFloat? {
        guard trackedTouches.count >= 2 else { return nil }
        let a = trackedTouches[0].location(in: nil)
        let b = trackedTouches[1].location(in: nil)
        return hypot(a.x - b.x, a.y - b.y)
    }
}

#endif
