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

    let video: Video
    var showVideoStatus: Bool = false
    var videoSwipeActions: [VideoActions] = [.queue]
    var onAddToQueue: (() -> Void)?

    func getVideoStatusSystemName(_ video: Video) -> (status: String?, color: Color)? {
        let defaultColor = Color.green
        switch video.status {
        case .inbox: return ("circle.circle.fill", .teal)
        case .playing: return ("play.circle.fill", defaultColor)
        case .queued: return ("arrow.uturn.right.circle.fill", defaultColor)
        case .none:
            if video.watched { return ("checkmark.circle.fill", defaultColor) }
        }
        return nil
    }

    func addVideoToQueue() {
        onAddToQueue?()
        VideoService.insertQueueEntries(
            at: 0,
            videos: [video],
            modelContext: modelContext
        )
    }

    func markVideoWatched() {
        VideoService.markVideoWatched(
            video,
            modelContext: modelContext
        )
    }

    func clearVideoEverywhere() {
        VideoService.clearFromEverywhere(
            video,
            modelContext: modelContext
        )
    }

    func getLeadingSwipeActions() -> some View {
        Group {
            if videoSwipeActions.contains(.queue) {
                Button {
                    addVideoToQueue()
                } label: {
                    Image(systemName: "text.badge.plus")
                }
                .tint(.teal)
            }
            if videoSwipeActions.contains(.watched) {
                Button {
                    markVideoWatched()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .tint(.teal)
            }
        }
    }

    func getTrailingSwipeActions() -> some View {
        return Group {
            if videoSwipeActions.contains(.clear) {
                Button {
                    clearVideoEverywhere()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .tint(.orange)
            }
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
                        .clipShape(RoundedRectangle(cornerRadius: 15.0))
                } placeholder: {
                    Color.backgroundColor
                        .frame(width: 160, height: 90)
                }
                .padding(showVideoStatus ? 5 : 0)

                VStack(alignment: .leading, spacing: 3) {
                    Text(video.title)
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(2)
                    if let published = video.publishedDate {
                        Text(published.formatted)
                            .font(.system(size: 14, weight: .light))
                            .font(.body)
                            .foregroundStyle(Color.gray)
                    }
                    if let title = video.feedTitle {
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
                            Text(formatDurationFromSeconds(remaining))
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color.gray)
                        }
                    }
                }
            }
            if showVideoStatus,
               let statusInfo = getVideoStatusSystemName(video),
               let status = statusInfo.status {
                Image(systemName: status)
                    .resizable()
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, statusInfo.color)
                    .frame(width: 23, height: 23)
            }
        }
    }

    var body: some View {
        videoItem
            .onTapGesture {
                navManager.video = video
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                getLeadingSwipeActions()
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                getTrailingSwipeActions()
            }
        // TODO: clean up all files with videoSwipeActions, there are probably funcs and contexts no longer necessary
    }
}

func formatDurationFromSeconds(_ seconds: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.unitsStyle = .positional

    if let formattedDuration = formatter.string(from: seconds) {
        let components = formattedDuration.split(separator: ":")
        if components.count == 1 {
            return "\(formattedDuration)s"
        } else {
            return formattedDuration
        }
    } else {
        return ""
    }
}

#Preview {
    let video = Video(
        title: "Virtual Reality OasisResident Evil 4 Remake Is 10x BETTER In VR!",
        url: URL(string: "https://www.youtube.com/watch?v=_7vP9vsnYPc")!,
        youtubeId: "_7vP9vsnYPc",
        thumbnailUrl: URL(string: "https://i4.ytimg.com/vi/_7vP9vsnYPc/hqdefault.jpg")!,
        publishedDate: Date())
    video.status = .playing

    return VideoListItem(video: video,
                         showVideoStatus: true)
        .background(Color.gray)
}
