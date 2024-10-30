//
//  VideoListViewAsync.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct VideosViewAsync: View {
    @Environment(\.modelContext) var modelContext

    @Binding var videoListVM: VideoListVM
    var searchText: String?
    var sorting: [SortDescriptor<Video>] = []
    var filter: Predicate<Video>?

    var body: some View {
        List {
            VideoListViewAsync(videoListVM: $videoListVM, searchText: searchText)
        }
        .listStyle(.plain)
        .task {
            videoListVM.container = modelContext.container
            videoListVM.filter = filter
            videoListVM.setSorting(sorting)
            await videoListVM.updateData()
        }
        .onChange(of: sorting) {
            videoListVM.setSorting(sorting, refresh: true)
        }
    }
}

struct VideoListViewAsync: View {
    @AppStorage(Const.hideShorts) var hideShorts: Bool = false

    @Binding var videoListVM: VideoListVM
    var searchText: String?

    var body: some View {
        ForEach(filtered, id: \.persistentId) { video in
            let config = VideoListItemConfig(
                showVideoStatus: true,
                hasInboxEntry: video.hasInboxEntry,
                hasQueueEntry: video.queueEntry != nil,
                watched: video.watchedDate != nil,
                onChange: {
                    videoListVM.updateVideo(video)
                },
                async: true
            )

            VideoListItem(
                video,
                config: config
            )
        }
        .listRowBackground(Color.backgroundColor)
    }

    var filtered: [SendableVideo] {
        if let searchText = searchText, !searchText.isEmpty {
            videoListVM.videos.filter({ $0.title.localizedStandardContains(searchText) })
        } else {
            videoListVM.videos
        }
    }
}
