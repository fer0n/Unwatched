//
//  ChangeChapterButtonStyle.swift
//  Unwatched
//

import SwiftUI

struct ChangeChapterButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    var chapter: Chapter?
    var remainingTime: Double?

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            ProgressCircle(remaining: remainingTime, total: chapter?.duration)
            configuration.label
        }
        .opacity(isEnabled ? 1 : 0.5)
        .frame(width: 40, height: 40)
    }
}

struct ProgressCircle: View {
    var remaining: Double?
    var total: Double?

    let lineWidth: Double = 2

    var body: some View {
        ZStack {
            Circle()
                .foregroundStyle(Color.foregroundGray)
                .opacity(0.3)

            if let remaining = remaining, let total = total {
                let from = (total - remaining) / total

                Circle()
                    .trim(from: from, to: 1)
                    .stroke(Color.foregroundGray, lineWidth: lineWidth)
                    .rotationEffect(Angle(degrees: 270.0))
                    .padding(lineWidth / 2)
                    .animation(.default, value: from)
            }
        }
    }
}
