//
//  VideoListItemDetails.swift
//  Unwatched
//

import SwiftUI

struct VideoListItemDetails: View {
    @Environment(NavigationManager.self) private var navManager
    var video: Video
    var showQueueButton: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            let videoTitle = !video.title.isEmpty ? video.title : video.youtubeId
            Text(videoTitle)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 3) {
                if let subTitle = video.subscription?.displayTitle {
                    Text(subTitle)
                        .font(.system(size: 14, weight: .regular))
                        .lineLimit(1)
                        .textCase(.uppercase)
                        .onTapGesture {
                            if let sub = video.subscription {
                                navManager.pushSubscription(sub)
                            }
                        }
                }

                if let published = video.publishedDate {
                    Text("\(published.formattedRelative) ago")
                        .font(.system(size: 12, weight: .regular))
                }
            }
            .padding(.trailing, showQueueButton ? 30 : 0)
        }
        .foregroundStyle(.secondary)
    }
}

struct QueueVideoButton: View {
    @AppStorage(Const.themeColor) var theme: ThemeColor = Color.defaultTheme
    @Environment(\.modelContext) var modelContext

    var video: Video
    let size: CGFloat = 30

    init(_ video: Video) {
        self.video = video
    }

    var body: some View {
        Button(role: .destructive, action: addToTopQueue, label: {
            Image(systemName: "arrow.uturn.right")
                .font(.system(size: 16, weight: .bold))
                .frame(width: size, height: size)
                .background {
                    Circle()
                        .fill(.automaticBlack.opacity(0.1))
                }
                .foregroundStyle(.secondary)
        })
        .onTapGesture(perform: addToTopQueue)
        .accessibilityLabel("queueNext")
        // button for accessibility, tapGesture to override parent
    }

    func addToTopQueue() {
        _ = VideoService.insertQueueEntries(
            at: 1,
            videos: [video],
            modelContext: modelContext
        )
    }
}

#Preview {
    VideoListItemDetails(video: Video.getDummy())
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(ImageCacheManager())
        .padding()
}
