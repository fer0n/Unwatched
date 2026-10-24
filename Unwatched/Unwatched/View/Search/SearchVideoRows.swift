//
//  SearchVideoRows.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SearchVideoRows: View {
    let videos: [SendableVideo]
    let vm: SearchVM
    var onAppear: (SendableVideo) -> Void = { _ in }

    var body: some View {
        ForEach(videos, id: \.youtubeId) { video in
            VideoListItem(
                video,
                video.youtubeId,
                config: VideoListItemConfig(
                    hasInboxEntry: video.hasInboxEntry,
                    hasQueueEntry: video.queueEntry != nil,
                    videoDuration: video.duration,
                    watched: video.watchedDate != nil,
                    deferred: video.deferDate != nil,
                    isNew: video.isNew,
                    showAllStatus: true,
                    showContextMenu: true,
                    showDelete: false
                ),
                onChange: { _, _ in
                    vm.refreshStatus(for: video.youtubeId)
                }
            )
            .equatable()
            .videoListItemEntry()
            .onAppear {
                onAppear(video)
            }
        }
        .myListRowBackground()
    }
}
