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
            AsyncPlaceholderWorkaround(videoListVM: $videoListVM)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .task {
            videoListVM.filter = filter
            videoListVM.setSorting(sorting)
            await videoListVM.updateData()
        }
        .onChange(of: sorting) {
            videoListVM.setSorting(sorting, refresh: true)
        }
    }
}

struct AsyncPlaceholderWorkaround: View {
    @Binding var videoListVM: VideoListVM

    var body: some View {
        // workaround: UITabBar scrollEdgeAppearance pops in and out. Reason: the parent view is showing the
        // regular appearance. (if the parent is showing the scrollEdgeAppearance, it works correctly)
        // When the child appears, the view is initially empty and the tabbar transitions over to a transparent
        // background (e.g. the scrollEdgeAppearance). During the transition, the child has items show up and
        // they appear beneath the tab bar. then the tab bar transition is done and it pops back to being opaque.

        if videoListVM.videos.isEmpty && videoListVM.isLoading {
            Spacer()
                .frame(height: {
                    #if os(iOS)
                    return UIScreen.main.bounds.size.height
                    #else
                    return NSScreen.main?.frame.size.height ?? 800
                    #endif
                }())
                .listRowBackground(Color.backgroundColor)
        }
    }
}

struct VideoListViewAsync: View {
    @Binding var videoListVM: VideoListVM

    var body: some View {
        ForEach(videoListVM.videos, id: \.persistentId) { video in
            let config = VideoListItemConfig(
                hasInboxEntry: video.hasInboxEntry,
                hasQueueEntry: video.queueEntry != nil,
                watched: video.watchedDate != nil,
                deferred: video.deferDate != nil,
                isNew: video.isNew,
                onChange: { _ in
                    videoListVM.updateVideo(video)
                },
                async: true
            )

            VideoListItem(
                video,
                config: config
            )
            .videoListItemEntry()
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
