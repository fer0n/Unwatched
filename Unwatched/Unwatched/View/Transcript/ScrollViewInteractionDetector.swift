//
//  ScrollViewInteractionDetector.swift
//  Unwatched
//

import SwiftUI

#if os(iOS) || os(visionOS)
struct ScrollViewInteractionDetector: UIViewRepresentable {
    let onUserScroll: () -> Void

    func makeUIView(context: Context) -> ScrollDetectorView {
        let view = ScrollDetectorView()
        view.onUserScroll = onUserScroll
        return view
    }

    func updateUIView(_ uiView: ScrollDetectorView, context: Context) {
        uiView.onUserScroll = onUserScroll
    }

    class ScrollDetectorView: UIView, UIGestureRecognizerDelegate {
        var onUserScroll: (() -> Void)?
        private var gestureAdded = false

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard !gestureAdded, window != nil else { return }
            if let scrollView = findParentScrollView() {
                let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
                gesture.delegate = self
                scrollView.addGestureRecognizer(gesture)
                gestureAdded = true
            }
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            if gesture.state == .began {
                onUserScroll?()
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        private func findParentScrollView() -> UIScrollView? {
            var current = superview
            while let view = current {
                if let scrollView = view as? UIScrollView {
                    return scrollView
                }
                current = view.superview
            }
            return nil
        }
    }
}
#elseif os(macOS)
struct ScrollViewInteractionDetector: NSViewRepresentable {
    let onUserScroll: () -> Void

    func makeNSView(context: Context) -> ScrollDetectorView {
        let view = ScrollDetectorView()
        view.onUserScroll = onUserScroll
        return view
    }

    func updateNSView(_ nsView: ScrollDetectorView, context: Context) {
        nsView.onUserScroll = onUserScroll
    }

    class ScrollDetectorView: NSView {
        var onUserScroll: (() -> Void)?
        private var observer: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard observer == nil, window != nil else { return }
            if let scrollView = findParentScrollView() {
                observer = NotificationCenter.default.addObserver(
                    forName: NSScrollView.willStartLiveScrollNotification,
                    object: scrollView,
                    queue: .main
                ) { [weak self] _ in
                    self?.onUserScroll?()
                }
            }
        }

        deinit {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        private func findParentScrollView() -> NSScrollView? {
            var current = superview
            while let view = current {
                if let scrollView = view as? NSScrollView {
                    return scrollView
                }
                current = view.superview
            }
            return nil
        }
    }
}
#endif
