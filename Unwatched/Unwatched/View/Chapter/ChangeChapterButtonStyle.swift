//
//  ChangeChapterButtonStyle.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ChangeChapterButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    var chapter: Chapter?
    var size: CGFloat = 40

    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 3) {
            configuration.label
        }
        .fontWeight(.bold)
        .frame(width: size, height: size)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

struct ProgressCircleModifier: ViewModifier {
    var remaining: Double?
    var total: Double?

    var lineWidth: Double
    var color: Color

    func body(content: Content) -> some View {
        content
            .overlay {
                if let remaining = remaining, let total = total {
                    let from = (total - remaining) / total

                    Circle()
                        .trim(from: from, to: 1)
                        .stroke(color, lineWidth: lineWidth)
                        .rotationEffect(Angle(degrees: 270.0))
                        .padding(lineWidth / 2)
                        .animation(.default, value: from)
                }
            }
    }
}

extension View {
    func progressCircleModifier(remaining: Double?,
                                total: Double?,
                                lineWidth: Double = 2,
                                color: Color = Color.foregroundGray
    ) -> some View {
        self.modifier(ProgressCircleModifier(remaining: remaining,
                                             total: total,
                                             lineWidth: lineWidth,
                                             color: color))
    }
}
