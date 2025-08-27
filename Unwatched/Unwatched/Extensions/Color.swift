//
//  Color.swift
//  Unwatched
//

import SwiftUI

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
