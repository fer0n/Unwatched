//
//  UIColor.swift
//  Unwatched
//

import SwiftUI

public extension Color {
    var isBlack: Bool {
        self == .black
    }

    /// Invisible, but unlike `.clear` still hit tested and not optimized away.
    static let tappableClear = Color.black.opacity(0.000001)
}

extension Color {
    /// nil for anything but 3, 6 or 8 hex digits, so a malformed stored value reads as missing.
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard let int = UInt64(hex, radix: 16) else { return nil }
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Always six digits: components outside sRGB (extended or P3 colors) are clamped
    func toHex() -> String {
        let resolved = resolve(in: EnvironmentValues())
        func byte(_ value: Float) -> Int {
            Int((min(max(value, 0), 1) * 255).rounded())
        }
        return String(format: "%02X%02X%02X", byte(resolved.red), byte(resolved.green), byte(resolved.blue))
    }
}
