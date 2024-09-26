//
//  UnwatchedMiniature.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct UnwatchedMiniature: View {
    @Environment(\.colorScheme) var currentColorScheme

    @AppStorage(Const.themeColor) var theme = ThemeColor()
    static let aspectRatio: Double = 16/9

    var fullWidth: Double
    var fullHeight: Double

    var width: Double
    var height: Double

    var selected = true
    var colorSchemePlayer: ColorScheme
    var colorScheme: ColorScheme

    init(
        _ appearance: AppAppearance,
        width: Double,
        selected: Bool = true
    ) {
        colorScheme = appearance.colorScheme
        colorSchemePlayer = appearance.playerColorScheme

        let padding = width * 0.2

        fullHeight = width * UnwatchedMiniature.aspectRatio
        fullWidth = width
        self.width = fullWidth - padding
        self.height = fullHeight - padding

        self.selected = selected
    }

    var body: some View {
        ZStack {
            borderColor
                .frame(width: fullWidth, height: fullHeight)
                .environment(\.colorScheme, currentColorScheme)
            miniature
        }
        .environment(\.colorScheme, colorScheme)
        .clipShape(RoundedRectangle(cornerRadius: (fullWidth - width) / 2 + (height * 0.125)))

    }

    var miniature: some View {
        VStack(spacing: 0) {
            player
                .environment(\.colorScheme, colorSchemePlayer)
            dropShadow
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: height * 0.05)
                .frame(height: 0)
            ZStack {
                Color.sheetBackground
                VStack(spacing: height * 0.05) {
                    dragHandle
                    listItem
                    listItem
                    listItem
                    Spacer()
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: height * 0.125, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: height * 0.125)
                .stroke(.black, lineWidth: width * 0.045)
        )
    }

    var player: some View {
        ZStack {
            Color.playerBackgroundColor
                .frame(height: height * 0.4)
            play
                .padding(.top, height * 0.075)
        }
    }

    var borderColor: Color {
        selected
            ? theme.color
            : Color.gray.opacity(0.4)
    }

    var play: some View {
        Image(systemName: "play.circle.fill")
            .font(.system(size: width * 0.27))
            .fontWeight(.black)
            .foregroundStyle(.automaticBlack)
    }

    var dropShadow: some View {
        Color.black
            .frame(height: height * 0.03)
            .opacity(0.2)
            .mask(LinearGradient(gradient: Gradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .clear, location: 1)
                ]
            ), startPoint: .bottom, endPoint: .top))
    }

    var dragHandle: some View {
        Color.gray
            .clipShape(Capsule())
            .frame(width: width * 0.18, height: height * 0.015)
            .padding(.top, height * 0.015)
    }

    var thumbnail: some View {
        RoundedRectangle(cornerRadius: width * 0.07)
            .fill(Color.gray)
            .frame(width: width * 0.36, height: height * 0.125)
    }

    var listItem: some View {
        HStack {
            thumbnail
            VStack(alignment: .leading, spacing: height * 0.015) {
                RoundedRectangle(cornerRadius: width * 0.09)
                    .fill(Color.gray)
                    .opacity(0.5)
                    .frame(width: width * 0.41, height: height * 0.025)
                RoundedRectangle(cornerRadius: width * 0.09)
                    .fill(Color.gray)
                    .opacity(0.5)
                    .frame(width: width * 0.27, height: height * 0.025)
                RoundedRectangle(cornerRadius: width * 0.09)
                    .fill(Color.gray)
                    .opacity(0.3)
                    .frame(width: width * 0.14, height: height * 0.025)
            }
        }
    }
}
