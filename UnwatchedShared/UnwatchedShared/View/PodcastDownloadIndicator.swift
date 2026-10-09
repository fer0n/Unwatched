//
//  PodcastDownloadIndicator.swift
//  UnwatchedShared
//

import SwiftUI

public struct PodcastDownloadIndicator: View {
    let video: VideoData
    let radius: CGFloat
    let padding: CGFloat

    @ScaledMetric private var iconSize = 10

    public init(video: VideoData, radius: CGFloat, padding: CGFloat) {
        self.video = video
        self.radius = radius
        self.padding = padding
    }

    public var body: some View {
        // a download in flight shows up in the progress bar instead
        if video.isPodcast, PodcastDownloadManager.shared.downloadedIds.contains(video.youtubeId) {
            let isTranscribing = TranscriptionActivity.shared.youtubeId == video.youtubeId
            Image(systemName: isTranscribing ? Const.transcribingSF : Const.downloadedSF)
                .font(.system(size: iconSize))
                .fontWeight(.heavy)
                .padding(padding)
                .foregroundStyle(.primary.opacity(0.9))
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .accessibilityElement(children: .ignore)
                .accessibilityValue(isTranscribing ? Text("generatingTranscript") : Text("downloaded"))
        }
    }
}
