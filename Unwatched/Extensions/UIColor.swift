//
//  UIColor.swift
//  Unwatched
//

import UIKit

extension UIColor {
    func isBlack() -> Bool {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return red == 0 && green == 0 && blue == 0 && alpha == 1
    }
}
