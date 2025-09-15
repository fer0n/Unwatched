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
                Text(verbatim: "#s")
                    .accessibilityElement(children: .ignore)
                    .accessibilityValue("#short")
                    .padding(.horizontal, padding)
            } else if let totalDuration {
                Text(totalDuration.formattedSecondsColon)
                    .accessibilityElement(children: .ignore)
                    .accessibilityValue(String(localized: "\(accessibilityDuration(totalDuration)) long"))
                    .padding(.horizontal, padding)
            } else if video.noDuration == true {
                Image(systemName: "dot.radiowaves.left.and.right")
                .accessibilityElement(children: .ignore)
                .accessibilityValue("Live/Upcoming")
                .padding(3)
            } else if let roughDuration {
                formatRoughDuration(roughDuration)
                    .padding(.horizontal, padding)
            }
        }
        .font(.subheadline)
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
