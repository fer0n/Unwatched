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

    private var normalSize: Bool {
        dynamicTypeSize <= .large
    }

    private var compactFormat: Bool {
        dynamicTypeSize <= .xxxLarge && videoListFormat == .compact
    }

    private var layout: AnyLayout {
        compactFormat
            ? AnyLayout(HStackLayout(alignment: normalSize ? .center : .top, spacing: 8))
            : AnyLayout(VStackLayout(spacing: 8))
    }

    var body: some View {
        layout {
            VideoListItemThumbnail(
                videoData,
                config: config,
                size: compactFormat ? CGSize(width: 168, height: 94.5) : nil,
                largeThumbnail: !compactFormat
            )
            // stacked: the thumbnail spans the full width, so it needs the trailing inset too
            .padding(compactFormat ? [.vertical, .leading] : .all, 5)
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

            VideoListItemDetails(video: videoData)
                .padding(.horizontal, videoListFormat == .expansive ? 5 : 0)
        }
        .accessibilityElement(children: .combine)
        .modifier(VideoListItemSwipeActionsModifier(
            videoData: videoData,
            config: config,
            onChange: onChange
        ))
        #if os(macOS)
        .rasterized(compactFormat)
        .foregroundStyle(Color.neutralAccentColor)
        .handleVideoListItemTap(videoData)
        #else
        .rasterized(compactFormat)
        .handleVideoListItemTap(videoData)
        #endif
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
        // .tint(.teal)
        .listRowSeparator(.hidden)
        .videoListItemEntry()
        // .listRowBackground(Color.gray)
    }
    .listStyle(.plain)
    .modelContainer(container)
    .environment(NavigationManager())
    .environment(PlayerManager())
    .environment(ImageCacheManager())
    // .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
