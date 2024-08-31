//
//  VideoListItem.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog

struct VideoListItem: View {
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
        let largeSize = dynamicTypeSize <= .xxxLarge
        let layout = largeSize
            ? AnyLayout(HStackLayout(alignment: normalSize ? .center : .top, spacing: 8))
            : AnyLayout(VStackLayout(spacing: 8))

        layout {
            VideoListItemThumbnail(
                video,
                config: config,
                size: largeSize ? CGSize(width: 168, height: 94.5) : nil
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
                queueButtonSize: config.showQueueButton ? queueButtonSize : nil
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

enum VideoActions {
    case queueTop
    case queueBottom
    case delete
    case clear
    case more
    case details
}

#Preview {
    let container = DataController.previewContainer
    let context = ModelContext(container)
    let fetch = FetchDescriptor<Video>()
    let videos = try? context.fetch(fetch)
    guard let video = videos?.first else {
        return Text("noVideoFound")
    }
    video.duration = 130
    video.elapsedSeconds = 20
    // video.isYtShort = true

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
    .environment(\.sizeCategory, .extraExtraExtraLarge)
}
