//
//  VideoListItemDetails.swift
//  Unwatched
//

import SwiftUI

struct VideoListItemDetails: View {
    @Environment(NavigationManager.self) private var navManager
    var video: Video

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            let videoTitle = !video.title.isEmpty ? video.title : video.youtubeId
            Text(videoTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 15, weight: .medium))
                .lineLimit(2)
                .foregroundStyle(.primary)
            if video.publishedDate != nil || video.isYtShort || video.isLikelyYtShort {
                HStack {
                    if let published = video.publishedDate {
                        Text(published.formatted)
                            .font(.system(size: 14, weight: .light))
                            .font(.body)
                    }
                    if video.isYtShort || video.isLikelyYtShort {
                        Text(verbatim: "#s\(video.isYtShort == true ? "." : "")")
                            .font(.system(size: 14, weight: .regular))
                    }
                }
            }
            if let title = video.subscription?.title {
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
            if let duration = video.duration,
               let remaining = video.remainingTime,
               duration > 0 && remaining > 0 {
                HStack(alignment: .center) {
                    ProgressView(value: video.elapsedSeconds ?? 0, total: duration)
                        .opacity(0.6)
                        .padding(.top, 3)
                        .padding(.trailing, 5)
                    if video.hasFinished != true, let remaining = remaining.formattedSeconds {
                        Text(verbatim: "-\(remaining)")
                            .font(.system(size: 12, weight: .regular))
                    }
                }
            }
        }
        .foregroundStyle(.secondary)
    }
}

#Preview {
    VideoListItemDetails(video: Video.getDummy())
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(ImageCacheManager())
}
