//
//  VideoListItem.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog

struct VideoListItem: View {
    @AppStorage(Const.hideMenuOnPlay) var hideMenuOnPlay: Bool = true
    @AppStorage(Const.goToQueueOnPlay) var goToQueueOnPlay: Bool = false

    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager
    @Environment(PlayerManager.self) private var player

    @State var showInfo = false

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
                    Color.backgroundColor
                        .frame(width: 168, height: 94.5)
                }
                .clipShape(.rect(cornerRadius: 15.0))
                .padding([.vertical, .leading], config.showVideoStatus ? 5 : 0)

                VideoListItemDetails(video: video, videoDuration: config.videoDuration)
            }
            if config.showVideoStatus {
                VideoListItemStatus(
                    video: video,
                    playingVideoId: player.video?.youtubeId,
                    hasInboxEntry: config.hasInboxEntry,
                    hasQueueEntry: config.hasQueueEntry,
                    watched: config.watched
                )
            }
        }
        .padding([.vertical, .leading], config.showVideoStatus ? -5 : 0)
        .contentShape(Rectangle())
        .onTapGesture {
            player.playVideo(video)
            _ = VideoService.insertQueueEntries(videos: [video], modelContext: modelContext)
            if hideMenuOnPlay {
                withAnimation {
                    navManager.showMenu = false
                }
            }

            if goToQueueOnPlay {
                navManager.navigateToQueue()
            }
        }
        .modifier(VideoListItemSwipeActionsModifier(
                    showInfo: $showInfo,
                    video: video,
                    config: config))
        .sheet(isPresented: $showInfo) {
            NavigationStack {
                ScrollView {
                    DescriptionDetailView(video: video)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            showInfo = false
                        } label: {
                            Image(systemName: Const.clearSF)
                        }
                    }
                }
            }
            .presentationDragIndicator(.visible)
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
}

#Preview {
    let container = DataController.previewContainer
    let context = ModelContext(container)
    let fetch = FetchDescriptor<Video>()
    let videos = try? context.fetch(fetch)
    guard let video = videos?.first else {
        return Text("noVideoFound")
    }

    return List {
        VideoListItem(
            video,
            config: VideoListItemConfig(
                showVideoStatus: true,
                hasInboxEntry: false,
                hasQueueEntry: true,
                watched: true
            )
        )
    }
    .listStyle(.plain)
    .modelContainer(container)
    .environment(NavigationManager())
    .environment(PlayerManager())
    .environment(ImageCacheManager())
}
