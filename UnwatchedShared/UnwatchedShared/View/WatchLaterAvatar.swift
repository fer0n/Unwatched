//
//  WatchLaterAvatar.swift
//  UnwatchedShared
//

import SwiftUI

public struct WatchLaterAvatar: View {
    @AppStorage(Const.themeColor) private var theme = ThemeColor()

    let size: CGFloat

    public init(size: CGFloat) {
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(theme.color.gradient)
            .overlay {
                Image(systemName: "clock")
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(theme.contrastColor)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
