//
//  MenuHighlightSuppressor.swift
//  Unwatched
//

#if os(macOS)
import AppKit

/// Workaround: right-clicking a row in a SwiftUI `List` lets NSTableView lay an
/// `NSMenuHighlightView` over the table for as long as the menu is up, which reads as a rectangular
/// outline around the row. Remove once a SwiftUI list can opt out of it.
///
/// The view is only added *after* `NSMenu.didBeginTrackingNotification`, so a run-loop observer on
/// the modal menu tracking loop is the first moment it can be caught. Verified against macOS 26.
@MainActor
enum MenuHighlightSuppressor {
    private static let highlightViewClass: AnyClass? = NSClassFromString("NSMenuHighlightView")
    private static var observer: CFRunLoopObserver?
    /// Submenus post their own tracking notifications inside the menu that opened them.
    private static var trackingDepth = 0

    static func start() {
        guard highlightViewClass != nil else { return }
        NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                trackingDepth += 1
                addObserver()
            }
        }
        NotificationCenter.default.addObserver(
            forName: NSMenu.didEndTrackingNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                trackingDepth = max(0, trackingDepth - 1)
                if trackingDepth == 0 {
                    removeObserver()
                }
            }
        }
    }

    private static func addObserver() {
        guard observer == nil else { return }
        let new = CFRunLoopObserverCreateWithHandler(
            nil,
            CFRunLoopActivity.beforeWaiting.rawValue,
            true,
            0
        ) { _, _ in
            MainActor.assumeIsolated { hideHighlightViews() }
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), new, .commonModes)
        observer = new
        hideHighlightViews()
    }

    private static func removeObserver() {
        guard let observer else { return }
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes)
        self.observer = nil
    }

    private static func hideHighlightViews() {
        guard let highlightViewClass else { return }
        for window in NSApp.windows {
            guard let contentView = window.contentView else { continue }
            hide(highlightViewClass, in: contentView)
        }
    }

    private static func hide(_ highlightViewClass: AnyClass, in view: NSView) {
        for subview in view.subviews {
            if subview.isKind(of: highlightViewClass) {
                subview.isHidden = true
            } else {
                hide(highlightViewClass, in: subview)
            }
        }
    }
}
#endif
