//
//  UIWindow.swift
//  Unwatched
//

import UIKit

public extension UIWindow {

    /// Unload all views and add back.
    /// Useful for applying `UIAppearance` changes to existing views.
    func reload() {
        subviews.forEach { view in
            view.removeFromSuperview()
            addSubview(view)
        }
    }
}

public extension Array where Element == UIWindow {

    /// Unload all views for each `UIWindow` and add back.
    /// Useful for applying `UIAppearance` changes to existing views.
    @MainActor
    func reload() {
        forEach { $0.reload() }
    }
}
