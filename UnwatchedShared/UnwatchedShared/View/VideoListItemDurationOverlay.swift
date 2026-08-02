//
//  VideoListItemDurationOverlay.swift
//  UnwatchedShared
//

import SwiftUI

public struct VideoListItemDurationOverlay: View {
    let video: VideoData
    let videoDuration: Double?
    let roughDuration: Double?
    let radius: CGFloat
    let padding: CGFloat
    let font: Font

    public init(
        video: VideoData,
        videoDuration: Double?,
        roughDuration: Double?,
        radius: CGFloat,
        padding: CGFloat,
        font: Font = .subheadline
    ) {
        self.video = video
        self.videoDuration = videoDuration
        self.roughDuration = roughDuration
        self.radius = radius
        self.padding = padding
        self.font = font
    }

    public var body: some View {
        ZStack {
            if video.isYtShort == true {
                Text(verbatim: "#s")
                    .accessibilityElement(children: .ignore)
                    .accessibilityValue("#short")
                    .padding(.horizontal, padding)
                    .padding(.vertical, 1)
            } else if let totalDuration {
                Text(totalDuration.formattedSecondsColon)
                    .accessibilityElement(children: .ignore)
                    .accessibilityValue(String(localized: "\(accessibilityDuration(totalDuration)) long"))
                    .padding(.horizontal, padding)
                    .padding(.vertical, 1)
            } else if video.noDuration == true {
                Image(systemName: "dot.radiowaves.left.and.right")
                .accessibilityElement(children: .ignore)
                .accessibilityValue("Live/Upcoming")
                .padding(padding)
            } else if let roughDuration {
                formatRoughDuration(roughDuration)
                    .padding(.horizontal, padding)
                    .padding(.vertical, 1)
            }
        }
        .font(font)
        .foregroundStyle(.primary.opacity(0.9))
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
    
    private var totalDuration: Double? {
        videoDuration ?? video.duration
    }

    private func formatRoughDuration(_ duration: Double) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Text(duration.formattedSecondsColon)
                .foregroundStyle(.primary)
            Image(systemName: "plus")
                .fontWeight(.semibold)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.trailing, -2)
        .accessibilityElement(children: .ignore)
        .accessibilityValue(String(localized: "At least \(accessibilityDuration(duration)) long"))
    }
    
    func accessibilityDuration(_ duration: Double) -> String {
        Duration.seconds(duration).formatted(.units(allowed: [.hours, .minutes]))
    }
}
