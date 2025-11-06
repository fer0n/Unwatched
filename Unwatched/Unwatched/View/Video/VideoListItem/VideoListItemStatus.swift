//
//  VideoListItemStatus.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

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
        if let statusInfo = videoStatusSystemName,
           let status = statusInfo.status {
            Image(systemName: status)
                .resizable()
                .foregroundStyle(.white, statusInfo.color.myMix(with: .black, by: 0.1))
                .frame(width: size, height: size)
                .accessibilityLabel("videoStatus")
                #if os(macOS)
                .padding(2)
            #endif
        }
    }

    var videoStatusSystemName: (status: String?, color: Color)? {
        let defaultColor = Color.green
        if showAllStatus {
            if youtubeId == player.video?.youtubeId {
                return ("play.circle.fill", defaultColor)
            }
            if hasInboxEntry == true {
                return ("tray.circle.fill", .teal)
            }
            if hasQueueEntry == true {
                return ("arrow.uturn.right.circle.fill", defaultColor)
            }
        }
        if isNew == true {
            return ("circle.circle.fill", .mint)
        }
        if showAllStatus {
            if deferred == true {
                return ("clock.circle.fill", .orange)
            }
            if watched == true {
                return (Const.watchedSF, defaultColor.myMix(with: .black, by: 0.3))
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
