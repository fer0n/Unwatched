//
//  CapsuleButtonStyle.swift
//  Unwatched
//

import SwiftUI

struct CapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? 1 : 0.2)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(Material.thin)
            .clipShape(Capsule())
            .foregroundColor(.myAccentColor)
    }
}

#Preview {
    Button(action: {}) {
        Text("Hello")
    }
    .buttonStyle(CapsuleButtonStyle())
}
