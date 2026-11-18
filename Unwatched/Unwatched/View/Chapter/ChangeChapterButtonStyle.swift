//
//  ChangeChapterButtonStyle.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ChangeChapterButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
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
