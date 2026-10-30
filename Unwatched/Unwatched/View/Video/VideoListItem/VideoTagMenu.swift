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
        if !tags.isEmpty {
            let video = storedVideo
            Menu {
                ForEach(tags) { tag in
                    let viaChannel = tag.covers(video?.subscription)
                    Button {
                        withAnimation {
                            toggle(tag)
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
                Label("tags", systemImage: Const.tagSF)
            }
        }
    }

    private var storedVideo: Video? {
        videoData as? Video ?? VideoService.getVideo(for: videoData.youtubeId, modelContext: modelContext)
    }

    private func toggle(_ tag: Tag) {
        guard let video = VideoService.getVideoModel(from: videoData, modelContext: modelContext) else { return }
        tag.setCovers(video: video, !tag.covers(video: video))
        try? modelContext.save()
    }
}
