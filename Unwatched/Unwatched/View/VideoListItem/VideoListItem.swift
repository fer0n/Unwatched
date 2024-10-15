//
//  VideoListItem.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

struct VideoListItem: View {
    @AppStorage(Const.videoListFormat) var videoListFormat: VideoListFormat = .compact

    @Environment(PlayerManager.self) private var player
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    @ScaledMetric var queueButtonSize = 30

    let video: Video
    let config: VideoListItemConfig

    init(_ video: Video,
         config: VideoListItemConfig) {
        self.video = video
        self.config = config
    }

    var body: some View {
        let normalSize = dynamicTypeSize <= .large
        let compactFormat = dynamicTypeSize <= .xxxLarge && videoListFormat == .compact
        let layout = compactFormat
            ? AnyLayout(HStackLayout(alignment: normalSize ? .center : .top, spacing: 8))
            : AnyLayout(VStackLayout(spacing: 8))

        layout {
            VideoListItemThumbnail(
                video,
                config: config,
                size: compactFormat ? CGSize(width: 168, height: 94.5) : nil
            )
            .padding([.vertical, .leading], config.showVideoStatus ? 5 : 0)
            .overlay(alignment: .topLeading) {
                VideoListItemStatus(
                    video: video,
                    playingVideoId: player.video?.youtubeId,
                    hasInboxEntry: config.hasInboxEntry,
                    hasQueueEntry: config.hasQueueEntry,
                    watched: config.watched
                )
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .opacity(config.showVideoStatus ? 1 : 0)
            }

            VideoListItemDetails(
                video: video,
                queueButtonSize: config.showQueueButton ? queueButtonSize : nil,
                showVideoListOrder: config.showVideoListOrder
            )
        }
        .overlay {
            if config.showQueueButton {
                QueueVideoButton(video, size: queueButtonSize)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .padding([.vertical, .leading], config.showVideoStatus ? -5 : 0)
        .handleVideoListItemTap(video)
        .modifier(VideoListItemSwipeActionsModifier(
                    video: video,
                    config: config))
    }
}

#Preview {
    let container = DataController.previewContainerFilled
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
            config: VideoListItemConfig(
                showVideoStatus: true,
                hasInboxEntry: false,
                hasQueueEntry: true,
                watched: true,
                showQueueButton: true
            )
        )
    }
    .listStyle(.plain)
    .modelContainer(container)
    .environment(NavigationManager())
    .environment(PlayerManager())
    .environment(ImageCacheManager())
    // .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
