//
//  VideoListItemDetails.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct VideoListItemDetails: View {
    @Environment(\.videoListShowsUploader) private var showsUploader

    let video: VideoData

    @ScaledMetric private var titleSize = 15
    @ScaledMetric private var subSize = 14
    @ScaledMetric private var timeSize = 12

    /// The row names the playlist the video came through rather than its channel
    private var showsPlaylist: Bool {
        !showsUploader && video.playlistTitle != nil
    }

    private var sourceTitle: String? {
        (showsUploader ? video.uploaderTitle : video.playlistTitle) ?? video.channelDisplayTitle
    }

    private var videoTitle: String {
        video.title.isEmpty ? video.youtubeId : video.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(videoTitle)
                .font(.system(size: titleSize, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 3) {
                if let subTitle = sourceTitle {
                    Text(subTitle)
                        .font(.system(size: subSize))
                        .lineLimit(1)
                        .textCase(.uppercase)
                        #if !os(visionOS)
                        .onTapGesture {
                            VideoListItemDetails.handleSourceTap(video, opensPlaylist: showsPlaylist)
                        }
                    #endif
                }

                if let published = video.publishedDate {
                    Text(published.formattedRelative)
                        .font(.system(size: timeSize))
                        .accessibilityLabel(
                            published.formatted(
                                .relative(
                                    presentation: .numeric,
                                    unitsStyle: .spellOut
                                )
                            )
                        )
                }
            }
            .foregroundStyle(.secondary)
        }
    }

    private static func handleSourceTap(_ video: VideoData, opensPlaylist: Bool) {
        let navManager = NavigationManager.shared
        if !opensPlaylist,
           let video = VideoService.existingVideoModel(from: video, modelContext: DataProvider.mainContext) {
            navManager.pushChannel(of: video)
            return
        }
        guard let sub = video.subscriptionData, opensPlaylist || sub.youtubePlaylistId == nil else { return }
        if let sendable = sub as? SendableSubscription {
            navManager.pushSubscription(sendableSubscription: sendable)
        } else if let subscription = sub as? Subscription {
            navManager.pushSubscription(subscription: subscription)
        }
    }
}

#Preview {
    VideoListItemDetails(video: Video.getDummy())
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(ImageCacheManager())
        .padding()
}
