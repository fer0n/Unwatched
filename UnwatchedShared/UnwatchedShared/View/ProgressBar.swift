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
    /// How much of the bar an in-flight download has filled, drawn neutrally underneath the playback progress.
    let downloadWidth: Double?

    init(_ color: Color?, _ width: Double?, _ height: CGFloat, downloadWidth: Double? = nil) {
        self.color = color
        self.width = width
        self.barHeight = height
        self.downloadWidth = downloadWidth
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack(alignment: .bottomLeading) {
                #if os(visionOS)
                Color.primary.opacity(0.6)
                #else
                Color.clear.overlay(.thinMaterial)
                #endif
                downloadOverlay
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

    /// The stable container is what lets the fill fade out once the download is done, instead of being cut at
    /// whatever width it last had.
    var downloadOverlay: some View {
        ZStack(alignment: .leading) {
            if let downloadWidth {
                DownloadShimmer()
                    .mask(alignment: .leading) {
                        Color.black.frame(width: downloadWidth)
                    }
                    .transition(.opacity)
            }
        }
        .frame(height: barHeight)
        .animation(.easeOut(duration: 0.4), value: downloadWidth)
    }
}


/// A neutral fill with a highlight travelling across it.
private struct DownloadShimmer: View {
    @State private var travelled = false

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let highlight = max(width * 0.3, 30)
            Color.primary.opacity(0.3)
                .overlay(alignment: .leading) {
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Color.primary.opacity(0.35), location: 0.5),
                            .init(color: .clear, location: 1)
                        ]),
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: highlight)
                    .offset(x: travelled ? width : -highlight)
                }
                .clipped()
                .onAppear {
                    withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                        travelled = true
                    }
                }
        }
    }
}
