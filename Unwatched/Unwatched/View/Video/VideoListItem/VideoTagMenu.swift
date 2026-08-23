//
//  VideoTagMenu.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

/// Only the `include` tags: adding to a subtractive one would take the video out of it.
struct VideoTagMenu: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: Tag.includeMode, sort: \Tag.order) private var tags: [Tag]

    let videoData: VideoData

    var body: some View {
        if !tags.isEmpty,
           let video = VideoService.getVideoModel(from: videoData, modelContext: modelContext) {
            Menu {
                ForEach(tags) { tag in
                    let viaChannel = tag.covers(video.subscription)
                    Button {
                        withAnimation {
                            toggle(tag, video)
                        }
                    } label: {
                        Label(
                            tag.name,
                            systemImage: viaChannel || tag.covers(video: video)
                                ? Const.checkmarkSF
                                : tag.displaySymbol
                        )
                    }
                    .disabled(viaChannel)
                }
            } label: {
                Label("tags", systemImage: Const.filterTagSF)
            }
        }
    }

    private func toggle(_ tag: Tag, _ video: Video) {
        tag.setCovers(video: video, !tag.covers(video: video))
        try? modelContext.save()
    }
}
