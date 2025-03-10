//
//  DeferDateButtonStyle.swift
//  Unwatched
//

import SwiftUI

struct DeferDateButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    var isHighlighted: Bool = false
    var color: Color
    var contrastColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(10)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHighlighted ? color : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(color, lineWidth: 1)
                    )
            )
            .foregroundStyle(isHighlighted ? contrastColor : color)
            .opacity(isEnabled ? 1 : 0.5)
    }
}
