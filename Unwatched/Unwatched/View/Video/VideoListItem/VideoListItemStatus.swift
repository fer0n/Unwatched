//
//  VideoListItemStatus.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct VideoListItemStatus: View {
    var youtubeId: String
    var playingVideoId: String?

    var hasInboxEntry: Bool?
    var hasQueueEntry: Bool?
    var watched: Bool?
    var deferred: Bool?

    @ScaledMetric var size = 23

    var body: some View {
        if let statusInfo = videoStatusSystemName,
           let status = statusInfo.status {
            Image(systemName: status)
                .resizable()
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, statusInfo.color)
                .frame(width: size, height: size)
                .accessibilityLabel("videoStatus")
                #if os(macOS)
                .padding(2)
            #endif
        }
    }

    var videoStatusSystemName: (status: String?, color: Color)? {
        let defaultColor = Color.green
        if youtubeId == playingVideoId {
            return ("play.circle.fill", defaultColor)
        }
        if hasInboxEntry == true {
            return ("circle.circle.fill", .mint)
        }
        if hasQueueEntry == true {
            return ("arrow.uturn.right.circle.fill", defaultColor)
        }
        if deferred == true {
            return ("clock.circle.fill", .orange)
        }
        if watched == true {
            return (Const.watchedSF, defaultColor)
        }
        return nil
    }
}

#Preview {
    VideoListItemStatus(
        youtubeId: "id",
        hasInboxEntry: false,
        hasQueueEntry: false,
        watched: false,
        deferred: true
    )
}
