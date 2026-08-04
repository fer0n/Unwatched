//
//  CGSize.swift
//  Unwatched
//

import Foundation

extension CGSize {
    var length: CGFloat {
        hypot(width, height)
    }

    /// Direction on its own, `.zero` for a size that has none
    var normalized: CGSize {
        let magnitude = length
        return magnitude > 0 ? self * (1 / magnitude) : .zero
    }

    /// How much of `self` points along `other`, negative when it points against it
    func projected(on other: CGSize) -> CGFloat {
        let heading = other.normalized
        return width * heading.width + height * heading.height
    }

    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }

    static func - (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
    }

    static func * (lhs: CGSize, rhs: CGFloat) -> CGSize {
        CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
    }
}
