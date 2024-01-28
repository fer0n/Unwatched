//
//  VideoListItem.swift
//  Unwatched
//

import SwiftUI
import SwiftData

enum VideoActions {
    case queueTop
    case queueBottom
    case delete
    case clear
}

struct VideoListItem: View {
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager
    @Environment(PlayerManager.self) private var player

    let video: Video
    var showVideoStatus: Bool = false
    var hasInboxEntry: Bool?
    var hasQueueEntry: Bool?
    var watched: Bool?
    // TODO: see if there's a better way to fix the "label doesn't update from bg tasks" issue
    // try to reproduce in mini project and ask on stackoverflow?

    var videoSwipeActions: [VideoActions]
    var onClear: (() -> Void)?
    // TODO: in case the entry is present twice (probably better to avoid that in another way)

    init(video: Video,
         videoSwipeActions: [VideoActions] = [.queueTop],
         onClear: (() -> Void)? = nil) {
        self.video = video
        self.videoSwipeActions = videoSwipeActions
        self.onClear = onClear
    }

    init(video: Video,
         showVideoStatus: Bool,
         hasInboxEntry: Bool,
         hasQueueEntry: Bool,
         watched: Bool,
         videoSwipeActions: [VideoActions] = [.queueTop],
         onClear: (() -> Void)? = nil) {
        self.video = video
        self.showVideoStatus = showVideoStatus
        self.hasInboxEntry = hasInboxEntry
        self.hasQueueEntry = hasQueueEntry
        self.watched = watched
        self.videoSwipeActions = videoSwipeActions
        self.onClear = onClear
    }

    var body: some View {
        videoItem
            .contentShape(Rectangle())
            .onTapGesture {
                player.playVideo(video)
                VideoService.insertQueueEntries(videos: [video], modelContext: modelContext)
                withAnimation {
                    navManager.showMenu = false
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                getLeadingSwipeActions()
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                getTrailingSwipeActions()
            }
    }

    var videoItem: some View {
        ZStack(alignment: .topLeading) {
            HStack {
                CachedImageView(video: video) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 160, height: 90)
                        .clipped()
                } placeholder: {
                    Color.backgroundColor
                        .frame(width: 160, height: 90)
                }
                .clipShape(RoundedRectangle(cornerRadius: 15.0))
                .padding(showVideoStatus ? 5 : 0)

                videoItemDetails
            }
            if showVideoStatus,
               let statusInfo = videoStatusSystemName,
               let status = statusInfo.status {
                Image(systemName: status)
                    .resizable()
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, statusInfo.color)
                    .frame(width: 23, height: 23)
            }
        }
    }

    func getLeadingSwipeActions() -> some View {
        Group {
            if videoSwipeActions.contains(.queueTop) {
                Button(action: addVideoToTopQueue) {
                    Image(systemName: "text.insert")
                }
                .tint(.teal)
            }
            if videoSwipeActions.contains(.queueBottom) {
                Button(action: addVideoToBottomQueue) {
                    Image(systemName: "text.append")
                }
                .tint(.mint)
            }
        }
    }

    func getTrailingSwipeActions() -> some View {
        return Group {
            if videoSwipeActions.contains(.clear) &&
                (hasInboxEntry == true || hasQueueEntry == true || [Tab.queue, Tab.inbox].contains(navManager.tab)) {
                Button(action: clearVideoEverywhere) {
                    Image(systemName: Const.clearSF)
                }
                .tint(Color.backgroundColor)
            }
        }
    }

    var videoItemDetails: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(video.title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 15, weight: .medium))
                .lineLimit(2)
            HStack {
                if let published = video.publishedDate {
                    Text(published.formatted)
                        .font(.system(size: 14, weight: .light))
                        .font(.body)
                        .foregroundStyle(Color.gray)
                }
                if video.isYtShort || video.isLikelyYtShort {
                    Text("#s\(video.isYtShort == true ? "." : "")")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.gray)
                }
            }
            if let title = video.subscription?.title {
                Text(title)
                    .font(.system(size: 14, weight: .regular))
                    .lineLimit(1)
                    .textCase(.uppercase)
                    .foregroundStyle(.gray)
                    .onTapGesture {
                        if let sub = video.subscription {
                            navManager.pushSubscription(sub)
                        }
                    }

            }
            if let duration = video.duration,
               let remaining = video.remainingTime,
               duration > 0 && remaining > 0 {
                HStack(alignment: .center) {
                    ProgressView(value: video.elapsedSeconds, total: duration)
                        .tint(.teal)
                        .opacity(0.6)
                        .padding(.top, 3)
                        .padding(.trailing, 5)
                    if video.hasFinished != true {
                        Text(remaining.formattedSeconds ?? "")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color.gray)
                    }
                }
            }
        }
    }

    var videoStatusSystemName: (status: String?, color: Color)? {
        let defaultColor = Color.green
        if video.youtubeId == player.video?.youtubeId {
            return ("play.circle.fill", defaultColor)
        }
        if hasInboxEntry == true {
            return ("circle.circle.fill", .mint)
        }
        if hasQueueEntry == true {
            return ("arrow.uturn.right.circle.fill", defaultColor)
        }
        if watched == true {
            return (Const.watchedSF, defaultColor)
        }
        return nil
    }

    func addVideoToTopQueue() {
        print("addVideoTop")
        _ = VideoService.insertQueueEntries(
            at: 1,
            videos: [video],
            modelContext: modelContext
        )
    }

    func addVideoToBottomQueue() {
        print("addVideoBottom")
        VideoService.addToBottomQueue(video: video, modelContext: modelContext)
    }

    func clearVideoEverywhere() {
        onClear?()
        let isFirstQueueEntry = video.queueEntry?.order == 0
        let task = VideoService.clearFromEverywhere(
            video,
            modelContext: modelContext
        )
        if isFirstQueueEntry {
            player.loadTopmostVideoFromQueue(after: task)
        }
    }
}

#Preview {
    let container = DataController.previewContainer
    let context = ModelContext(container)
    let fetch = FetchDescriptor<Video>()
    let videos = try? context.fetch(fetch)
    guard let video = videos?.first else {
        return Text("no video found")
    }

    return VideoListItem(
        video: video,
        showVideoStatus: true,
        hasInboxEntry: false,
        hasQueueEntry: true,
        watched: true
    )
    .modelContainer(container)
    .environment(NavigationManager())
    .environment(PlayerManager())
    .environment(ImageCacheManager())
}
