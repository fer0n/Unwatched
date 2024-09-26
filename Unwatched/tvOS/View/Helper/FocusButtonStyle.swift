//
//  FocusButtonStyle.swift
//  UnwatchedTV
//

import SwiftUI

struct FocusButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.15 : 1.0)
            .animation(.snappy.speed(1.5), value: isFocused)
    }
}
