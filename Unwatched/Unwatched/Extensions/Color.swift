//
//  Color.swift
//  Unwatched
//

import SwiftUI

extension Color {
    func mix(with color: Color, by percentage: Double) -> Color {
        let clampedPercentage = min(max(percentage, 0), 1)

        #if os(iOS)
        let components1 = UIColor(self).cgColor.components!
        let components2 = UIColor(color).cgColor.components!
        #else
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

public extension Color {
    static func random(randomOpacity: Bool = false) -> Color {
        Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1),
            opacity: randomOpacity ? .random(in: 0...1) : 1
        )
    }
}

extension View {
    func debug() -> some View {
        self.border(Color.random())
    }
}
