//
//  VideoListItem.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

struct VideoListItem: View, Equatable {
    nonisolated static func == (lhs: VideoListItem, rhs: VideoListItem) -> Bool {
        lhs.config == rhs.config &&
            lhs.youtubeId == rhs.youtubeId
    }

    @AppStorage(Const.videoListFormat) var videoListFormat: VideoListFormat = .compact
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    let videoData: any VideoData
    let youtubeId: String
    let config: VideoListItemConfig
    let onChange: ((_ reason: VideoChangeReason?, _ order: Int?) -> Void)?

    init(
        _ videoData: any VideoData,
        _ youtubeId: String,
        config: VideoListItemConfig,
        onChange: ((_ reason: VideoChangeReason?, _ order: Int?) -> Void)? = nil
    ) {
        self.videoData = videoData
        self.youtubeId = youtubeId
        self.config = config
        self.onChange = onChange
    }

    private var layout: VideoListItemLayout {
        VideoListItemLayout(format: videoListFormat, dynamicTypeSize: dynamicTypeSize)
    }

    var body: some View {
        let layout = layout
        layout.stack {
            VideoListItemThumbnail(
                videoData,
                config: config,
                size: layout.thumbnailSize,
                largeThumbnail: !layout.isCompact
            )
            .padding(layout.thumbnailInsets, 5)
            .overlay(alignment: .topLeading) {
                VideoListItemStatus(
                    showAllStatus: config.showAllStatus,
                    youtubeId: youtubeId,
                    hasInboxEntry: config.hasInboxEntry,
                    hasQueueEntry: config.hasQueueEntry,
                    watched: config.watched,
                    deferred: config.deferred,
                    isNew: config.isNew
                )
                .limitDynamicType()
            }

            VideoListItemDetails(
                video: videoData,
                episodeNumber: config.episodeNumber ?? videoData.episodeNumber
            )
            .padding(.horizontal, layout.detailsInset)
        }
        .accessibilityElement(children: .combine)
        .modifier(VideoListItemSwipeActionsModifier(
            videoData: videoData,
            config: config,
            onChange: onChange
        ))
        #if os(macOS)
        .rasterized(layout.isCompact)
        .foregroundStyle(Color.neutralAccentColor)
        .handleVideoListItemTap(videoData)
        #else
        .rasterized(layout.isCompact)
        .handleVideoListItemTap(videoData)
        #endif
    }
}

private struct VideoListItemLayout {
    let format: VideoListFormat
    let dynamicTypeSize: DynamicTypeSize

    var isCompact: Bool {
        dynamicTypeSize <= .xxxLarge && format == .compact
    }

    var stack: AnyLayout {
        isCompact
            ? AnyLayout(HStackLayout(alignment: dynamicTypeSize <= .large ? .center : .top, spacing: 8))
            : AnyLayout(VStackLayout(spacing: 8))
    }

    var thumbnailSize: CGSize? {
        isCompact ? CGSize(width: 168, height: 94.5) : nil
    }

    var thumbnailInsets: Edge.Set {
        isCompact ? [.vertical, .leading] : .all
    }

    var detailsInset: CGFloat {
        format == .expansive ? 5 : 0
    }
}

struct VideoListItemPlaceholder: View {
    @AppStorage(Const.videoListFormat) private var videoListFormat: VideoListFormat = .compact
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let video = SendableVideo(
        youtubeId: "",
        title: "Placeholder title that is long enough for two lines",
        url: nil,
        feedTitle: "Channel name",
        publishedDate: .now
    )

    var body: some View {
        let layout = VideoListItemLayout(format: videoListFormat, dynamicTypeSize: dynamicTypeSize)
        layout.stack {
            VideoListItemThumbnail(
                Self.video,
                config: VideoListItemConfig(),
                size: layout.thumbnailSize,
                largeThumbnail: !layout.isCompact
            )
            .padding(layout.thumbnailInsets, 5)

            VideoListItemDetails(video: Self.video)
                .redacted(reason: .placeholder)
                .padding(.horizontal, layout.detailsInset)
        }
    }
}

private extension View {
    /// `drawingGroup()` speeds up scrolling, but it rasterizes the row at the size of an early
    /// layout pass. In the stacked layout the row's height follows its width (the thumbnail is a
    /// full-width 16:9 image), which isn't settled yet at that point, so the raster ends up
    /// cutting off the bottom of the row — the published date and the duration overlay. The
    /// compact layout uses a fixed-size thumbnail and isn't affected.
    @ViewBuilder
    func rasterized(_ enabled: Bool) -> some View {
        if enabled {
            drawingGroup()
        } else {
            self
        }
    }
}

extension View {
    func limitDynamicType() -> some View {
        self.dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}

#Preview {
    let container = DataProvider.previewContainerFilled
    let context = ModelContext(container)
    let fetch = FetchDescriptor<Video>()
    let videos = try? context.fetch(fetch)
    guard let video = videos?.first else {
        return Text("noVideoFound")
    }
    video.duration = nil // 130
    video.elapsedSeconds = 0.1
    video.isYtShort = false
    video.noDuration = false

    return List {
        VideoListItem(
            video,
            video.youtubeId,
            config: VideoListItemConfig(
                hasInboxEntry: false,
                hasQueueEntry: true,
                watched: true,
                isNew: true
            )
        )
        .equatable()
        .listRowSeparator(.hidden)
        .videoListItemEntry()
    }
    .listStyle(.plain)
    .modelContainer(container)
    .environment(NavigationManager())
    .environment(PlayerManager())
    .environment(ImageCacheManager())
}
