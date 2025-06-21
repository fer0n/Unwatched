//
//  VideoListItemDurationOverlay.swift
//  UnwatchedShared
//

import SwiftUI

struct VideoListItemDurationOverlay: View {
    let video: VideoData
    let videoDuration: Double?
    let roughDuration: Double?
    let radius: CGFloat
    let padding: CGFloat

    var body: some View {
        ZStack {
            if video.isYtShort == true {
                Text("#s")
                    .accessibilityElement(children: .ignore)
                    .accessibilityValue("#short")
            } else if let totalDuration {
                Text(totalDuration.formattedSecondsColon)
                    .accessibilityElement(children: .ignore)
                    .accessibilityValue(String(localized: "\(accessibilityDuration(totalDuration)) long"))
            } else if let roughDuration {
                formatRoughDuration(roughDuration)
            }
        }
        .font(.subheadline)
        .foregroundStyle(.primary.opacity(0.9))
        .padding(.horizontal, padding)
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
