//
//  VideoListItemThumbnailOverlay.swift
//  Unwatched
//

import SwiftUI


public struct VideoListItemThumbnailOverlay: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    let video: Video
    var videoDuration: Double?
    // workaround: doesn't update instantly otherwise

    var color: Color?
    var showDuration = true
    var fixedProgressbarHeight: CGFloat?
    @ScaledMetric var progressbarHeight: CGFloat = 5
    @ScaledMetric var padding: CGFloat = 4
    @ScaledMetric var radius: CGFloat = 6
    
    public init(
        video: Video,
        videoDuration: Double? = nil,
        barHeight: CGFloat? = nil
    ) {
        self.video = video
        self.videoDuration = videoDuration
        self.fixedProgressbarHeight = barHeight
    }

    public var body: some View {
        let elapsed = video.elapsedSeconds
        let total = videoDuration ?? video.duration
        let roughDuration: Double? = {
            if total == nil {
                return HelperService.getDurationFromChapters(video)
            }
            return nil
        }()
        let hasDuration = showDuration
            && (roughDuration != nil || total != nil || video.isYtShort)

        ZStack {
            if let elapsed = elapsed, let total = total {
                let progress = elapsed / total
                // if the time is barely started, show a little bit of progress
                let cleanedProgress = (progress > 0 && progress < 0.1)
                    ? 0.1
                    : progress

                GeometryReader { geo in
                    let progressWidth = geo.size.width * cleanedProgress
                    let cleanedProgressWidth = max(radius * 3, progressWidth)
                    progressBar(cleanedProgressWidth)
                }
            } else if hasDuration {
                progressBar()
            }

            if hasDuration {
                ZStack {
                    if video.isYtShort {
                        Text(verbatim: "#s")
                    } else if let text = total?.formattedSecondsColon {
                        Text(text)
                    } else if let duration = roughDuration?.formattedSecondsColon {
                        formatRoughDuration(duration)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.primary).opacity(0.9)
                .padding(.horizontal, padding)
                .background(.thinMaterial)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: radius,
                        style: .continuous
                    )
                )
                .padding(.bottom, padding + barHeight)
                .padding(.trailing, padding)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .bottomTrailing
                )
            }
        }
    }
    
    var barHeight: CGFloat {
        fixedProgressbarHeight ?? self.progressbarHeight
    }

    func formatRoughDuration(_ duration: String) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Text(duration)
                .foregroundStyle(.primary)
            Image(systemName: "plus")
                .fontWeight(.semibold)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.trailing, -2)
    }

    func progressBar(_ width: Double? = nil) -> some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack(alignment: .bottomLeading) {
                Color.clear.overlay(.thinMaterial)
                HStack(spacing: 0) {
                    (color ?? theme.color)
                        .frame(width: width ?? 0)
                    Color.black
                        .opacity(0.2)
                        .mask(LinearGradient(gradient: Gradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .clear, location: 1)
                            ]
                        ), startPoint: .leading, endPoint: .trailing))
                        .frame(width: 2)
                }
                .frame(height: barHeight - 0.5)
            }
            .frame(height: barHeight)
        }
    }
}