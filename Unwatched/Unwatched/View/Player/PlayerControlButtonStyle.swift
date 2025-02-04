//
//  PlayerControlButtonStyle.swift
//  Unwatched
//

import SwiftUI

struct PlayerControlButtonStyle: ViewModifier {
    @Environment(\.isEnabled) var isEnabled
    var isOn: Bool = false

    func body(content: Content) -> some View {
        if isOn {
            content
                .symbolRenderingMode(.palette)
                .foregroundStyle(.black, Color.foregroundGray.opacity(0.5))
        } else {
            content
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    Color.foregroundGray.opacity(0.5),
                    Color.backgroundColor
                )
                .font(.system(size: 29))
        }
    }
}
