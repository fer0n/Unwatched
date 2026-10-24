//
//  SearchResultsList.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// The rows behind both the pushed results page and the macOS pane.
struct SearchResultsList: View {
    let vm: SearchVM
    @State private var expandedSources: Set<SearchSource> = []

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
                    libraryRows
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
            expandedSources = []
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

    @ViewBuilder
    var podcastRows: some View {
        ForEach(collapsed(vm.podcastResults, in: .podcasts), id: \.link) { sub in
            NavigationLink(value: SearchRoute.subscription(sub)) {
                SearchSubscriptionListItem(subscription: sub)
            }
        }
        .myListRowBackground()

        showMoreButton(for: .podcasts, total: vm.podcastResults.count)
    }

    @ViewBuilder
    var libraryRows: some View {
        videoRows(collapsed(vm.localResults.videos, in: .library))
        showMoreButton(for: .library, total: vm.localResults.videos.count)
    }

    func collapsedCount(for source: SearchSource) -> Int {
        source == .podcasts ? 1 : 3
    }

    func collapsed<Item>(_ items: [Item], in source: SearchSource) -> [Item] {
        expandedSources.contains(source) ? items : Array(items.prefix(collapsedCount(for: source)))
    }

    @ViewBuilder
    func showMoreButton(for source: SearchSource, total: Int) -> some View {
        if !expandedSources.contains(source) && total > collapsedCount(for: source) {
            Button {
                withAnimation { _ = expandedSources.insert(source) }
            } label: {
                HStack(spacing: 4) {
                    Text("showMoreResults")
                    Image(systemName: "chevron.down")
                }
                .padding(.vertical, 5)
            }
            .showMoreRow()
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
        SearchVideoRows(videos: videos, vm: vm) { video in
            if loadMore {
                vm.loadMoreIfNeeded(currentItem: video)
            }
        }
    }
}
