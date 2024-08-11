//
//  VideoListItemDetails.swift
//  Unwatched
//

import SwiftUI

struct VideoListItemDetails: View {
    @Environment(NavigationManager.self) private var navManager
    var video: Video
    var videoDuration: Double?
    // workaround: doesn't update instantly otherwise

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            let videoTitle = !video.title.isEmpty ? video.title : video.youtubeId
            Text(videoTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(2)
                .foregroundStyle(.primary)
            if video.publishedDate != nil || video.isYtShort {
                HStack {
                    if let published = video.publishedDate {
                        Text(published.formatted)
                            .font(.system(size: 14, weight: .light))
                            .font(.body)
                    }
                    if video.isYtShort {
                        Text(verbatim: "#s")
                            .font(.system(size: 14, weight: .regular))
                    }
                }
            }
            if let title = video.subscription?.displayTitle {
                Text(title)
                    .font(.system(size: 14, weight: .regular))
                    .lineLimit(1)
                    .textCase(.uppercase)
                    .onTapGesture {
                        if let sub = video.subscription {
                            navManager.pushSubscription(sub)
                        }
                    }
            }
            VideoListItemProgress(video: video, videoDuration: videoDuration)
        }
        .foregroundStyle(.secondary)
    }
}

struct VideoListItemProgress: View {
    let video: Video
    let videoDuration: Double?

    var body: some View {
        ZStack {
            if let duration = videoDuration ?? video.duration,
               let remaining = video.remainingTime,
               duration > 0 && remaining > 0 {
                HStack(alignment: .center) {
                    ProgressView(value: video.elapsedSeconds ?? 0, total: duration)
                        .opacity(0.6)
                        .padding(.top, 3)
                        .padding(.trailing, 5)
                    if video.hasFinished != true, let remaining = remaining.formattedSeconds {
                        Text(verbatim: "-\(remaining)")
                            .font(.system(size: 11, weight: .regular))
                    }
                }
            }
        }
    }
}

#Preview {
    VideoListItemDetails(video: Video.getDummy())
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(ImageCacheManager())
}
