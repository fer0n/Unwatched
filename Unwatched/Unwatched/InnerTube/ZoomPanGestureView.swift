#if !os(macOS)
import SwiftUI
import UIKit

// MARK: - ZoomPanModifier

/// Applies pinch-to-zoom and two-finger pan to any view.
/// No-ops on iOS 17; gesture recognizers require iOS 18's UIGestureRecognizerRepresentable.
struct ZoomPanModifier: ViewModifier {
    @Binding var zoom: CGFloat
    @Binding var offset: CGSize
    @Binding var isGesturing: Bool

    // The video's un-transformed layout rect, in the global coordinate space.
    // The gesture math must reference *this* rect (the same one `scaleEffect` anchors
    // on), not `gesture.view.bounds` — in portrait the recognizer's host view is taller
    // than the letterboxed video, so its center sits below the video and the zoom anchor
    // is wrong. In landscape the video fills the host, which is why it only breaks in portrait.
    @State private var contentFrame: CGRect = .zero

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
                action: { contentFrame = $0 }
            // A single recognizer owns zoom, pan AND `isGesturing`. One recognizer (rather
            // than separate pinch + pan that fought over `offset`) means there's one consistent
            // baseline, and it stays active for the *whole* two-finger interaction — including
            // the tail after one finger lifts — so nothing jumps and the single-finger swipe /
            // long-press gestures stacked below never hijack it mid-zoom.
            .gesture(PinchPanRepresentable(
                zoom: $zoom, offset: $offset, isGesturing: $isGesturing, contentFrame: contentFrame))
    }
}

// MARK: - Combined pinch + two-finger pan

/// Custom recognizer that tracks its own touches so it can stay alive across finger-count
/// changes. Pinch geometry is derived from the first two tracked touches directly (spread +
/// centroid) rather than `UIPinchGestureRecognizer.scale`, which lets the coordinator re-baseline
/// cleanly whenever a finger is added or removed instead of the centroid lurching to the
/// remaining finger.
private final class PinchPanGestureRecognizer: UIGestureRecognizer {
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

private struct PinchPanRepresentable: UIGestureRecognizerRepresentable {
    @Binding var zoom: CGFloat
    @Binding var offset: CGSize
    @Binding var isGesturing: Bool
    var contentFrame: CGRect

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> PinchPanGestureRecognizer {
        let gr = PinchPanGestureRecognizer()
        gr.cancelsTouchesInView = false
        gr.delaysTouchesBegan   = false
        gr.delegate             = context.coordinator
        return gr
    }

    func updateUIGestureRecognizer(_ recognizer: PinchPanGestureRecognizer, context: Context) {
        let c = context.coordinator
        c.getZoom         = { zoom }
        c.setZoom         = { zoom = $0 }
        c.getOffset       = { offset }
        c.setOffset       = { offset = $0 }
        c.setGesturing    = { isGesturing = $0 }
        c.getContentFrame = { contentFrame }
    }

    func handleUIGestureRecognizerAction(_ recognizer: PinchPanGestureRecognizer, context: Context) {
        context.coordinator.handle(recognizer)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var getZoom:         () -> CGFloat     = { 1 }
        var setZoom:         (CGFloat) -> Void = { _ in }
        var getOffset:       () -> CGSize      = { .zero }
        var setOffset:       (CGSize) -> Void  = { _ in }
        var setGesturing:    (Bool) -> Void    = { _ in }
        var getContentFrame: () -> CGRect      = { .zero }

        // Baseline captured at `.began` and re-captured whenever the finger count changes.
        private var startZoom:        CGFloat = 1
        private var startOffset:      CGSize  = .zero
        private var startCentroid:    CGPoint = .zero
        private var startSpread:      CGFloat = 0
        private var lastTouchCount:   Int     = 0

        func gestureRecognizer(_ gr: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        func handle(_ gesture: PinchPanGestureRecognizer) {
            // Centre/size come from the video's global layout rect (what `scaleEffect` anchors
            // on), not `view.bounds`. Touch locations are read in window coords, which share
            // SwiftUI's `.global` origin, so both sides agree in every orientation.
            let frame = getContentFrame()
            let size = frame.size
            guard size.width > 0, size.height > 0 else { return }
            let cx = frame.midX, cy = frame.midY

            switch gesture.state {
            case .began:
                setGesturing(true)
                rebaseline(gesture)

            case .changed:
                // A finger was added or lifted → reset the baseline to the new touch set so the
                // remaining/new fingers don't snap the content to a new position.
                if gesture.activeCount != lastTouchCount {
                    rebaseline(gesture)
                }
                guard let point = gesture.centroidPoint else { return }

                if gesture.activeCount >= 2, startSpread > 0 {
                    // Two fingers: pinch (+ pan, which falls out of the centroid math).
                    let scale   = (gesture.twoFingerSpread ?? startSpread) / startSpread
                    let newZoom = max(1.0, min(5.0, startZoom * scale))
                    // Screen-space vectors: view center → start/current centroid.
                    let scX = startCentroid.x - cx;  let scY = startCentroid.y - cy
                    let ccX = point.x - cx;          let ccY = point.y - cy
                    // Content point (zoom=1 space) under the start centroid.
                    let px  = (scX - startOffset.width)  / startZoom
                    let py  = (scY - startOffset.height) / startZoom
                    // New offset keeps that content point under the current centroid.
                    let newOff = CGSize(width: ccX - px * newZoom, height: ccY - py * newZoom)
                    setZoom(newZoom)
                    setOffset(clamped(newOff, zoom: newZoom, size: size))
                } else if getZoom() > 1 {
                    // One finger left from a pinch: keep panning the zoomed video with it
                    // (matches Photos) instead of freezing.
                    let newOff = CGSize(width:  startOffset.width  + point.x - startCentroid.x,
                                        height: startOffset.height + point.y - startCentroid.y)
                    setOffset(clamped(newOff, zoom: getZoom(), size: size))
                }

            case .ended, .cancelled, .failed:
                lastTouchCount = 0
                if getZoom() < 1.05 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        setZoom(1.0); setOffset(.zero)
                    }
                }
                setGesturing(false)

            default: break
            }
        }

        private func rebaseline(_ gesture: PinchPanGestureRecognizer) {
            startZoom      = getZoom()
            startOffset    = getOffset()
            startCentroid  = gesture.centroidPoint ?? .zero
            startSpread    = gesture.twoFingerSpread ?? 0
            lastTouchCount = gesture.activeCount
        }

        private func clamped(_ off: CGSize, zoom: CGFloat, size: CGSize) -> CGSize {
            guard zoom > 1 else { return .zero }
            let mx = size.width  * (zoom - 1) / 2
            let my = size.height * (zoom - 1) / 2
            return CGSize(width:  max(-mx, min(mx, off.width)),
                          height: max(-my, min(my, off.height)))
        }
    }
}
#endif
