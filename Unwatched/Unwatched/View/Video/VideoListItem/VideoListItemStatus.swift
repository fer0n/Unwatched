//
//  VideoListItemStatus.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

private struct StatusInfo {
    let systemName: String
    let color: Color
    let label: LocalizedStringKey

    init(_ systemName: String, _ color: Color, _ label: LocalizedStringKey) {
        self.systemName = systemName
        self.color = color
        self.label = label
    }
}

struct VideoListItemStatus: View {
    @Environment(PlayerManager.self) private var player

    var showAllStatus: Bool = true
    var youtubeId: String

    var hasInboxEntry: Bool?
    var hasQueueEntry: Bool?
    var watched: Bool?
    var deferred: Bool?
    var isNew: Bool?

    @ScaledMetric var size = 23

    var body: some View {
        if let statusInfo {
            Image(systemName: statusInfo.systemName)
                .resizable()
                .foregroundStyle(.white, statusInfo.color.mix(with: .black, by: 0.1))
                .frame(width: size, height: size)
                .accessibilityLabel("videoStatus")
                .accessibilityValue(statusInfo.label)
                #if os(macOS)
                .padding(2)
            #endif
        }
    }

    private var statusInfo: StatusInfo? {
        let defaultColor = Color.green
        if showAllStatus {
            if youtubeId == player.video?.youtubeId {
                return StatusInfo("play.circle.fill", defaultColor, "nowPlaying")
            }
            if hasInboxEntry == true {
                return StatusInfo("tray.circle.fill", .teal, "inbox")
            }
            if hasQueueEntry == true {
                return StatusInfo("arrow.uturn.right.circle.fill", defaultColor, "queue")
            }
        }
        if isNew == true {
            return StatusInfo("circle.circle.fill", .mint, "statusNew")
        }
        if showAllStatus {
            if deferred == true {
                return StatusInfo("clock.circle.fill", .orange, "statusDeferred")
            }
            if watched == true {
                return StatusInfo(Const.watchedSF, defaultColor.mix(with: .black, by: 0.3), "watched")
            }
        }
        return nil
    }
}

#Preview {
    VStack {
        VideoListItemStatus(
            youtubeId: "id",
            // hasInboxEntry: true,
            // hasQueueEntry: true,
            // watched: true,
            deferred: true,
            )
        VideoListItemStatus(
            youtubeId: "id",
            // hasInboxEntry: true,
            // hasQueueEntry: true,
            watched: true,
            // deferred: true,
            )
        VideoListItemStatus(
            youtubeId: "id",
            // hasInboxEntry: true,
            hasQueueEntry: true,
            // watched: true,
            // deferred: true,
            )
        VideoListItemStatus(
            youtubeId: "id",
            hasInboxEntry: true,
            // hasQueueEntry: true,
            // watched: true,
            // deferred: true,
            )
    }
    .scaleEffect(4)
    .environment(PlayerManager())
}
