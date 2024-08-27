//
//  VideoListItem.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog

struct VideoListItem: View {
    @Environment(PlayerManager.self) private var player

    let video: Video
    var config: VideoListItemConfig

    init(_ video: Video,
         config: VideoListItemConfig) {
        self.video = video
        self.config = config
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 8) {
                CachedImageView(imageHolder: video) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 168, height: 94.5)
                        .clipped()
                } placeholder: {
                    Color.insetBackgroundColor
                        .frame(width: 168, height: 94.5)
                }
                .overlay {
                    VideoListItemThumbnailOverlay(
                        video: video,
                        videoDuration: config.videoDuration
                    )
                }
                .clipShape(.rect(cornerRadius: 15.0))
                .padding([.vertical, .leading], config.showVideoStatus ? 5 : 0)

                VideoListItemDetails(
                    video: video,
                    showQueueButton: config.showQueueButton
                )
            }
            VideoListItemStatus(
                video: video,
                playingVideoId: player.video?.youtubeId,
                hasInboxEntry: config.hasInboxEntry,
                hasQueueEntry: config.hasQueueEntry,
                watched: config.watched
            )
            .opacity(config.showVideoStatus ? 1 : 0)
        }
        .overlay {
            if config.showQueueButton {
                QueueVideoButton(video)
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

struct VideoListItemThumbnailOverlay: View {
    @AppStorage(Const.themeColor) var theme: ThemeColor = Color.defaultTheme

    let video: Video
    var videoDuration: Double?
    // workaround: doesn't update instantly otherwise

    var color: Color?
    var showDuration = true

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
                        .frame(height: 3)
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
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 3)
                .background(.thinMaterial)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 3,
                        style: .continuous
                    )
                )
                .padding(.bottom, (total == nil || elapsed == nil) ? 4 : 8)
                .padding(.trailing, 4)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .bottomTrailing
                )
            }
        }
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

struct VideoListItemConfig {
    var showVideoStatus: Bool = false
    var hasInboxEntry: Bool?
    var hasQueueEntry: Bool?
    var videoDuration: Double?
    var watched: Bool?
    var clearRole: ButtonRole?
    var queueRole: ButtonRole?
    var onChange: (() -> Void)?
    var clearAboveBelowList: ClearList?
    var videoSwipeActions: [VideoActions] = [.queueTop, .queueBottom, .clear, .more, .details]
    var showQueueButton: Bool = false
    var showContextMenu: Bool = true
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
}
