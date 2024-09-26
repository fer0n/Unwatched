//
//  PlayerControlButtonStyle.swift
//  Unwatched
//

import SwiftUI

struct PlayerControlButtonStyle: ViewModifier {
    @Environment(\.isEnabled) var isEnabled
    var isOn: Bool = false

    func body(content: Content) -> some View {

        VStack(spacing: 5) {
            content
            if isOn {
                Circle()
                    .frame(width: 5, height: 5)
            }
        }
        .opacity(isEnabled ? 1 : 0.3)
        .padding(3)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
