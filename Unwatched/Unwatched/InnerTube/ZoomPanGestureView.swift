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
            .gesture(PinchZoomRepresentable(
                zoom: $zoom, offset: $offset, isGesturing: $isGesturing, contentFrame: contentFrame))
            .gesture(TwoFingerPanRepresentable(
                zoom: $zoom, offset: $offset, isGesturing: $isGesturing, contentFrame: contentFrame))
    }
}

// MARK: - Pinch-to-Zoom

private struct PinchZoomRepresentable: UIGestureRecognizerRepresentable {
    @Binding var zoom: CGFloat
    @Binding var offset: CGSize
    @Binding var isGesturing: Bool
    var contentFrame: CGRect

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPinchGestureRecognizer {
        let gr = UIPinchGestureRecognizer()
        gr.cancelsTouchesInView = false
        gr.delaysTouchesBegan   = false
        gr.delegate             = context.coordinator
        return gr
    }

    func updateUIGestureRecognizer(_ recognizer: UIPinchGestureRecognizer, context: Context) {
        let c = context.coordinator
        c.getZoom         = { zoom }
        c.setZoom         = { zoom = $0 }
        c.getOffset       = { offset }
        c.setOffset       = { offset = $0 }
        c.setGesturing    = { isGesturing = $0 }
        c.getContentFrame = { contentFrame }
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPinchGestureRecognizer, context: Context) {
        context.coordinator.handle(recognizer)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var getZoom:         () -> CGFloat     = { 1 }
        var setZoom:         (CGFloat) -> Void = { _ in }
        var getOffset:       () -> CGSize      = { .zero }
        var setOffset:       (CGSize) -> Void  = { _ in }
        var setGesturing:    (Bool) -> Void    = { _ in }
        var getContentFrame: () -> CGRect      = { .zero }

        private var startZoom:     CGFloat = 1
        private var startOffset:   CGSize  = .zero
        private var startCentroid: CGPoint = .zero

        func gestureRecognizer(_ gr: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        func handle(_ gesture: UIPinchGestureRecognizer) {
            // Centre/size come from the video's global layout rect (what `scaleEffect` anchors
            // on), not `view.bounds`. Centroids are read in window coords (`location(in: nil)`),
            // which share SwiftUI's `.global` origin, so both sides agree in every orientation.
            let frame = getContentFrame()
            let size = frame.size
            guard size.width > 0, size.height > 0 else { return }
            let cx = frame.midX, cy = frame.midY

            switch gesture.state {
            case .began:
                startZoom     = getZoom()
                startOffset   = getOffset()
                startCentroid = gesture.location(in: nil)
                setGesturing(true)

            case .changed:
                // When one finger lifts first, the centroid jumps to the remaining finger.
                // Freeze until the gesture ends naturally rather than producing a visual jump.
                guard gesture.numberOfTouches >= 2 else { break }
                let newZoom = max(1.0, min(5.0, startZoom * gesture.scale))
                let cur     = gesture.location(in: nil)
                // Screen-space vectors: view center → start/current centroid.
                let scX = startCentroid.x - cx;  let scY = startCentroid.y - cy
                let ccX = cur.x - cx;            let ccY = cur.y - cy
                // Content point (zoom=1 space) under the start centroid.
                let px  = (scX - startOffset.width)  / startZoom
                let py  = (scY - startOffset.height) / startZoom
                // New offset: current centroid stays over the same content point.
                // Translational finger movement (pan-during-zoom) is automatic.
                let newOff = CGSize(width: ccX - px * newZoom, height: ccY - py * newZoom)
                setZoom(newZoom)
                setOffset(clamped(newOff, zoom: newZoom, size: size))

            case .ended, .cancelled, .failed:
                if getZoom() < 1.05 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        setZoom(1.0); setOffset(.zero)
                    }
                }
                setGesturing(false)

            default: break
            }
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

// MARK: - Two-Finger Pan

private struct TwoFingerPanRepresentable: UIGestureRecognizerRepresentable {
    @Binding var zoom: CGFloat
    @Binding var offset: CGSize
    @Binding var isGesturing: Bool
    var contentFrame: CGRect

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let gr = UIPanGestureRecognizer()
        gr.minimumNumberOfTouches = 2
        gr.maximumNumberOfTouches = 2
        gr.cancelsTouchesInView   = false
        gr.delaysTouchesBegan     = false
        gr.delegate               = context.coordinator
        return gr
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let c = context.coordinator
        c.getZoom         = { zoom }
        c.getOffset       = { offset }
        c.setOffset       = { offset = $0 }
        c.setGesturing    = { isGesturing = $0 }
        c.getContentFrame = { contentFrame }
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        context.coordinator.handle(recognizer)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var getZoom:         () -> CGFloat     = { 1 }
        var getOffset:       () -> CGSize      = { .zero }
        var setOffset:       (CGSize) -> Void  = { _ in }
        var setGesturing:    (Bool) -> Void    = { _ in }
        var getContentFrame: () -> CGRect      = { .zero }

        private var startOffset: CGSize = .zero

        func gestureRecognizer(_ gr: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        func handle(_ gesture: UIPanGestureRecognizer) {
            guard getZoom() > 1.0 else { return }
            switch gesture.state {
            case .began:
                startOffset = getOffset()
                setGesturing(true)
            case .changed:
                let t    = gesture.translation(in: nil)
                let size = getContentFrame().size
                setOffset(clamped(
                    CGSize(width: startOffset.width + t.x, height: startOffset.height + t.y),
                    zoom: getZoom(), size: size
                ))
            case .ended, .cancelled, .failed:
                setGesturing(false)
            default: break
            }
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
