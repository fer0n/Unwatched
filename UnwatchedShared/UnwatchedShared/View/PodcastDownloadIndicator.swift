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
        if video.downloadedDate != nil {
            Image(systemName: Const.downloadedSF)
                .font(.system(size: iconSize))
                .fontWeight(.heavy)
                .padding(padding)
                .foregroundStyle(.primary.opacity(0.9))
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .accessibilityElement(children: .ignore)
                .accessibilityValue("downloaded")
        }
    }
}
