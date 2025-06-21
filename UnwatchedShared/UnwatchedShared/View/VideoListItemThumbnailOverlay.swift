//
//  VideoListItemThumbnailOverlay.swift
//  Unwatched
//

import SwiftUI
import SwiftData

public protocol VideoData {
    var title: String { get }
    var elapsedSeconds: Double? { get }
    var duration: Double? { get }
    var isYtShort: Bool? { get }
    var thumbnailUrl: URL? { get }
    var youtubeId: String { get }
    var publishedDate: Date? { get }
    var queueEntryData: QueueEntryData? { get }
    var bookmarkedDate: Date? { get }
    var watchedDate: Date? { get }
    var deferDate: Date? { get }
    var isNew: Bool { get }
    var url: URL? { get }
    var persistentId: PersistentIdentifier? { get }

    var sortedChapterData: [ChapterData] { get }
    var subscriptionData: (any SubscriptionData)? { get }
    var hasInboxEntry: Bool? { get }
}

public protocol ChapterData {
    var startTime: Double { get }
    var endTime: Double? { get }
    var isActive: Bool { get }
}

public struct VideoListItemThumbnailOverlay: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

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
        let barHeight = fixedProgressbarHeight ?? progressbarHeight

        ZStack {
            progressOverlay(barHeight: barHeight)
            durationOverlay(barHeight: barHeight)
        }
    }

    // MARK: - Progress Bar Overlay

    @ViewBuilder
    private func progressOverlay(barHeight: CGFloat) -> some View {
        if let progress = cleanedProgress {
            GeometryReader { geo in
                let progressWidth = max(radius * 3, geo.size.width * progress)
                progressBar(progressWidth, barHeight: barHeight)
            }
        } else if hasDuration {
            progressBar(nil, barHeight: barHeight)
        }
    }

    // MARK: - Duration Text Overlay

    @ViewBuilder
    private func durationOverlay(barHeight: CGFloat) -> some View {
        if hasDuration {
            ZStack {
                if video.isYtShort == true {
                    Text("#s")
                } else if let text = totalText {
                    Text(text)
                } else if let rough = roughText {
                    formatRoughDuration(rough)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.primary.opacity(0.9))
            .padding(.horizontal, padding)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .padding(.bottom, padding + barHeight)
            .padding(.trailing, padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }

    // MARK: - Progress Bar View

    private func progressBar(_ width: Double?, barHeight: CGFloat) -> some View {
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

    // MARK: - Helpers

    private var cleanedProgress: Double? {
        guard let elapsed = video.elapsedSeconds, let total = videoDuration ?? video.duration else { return nil }
        let progress = elapsed / total
        return (progress > 0 && progress < 0.1) ? 0.1 : progress
    }

    private var hasDuration: Bool {
        showDuration && (roughDuration != nil || (videoDuration ?? video.duration) != nil || video.isYtShort == true)
    }

    private var roughDuration: Double? {
        if videoDuration ?? video.duration == nil {
            return HelperService.getDurationFromChapters(video)
        }
        return nil
    }

    private var totalText: String? {
        (videoDuration ?? video.duration)?.formattedSecondsColon
    }

    private var roughText: String? {
        roughDuration?.formattedSecondsColon
    }

    private func formatRoughDuration(_ duration: String) -> some View {
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
}
