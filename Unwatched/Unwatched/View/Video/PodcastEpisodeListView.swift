//
//  PodcastEpisodeListView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

/// A show's episodes: the catalogue comes from the local cache, the state from the `Video` rows
/// that exist for the episodes the user has acted on.
struct PodcastEpisodeListView: View {
    @Environment(RefreshManager.self) private var refresher
    @Query private var touchedVideos: [Video]
    @State private var vm = PodcastEpisodeListVM()

    private let feedUrl: URL?
    private let show: SendableSubscription?
    /// Empty: the whole list
    private let searchText: String

    init(subscription: Subscription, searchText: String = "") {
        self.searchText = searchText
        let subscriptionId = subscription.persistentModelID
        _touchedVideos = Query(
            filter: #Predicate<Video> { $0.subscription?.persistentModelID == subscriptionId },
            animation: .default
        )
        feedUrl = subscription.link
        show = subscription.toExport
    }

    var body: some View {
        let touched = touchedById
        let isSearch = !searchText.trimmingCharacters(in: .whitespaces).isEmpty
        let episodes = isSearch ? (vm.searchResults ?? []) : vm.episodes

        ForEach(episodes, id: \.youtubeId) { episode in
            let video = touched[episode.youtubeId]

            VideoListItem(
                video ?? episode,
                episode.youtubeId,
                config: VideoListItemConfig(
                    hasInboxEntry: video?.inboxEntry != nil,
                    hasQueueEntry: video?.queueEntry != nil,
                    videoDuration: episode.duration,
                    watched: video?.watchedDate != nil,
                    deferred: video?.deferDate != nil,
                    isNew: video?.isNew ?? false,
                    episodeNumber: episode.episodeNumber
                )
            )
            .equatable()
            .videoListItemEntry()
            .onAppear {
                if !isSearch {
                    vm.loadMoreIfNeeded(currentItem: episode)
                }
            }
        }
        .myListRowBackground()

        if isSearch && !vm.isSearching && vm.searchResults?.isEmpty == true {
            ContentUnavailableView.search(text: searchText)
                .listRowSeparator(.hidden)
                .myListRowBackground()
        }

        // a modifier on `ForEach` applies per row, so the load has to hang off a row that exists
        // before there are any episodes
        loadingRow(isSearch: isSearch)
            .task {
                await vm.setUp(feedUrl: feedUrl, show: show)
            }
            .task(id: searchText) {
                guard isSearch else {
                    await vm.search("")
                    return
                }
                // wait for a pause in typing
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                await vm.search(searchText)
            }
            // episodes live in `PodcastEpisodeCache`, not in the `Video` rows `@Query` watches,
            // so a refresh that fetched new ones needs to be picked up by hand
            .onChange(of: refresher.isLoading) { _, isLoading in
                guard !isLoading else { return }
                Task {
                    await vm.reloadLoadedPages()
                }
            }
    }

    @ViewBuilder
    private func loadingRow(isSearch: Bool) -> some View {
        Group {
            if isSearch ? vm.isSearching : (vm.isLoading || !vm.hasLoadedFirstPage) {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Color.clear
                    .frame(height: 0)
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .myListRowBackground()
    }

    private var touchedById: [String: Video] {
        Dictionary(touchedVideos.map { ($0.youtubeId, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
