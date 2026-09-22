//
//  ThemedTipViewStyle.swift
//  Unwatched
//

import SwiftUI
import TipKit
import UnwatchedShared

// a popover ignores `.tint`, so the theme color has to be drawn here
struct ThemedTipViewStyle: TipViewStyle {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    let action: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                if let image = configuration.image {
                    image
                        .font(.title)
                        .foregroundStyle(theme.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    configuration.title
                        .font(.headline)
                    configuration.message
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button {
                    configuration.tip.invalidate(reason: .tipClosed)
                } label: {
                    Image(systemName: Const.clearNoFillSF)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            ForEach(configuration.actions) { tipAction in
                Button(action: action) {
                    tipAction.label()
                        .foregroundStyle(theme.contrastColor)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(theme.color)
            }
        }
        .padding(16)
    }
}
