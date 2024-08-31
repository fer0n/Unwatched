//
//  VideoListItemThumbnailOverlay.swift
//  Unwatched
//

import SwiftUI

struct VideoListItemThumbnailOverlay: View {
    @AppStorage(Const.themeColor) var theme: ThemeColor = Color.defaultTheme

    let video: Video
    var videoDuration: Double?
    // workaround: doesn't update instantly otherwise

    var color: Color?
    var showDuration = true
    @ScaledMetric var progressbarHeight: CGFloat = 3

    var body: some View {
        let elapsed = video.elapsedSeconds
        let total = videoDuration ?? video.duration

        ZStack {
            if let elapsed = elapsed, let total = total {
                let progress = elapsed / total
                GeometryReader { geo in
                    let progressWidth = geo.size.width * progress

                    VStack(spacing: 0) {
                        Spacer()
                        Color.black
                            .frame(height: 4)
                            .opacity(0.1)
                            .mask(LinearGradient(gradient: Gradient(
                                stops: [
                                    .init(color: .black, location: 0),
                                    .init(color: .clear, location: 1)
                                ]
                            ), startPoint: .bottom, endPoint: .top))
                        HStack(spacing: 0) {
                            (color ?? theme.color)
                                .frame(width: progressWidth)
                            Color.clear.background(.thinMaterial)
                        }
                        .frame(height: progressbarHeight)
                    }
                }
            }

            if showDuration && (total != nil || video.isYtShort) {
                ZStack {
                    if video.isYtShort {
                        Text(verbatim: "#s")
                    } else if let time = total?.formattedSecondsColon {
                        Text(time)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 3)
                .background(.thinMaterial)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: progressbarHeight,
                        style: .continuous
                    )
                )
                .padding(
                    .bottom,
                    (total == nil || elapsed == nil)
                        ? progressbarHeight
                        : progressbarHeight * 2
                )
                .padding(.trailing, progressbarHeight)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .bottomTrailing
                )
            }
        }
    }
}
