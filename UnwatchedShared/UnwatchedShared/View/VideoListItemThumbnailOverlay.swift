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
    @ScaledMetric var padding: CGFloat = 3
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
            if video.isPodcast {
                downloadIndicator
            }
        }
    }

    // MARK: - Progress Bar Overlay

    @ViewBuilder
    var progressOverlay: some View {
        let progress = cleanedProgress
        let download = downloadProgress
        if progress != nil || download != nil {
            GeometryReader { geo in
                ProgressBar(
                    color,
                    progress.map { max(radius * 3, geo.size.width * $0) },
                    barHeight,
                    downloadWidth: download.map { geo.size.width * $0 }
                )
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
            .padding(.bottom, padding + barHeight + 1)
            .padding(.trailing, padding + 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }

    @ViewBuilder
    var downloadIndicator: some View {
        PodcastDownloadIndicator(video: video, radius: radius, padding: padding)
            .padding(.bottom, padding + barHeight + 1)
            .padding(.leading, padding + 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
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
        showDuration && (
            roughDuration != nil
            || (videoDuration ?? video.duration) != nil
            || video.isYtShort == true
            || video.noDuration == true
        )
    }

    /// Only read for an episode that isn't downloaded yet, so a list of watched ones doesn't observe the manager.
    private var downloadProgress: Double? {
        guard video.isPodcast, video.downloadedDate == nil else { return nil }
        return PodcastDownloadManager.shared.downloadProgress[video.youtubeId]
    }

    private var cleanedProgress: Double? {
        guard let elapsed = video.elapsedSeconds, let total = videoDuration ?? video.duration else { return nil }
        // a zero duration (livestream, unfetched) would make this infinite and hand a NaN width to
        // the progress bar's layout
        guard total > 0 else { return nil }
        let progress = elapsed / total
        guard progress.isFinite else { return nil }
        return (progress > 0 && progress < 0.1) ? 0.1 : progress
    }
}
