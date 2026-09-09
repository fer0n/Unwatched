//
//  SearchResultsList.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// The rows behind both the pushed results page and the macOS pane.
struct SearchResultsList: View {
    private static let collapsedPodcastCount = 3

    let vm: SearchVM
    @State private var showAllPodcasts = false

    var body: some View {
        List {
            if !vm.localResults.subscriptions.isEmpty {
                section(.subscriptions) {
                    ForEach(vm.localResults.subscriptions, id: \.persistentId) { sub in
                        NavigationLink(value: SearchRoute.subscription(sub)) {
                            SearchSubscriptionListItem(subscription: sub)
                        }
                    }
                    .myListRowBackground()
                }
            }

            if !vm.localResults.bookmarks.isEmpty {
                section(.bookmarks) {
                    videoRows(vm.localResults.bookmarks)
                }
            }

            if !vm.localResults.videos.isEmpty {
                section(.library) {
                    videoRows(vm.localResults.videos)
                }
            }

            if !vm.podcastResults.isEmpty {
                section(.podcasts) {
                    podcastRows
                }
            }

            if !vm.youtubeResults.isEmpty || !vm.youtubeChannelResults.isEmpty {
                section(.youtube) {
                    youtubeChannelRows(vm.youtubeChannelResults)

                    videoRows(vm.youtubeResults, loadMore: true)

                    if vm.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .listRowSeparator(.hidden)
                            .myListRowBackground()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .environment(\.videoListContext, .search)
        .onChange(of: vm.activeQuery) {
            showAllPodcasts = false
        }
    }

    /// Sections are only labelled once something local matched — a lone "YouTube"
    /// header above a plain search would just be noise.
    var showSectionHeaders: Bool {
        !vm.localResults.isEmpty || !vm.podcastResults.isEmpty
    }

    /// The label is an ordinary row rather than a `Section` header: a plain list pins
    /// headers, which makes them float free of the rows they label while scrolling.
    func section<Content: View>(
        _ source: SearchSource,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Section {
            if showSectionHeaders {
                source.label
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .myListRowBackground()
            }
            content()
        }
    }

    /// Podcast hits are a sidebar to the search, not its subject: only a few show until asked.
    @ViewBuilder
    var podcastRows: some View {
        let shown = showAllPodcasts
            ? vm.podcastResults
            : Array(vm.podcastResults.prefix(Self.collapsedPodcastCount))

        ForEach(shown, id: \.link) { sub in
            NavigationLink(value: SearchRoute.subscription(sub)) {
                SearchSubscriptionListItem(subscription: sub)
            }
        }
        .myListRowBackground()

        if !showAllPodcasts && vm.podcastResults.count > Self.collapsedPodcastCount {
            Button {
                withAnimation { showAllPodcasts = true }
            } label: {
                HStack(spacing: 4) {
                    Text("showMoreResults")
                    Image(systemName: "chevron.down")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .listRowSeparator(.hidden)
            .myListRowBackground()
        }
    }

    @ViewBuilder
    func youtubeChannelRows(_ channels: [SendableSubscription]) -> some View {
        if !channels.isEmpty {
            ForEach(channels, id: \.youtubeChannelId) { sub in
                NavigationLink(value: SearchRoute.subscription(sub)) {
                    SearchSubscriptionListItem(subscription: sub)
                }
            }
            .myListRowBackground()
            .videoListItemEntry()

            VStack {
                Divider()
                    .padding(.horizontal)
            }
            .videoListItemEntry()
            .myListRowBackground()
        }
    }

    func videoRows(_ videos: [SendableVideo], loadMore: Bool = false) -> some View {
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
                if loadMore {
                    vm.loadMoreIfNeeded(currentItem: video)
                }
            }
        }
        .myListRowBackground()
    }
}
