//
//  ImageAccentBackground.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ImageAccentBackground: ViewModifier {
    @Environment(ImageCacheManager.self) var imageCacheManager
    @AppStorage(Const.themeColor) var theme = ThemeColor()
    @State var imageColor: Color?

    var url: URL?
    var useThemeColor = false
    let topPadding: CGFloat = 200
    let gradientStart: CGFloat = 70

    var color: Color? {
        useThemeColor ? theme.color.opacity(0.35) : imageColor
    }

    func body(content: Content) -> some View {
        content
            #if os(iOS)
            .padding(.top, gradientStart)
            #endif
            .background(
                LinearGradient(
                    colors: [color ?? Color.automaticWhite, Const.macOS26 || Device.isVision
                                ? Color.clear
                                : Color.backgroundColor ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                #if os(macOS)
                .padding(.horizontal, -15)
                #endif
            )
            #if os(iOS)
            .padding(.top, topPadding - gradientStart)
            .listRowInsets(EdgeInsets(top: -topPadding, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            #endif
            .task(id: url) {
                if !useThemeColor {
                    await updateColor()
                }
            }
            .background {
                (Const.macOS26 || Device.isVision
                    ? Color.clear
                    : color)
                    .mask(LinearGradient(gradient: Gradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.15)
                        ]
                    ), startPoint: .top, endPoint: .bottom))
            }
            #if os(macOS)
            .clipShape(RoundedRectangle(cornerRadius: Const.macOS26 ? 25 : 0))
        #endif
    }

    func updateColor() async {
        guard let url else { return }
        let task = await ImageService.getAccentColor(from: url, imageCacheManager)
        if let info = await task.value {
            imageColor = info.color
            imageCacheManager[url.absoluteString] = info
        }
    }
}

extension View {
    func imageAccentBackground(url: URL?, useThemeColor: Bool = false) -> some View {
        self.modifier(ImageAccentBackground(url: url, useThemeColor: useThemeColor))
    }
}
