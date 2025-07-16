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
    @ScaledMetric var queueButtonSize = 30

    let videoData: any VideoData
    let youtubeId: String
    let config: VideoListItemConfig
    let onChange: ((_ reason: ChangeReason?) -> Void)?

    init(
        _ videoData: any VideoData,
        _ youtubeId: String,
        config: VideoListItemConfig,
        onChange: ((_ reason: ChangeReason?) -> Void)? = nil
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
        ZStack(alignment: .bottomTrailing) {
            layout {
                VideoListItemThumbnail(
                    videoData,
                    config: config,
                    size: compactFormat ? CGSize(width: 168, height: 94.5) : nil
                )
                .padding([.vertical, .leading], 5)
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
                    queueButtonSize: config.showQueueButton ? queueButtonSize : nil,
                    )
                .padding(.horizontal, videoListFormat == .expansive ? 5 : 0)
            }

            if config.showQueueButton {
                QueueVideoButton(videoData, size: queueButtonSize)
                    .foregroundStyle(.secondary)
            }
        }
        .padding([.vertical, .leading], -5)
        .padding(.horizontal, videoListFormat == .expansive ? -5 : 0)
        .accessibilityElement(children: .combine)
        .handleVideoListItemTap(videoData)
        .modifier(VideoListItemSwipeActionsModifier(
            videoData: videoData,
            config: config,
            onChange: onChange
        ))
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
    video.duration = 130
    video.elapsedSeconds = 0.1
    video.isYtShort = false

    return List {
        VideoListItem(
            video,
            video.youtubeId,
            config: VideoListItemConfig(
                hasInboxEntry: false,
                hasQueueEntry: true,
                watched: true,
                isNew: true,
                showQueueButton: true
            )
        )
        .equatable()
        .tint(.teal)
        .listRowSeparator(.hidden)
    }
    .listStyle(.plain)
    .modelContainer(container)
    .environment(NavigationManager())
    .environment(PlayerManager())
    .environment(ImageCacheManager())
    // .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
