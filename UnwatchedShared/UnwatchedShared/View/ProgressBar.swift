//
//  ProgressBar.swift
//  UnwatchedShared
//

import SwiftUI

struct ProgressBar: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    let color: Color?
    let width: Double?
    let barHeight: CGFloat

    init(_ color: Color?, _ width: Double?, _ height: CGFloat) {
        self.color = color
        self.width = width
        self.barHeight = height
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack(alignment: .bottomLeading) {
                Color.clear.overlay(.thinMaterial)
                HStack(spacing: 0) {
                    (color ?? theme.color)
                        .frame(width: width ?? 0)
                    Color.black
                        .opacity(0.2)
                        .mask(LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .black, location: 0),
                                .init(color: .clear, location: 1)
                            ]),
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: 2)
                }
                .frame(height: barHeight - 0.5)
            }
            .frame(height: barHeight)
        }
    }
}
