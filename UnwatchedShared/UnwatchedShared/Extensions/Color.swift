//
//  UIColor.swift
//  Unwatched
//

import SwiftUI

public extension Color {
    var isBlack: Bool {
        self == .black
    }
    
    func myMix(with color: Color, by percentage: Double) -> Color {
        if #available(iOS 18, macOS 15, tvOS 18, *) {
            return self.mix(with: color, by: percentage)
        }
        
        let clampedPercentage = min(max(percentage, 0), 1)

        #if os(iOS) || os(tvOS)
        let components1 = UIColor(self).cgColor.components!
        let components2 = UIColor(color).cgColor.components!
        #elseif os(macOS)
        let components1 = NSColor(self).cgColor.components!
        let components2 = NSColor(color).cgColor.components!
        #endif
        let red = (1.0 - clampedPercentage) * components1[0] + clampedPercentage * components2[0]
        let green = (1.0 - clampedPercentage) * components1[1] + clampedPercentage * components2[1]
        let blue = (1.0 - clampedPercentage) * components1[2] + clampedPercentage * components2[2]
        let alpha = (1.0 - clampedPercentage) * components1[3] + clampedPercentage * components2[3]

        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String {
        let components = self.cgColor?.components ?? [0, 0, 0, 1]
        let red = Int(components[0] * 255)
        let green = Int(components[1] * 255)
        let blue = Int(components[2] * 255)
        return String(format: "%02X%02X%02X", red, green, blue)
    }
}
