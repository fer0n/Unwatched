//
//  VideoListItemThumbnailOverlay.swift
//  Unwatched
//

import SwiftUI
import SwiftData

public struct VideoListItemThumbnailOverlay: View {

    let video: VideoData
    var videoDuration: Double?
    // workaround: doesn't update instantly otherwise

    var color: Color?
    var showDuration = true
    var fixedProgressbarHeight: CGFloat?

    @ScaledMetric var progressbarHeight: CGFloat = 5
    @ScaledMetric var padding: CGFloat = 4
    @ScaledMetric var radius: CGFloat = 6

    public init(
        video: VideoData,
        videoDuration: Double? = nil,
        barHeight: CGFloat? = nil
    ) {
        self.video = video
        self.videoDuration = videoDuration
        self.fixedProgressbarHeight = barHeight
    }

    public var body: some View {
        ZStack {
            progressOverlay
            listItemDuration
        }
    }

    // MARK: - Progress Bar Overlay

    @ViewBuilder
    var progressOverlay: some View {
        if let progress = cleanedProgress {
            GeometryReader { geo in
                let progressWidth = max(radius * 3, geo.size.width * progress)
                ProgressBar(color, progressWidth, barHeight)
            }
        } else if hasDuration {
            ProgressBar(color, nil, barHeight)
        }
    }

    @ViewBuilder
    var listItemDuration: some View {
        if hasDuration {
            VideoListItemDurationOverlay(
                video: video,
                videoDuration: videoDuration,
                roughDuration: roughDuration,
                radius: radius,
                padding: padding
            )
            .padding(.bottom, padding + barHeight)
            .padding(.trailing, padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }

    // MARK: - Helpers

    var barHeight: CGFloat {
        fixedProgressbarHeight ?? progressbarHeight
    }

    private var roughDuration: Double? {
        if videoDuration ?? video.duration == nil {
            return HelperService.getDurationFromChapters(video)
        }
        return nil
    }

    private var hasDuration: Bool {
        showDuration && (roughDuration != nil || (videoDuration ?? video.duration) != nil || video.isYtShort == true)
    }

    private var cleanedProgress: Double? {
        guard let elapsed = video.elapsedSeconds, let total = videoDuration ?? video.duration else { return nil }
        let progress = elapsed / total
        return (progress > 0 && progress < 0.1) ? 0.1 : progress
    }
}
