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
    @Query private var touchedVideos: [Video]
    @State private var vm = PodcastEpisodeListVM()

    private let feedUrl: URL?
    private let show: SendableSubscription?

    init(subscription: Subscription) {
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

        ForEach(vm.episodes, id: \.youtubeId) { episode in
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
                    isNew: video?.isNew ?? false
                )
            )
            .equatable()
            .videoListItemEntry()
            .onAppear {
                vm.loadMoreIfNeeded(currentItem: episode)
            }
        }
        .myListRowBackground()

        // a modifier on `ForEach` applies per row, so the load has to hang off a row that exists
        // before there are any episodes
        loadingRow
            .task {
                await vm.setUp(feedUrl: feedUrl, show: show)
            }
    }

    @ViewBuilder
    private var loadingRow: some View {
        Group {
            if vm.isLoading || !vm.hasLoadedFirstPage {
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
