//
//  RotateOrientationButton.swift
//  Unwatched
//

import SwiftUI

struct RotateOrientationButton: View {
    var body: some View {
        Button {
            OrientationManager.changeOrientation(to: .landscapeRight)
        } label: {
            Image(systemName: "rotate.right")
                .offset(x: 1, y: -1)
        }
        .outlineToggleModifier(isOn: false, isSmall: true)
    }
}
