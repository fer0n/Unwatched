//
//  VideoListItem.swift
//  Unwatched
//

import SwiftUI

enum VideoActions {
    case queue
    case delete
    case clear
    case watched
}

struct VideoListItem: View {
    @Environment(NavigationManager.self) private var navManager
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) private var player

    let video: Video
    var showVideoStatus: Bool = false
    var hasInboxEntry: Bool?
    var hasQueueEntry: Bool?
    var watched: Bool?
    // TODO: see if there's a better way to fix the "label doesn't update from bg tasks" issue
    // try to reproduce in mini project and ask on stackoverflow?

    var videoSwipeActions: [VideoActions]
    var onTapGuesture: (() -> Void)?
    var onClear: (() -> Void)?
    // TODO: in case the entry is present twice (probably better to avoid that in another way)

    init(video: Video,
         videoSwipeActions: [VideoActions] = [.queue],
         onTapGuesture: (() -> Void)? = nil,
         onClear: (() -> Void)? = nil) {
        self.video = video
        self.videoSwipeActions = videoSwipeActions
        self.onTapGuesture = onTapGuesture
        self.onClear = onClear
    }

    init(video: Video,
         showVideoStatus: Bool,
         hasInboxEntry: Bool,
         hasQueueEntry: Bool,
         watched: Bool,
         videoSwipeActions: [VideoActions] = [.queue],
         onTapGuesture: (() -> Void)? = nil,
         onClear: (() -> Void)? = nil) {
        self.video = video
        self.showVideoStatus = showVideoStatus
        self.hasInboxEntry = hasInboxEntry
        self.hasQueueEntry = hasQueueEntry
        self.watched = watched
        self.videoSwipeActions = videoSwipeActions
        self.onTapGuesture = onTapGuesture
        self.onClear = onClear
    }

    var body: some View {
        videoItem
            .contentShape(Rectangle())
            .onTapGesture {
                if let tap = onTapGuesture {
                    tap()
                } else {
                    player.video = video
                    withAnimation {
                        navManager.showMenu = false
                    }
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
                CacheAsyncImage(url: video.thumbnailUrl) { image in
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
            if videoSwipeActions.contains(.queue) {
                Button(action: addVideoToQueue) {
                    Image(systemName: Const.addToQueuSF)
                }
                .tint(.teal)
            }
            if videoSwipeActions.contains(.watched) {
                Button(action: markVideoWatched) {
                    Image(systemName: Const.watchedSF)
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
                    .foregroundStyle(Color.gray)
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
            return ("circle.circle.fill", .teal)
        }
        if hasQueueEntry == true {
            return ("arrow.uturn.right.circle.fill", defaultColor)
        }
        if watched == true {
            return (Const.watchedSF, .mint)
        }
        return nil
    }

    func addVideoToQueue() {
        print("addVideoToQueue")
        VideoService.insertQueueEntries(
            at: 0,
            videos: [video],
            modelContext: modelContext
        )
    }

    func markVideoWatched() {
        if let video = player.video {
            VideoService.markVideoWatched(
                video,
                modelContext: modelContext
            )
        }
    }

    func clearVideoEverywhere() {
        onClear?()
        VideoService.clearFromEverywhere(
            video,
            modelContext: modelContext
        )
    }
}

#Preview {
    let video = Video(
        title: "Virtual Reality OasisResident Evil 4 Remake Is 10x BETTER In VR!",
        url: URL(string: "https://www.youtube.com/watch?v=_7vP9vsnYPc")!,
        youtubeId: "_7vP9vsnYPc",
        thumbnailUrl: URL(string: "https://i4.ytimg.com/vi/_7vP9vsnYPc/hqdefault.jpg")!,
        publishedDate: Date(),
        isYtShort: true)

    return VideoListItem(
        video: video,
        showVideoStatus: true,
        hasInboxEntry: false,
        hasQueueEntry: true,
        watched: true
    )
    .modelContainer(DataController.previewContainer)
    .environment(NavigationManager())
}
