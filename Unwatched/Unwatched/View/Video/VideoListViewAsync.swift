//
//  VideoListViewAsync.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct VideosViewAsync: View {
    @Environment(\.modelContext) var modelContext

    @Binding var videoListVM: VideoListVM
    var sorting: [SortDescriptor<Video>] = []
    var filter: Predicate<Video>?

    var body: some View {
        List {
            VideoListViewAsync(videoListVM: $videoListVM)
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

    var body: some View {
        ForEach(videoListVM.videos, id: \.persistentId) { video in
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
            .onAppear {
                videoListVM.loadMoreContentIfNeeded(currentItem: video)
            }
        }
        .listRowBackground(Color.backgroundColor)

        if videoListVM.isLoading && !videoListVM.videos.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.backgroundColor)
        }
    }
}
