//
//  ImageAccentBackground.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ImageAccentBackground: ViewModifier {
    @Environment(ImageCacheManager.self) var imageCacheManager
    @State var color: Color?

    var url: URL?
    let topPadding: CGFloat = 200
    let gradientStart: CGFloat = 55

    func body(content: Content) -> some View {
        content
            .padding(.top, gradientStart)
            .background(
                LinearGradient(
                    colors: [color ?? Color.automaticWhite, Color.backgroundColor],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .padding(.top, topPadding - gradientStart)
            .listRowInsets(EdgeInsets(top: -topPadding, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .task {
                guard let url, color == nil else { return }
                let task = await ImageService.getAccentColor(from: url, imageCacheManager)
                if let info = await task.value {
                    color = info.color
                    imageCacheManager[url.absoluteString] = info
                }
            }
            .background {
                color
                    .mask(LinearGradient(gradient: Gradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.15)
                        ]
                    ), startPoint: .top, endPoint: .bottom))
            }
    }
}

extension View {
    func imageAccentBackground(url: URL?) -> some View {
        self.modifier(ImageAccentBackground(url: url))
    }
}
