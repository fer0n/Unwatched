#if canImport(UIKit) && !os(visionOS)
import UIKit

/// Keeps horizontal pagers still while a pinch is under way.
@MainActor
final class PagerPanLock {
    private var pagerPans: [WeakPan] = []
    private var lockedPans: [WeakPan] = []
    private var isLocked = false

    func register(_ recognizer: UIGestureRecognizer) {
        guard let pan = recognizer as? UIPanGestureRecognizer,
              let scrollView = pan.view as? UIScrollView,
              scrollView.panGestureRecognizer === pan,
              scrollView.contentSize.width > scrollView.bounds.width,
              !pagerPans.contains(where: { $0.recognizer === pan }) else { return }
        pagerPans.append(WeakPan(pan))
        if isLocked { disablePagerPans() }
    }

    func lock() {
        isLocked = true
        disablePagerPans()
    }

    func unlock() {
        isLocked = false
        for pan in lockedPans { pan.recognizer?.isEnabled = true }
        lockedPans.removeAll()
        pagerPans.removeAll()
    }

    private func disablePagerPans() {
        for pan in pagerPans {
            guard let recognizer = pan.recognizer, recognizer.isEnabled else { continue }
            recognizer.isEnabled = false
            lockedPans.append(pan)
        }
    }

    isolated deinit {
        unlock()
    }
}

private struct WeakPan {
    weak var recognizer: UIPanGestureRecognizer?

    init(_ recognizer: UIPanGestureRecognizer) {
        self.recognizer = recognizer
    }
}

#endif
