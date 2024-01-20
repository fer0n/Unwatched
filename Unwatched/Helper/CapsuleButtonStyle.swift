//
//  CapsuleButtonStyle.swift
//  Unwatched
//

import SwiftUI

struct CapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(Material.thin)
            .clipShape(Capsule())
            .foregroundColor(.accentColor)

    }
}

#Preview {
    Button(action: {}) {
        Text("Hello")
    }
    .buttonStyle(CapsuleButtonStyle())
}
