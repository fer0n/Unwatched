//
//  SubscriptionVideoList.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct SubscriptionVideoList: View, Equatable {
    @Query var videos: [Video]
    @State private var viewModel: SubscriptionVideoListVM

    private let subscriptionId: PersistentIdentifier
    private let source: SubscriptionVideoListVM.Source
    private let limit: Int?
    private let showMoreStored: () -> Void

    init(
        subscriptionId: PersistentIdentifier,
        source: SubscriptionVideoListVM.Source,
        title: String,
        limit: Int?,
        showMoreStored: @escaping () -> Void
    ) {
        self.subscriptionId = subscriptionId
        self.source = source
        self.limit = limit
        self.showMoreStored = showMoreStored
        _videos = VideoListView.query(subscriptionId: subscriptionId, limit: limit.map { $0 + 1 })
        _viewModel = State(initialValue: SubscriptionVideoListVM(source: source, title: title))
    }

    // skips page redraws (e.g. the scrolling title); don't use .equatable(), it lays out every List row
    nonisolated static func == (lhs: SubscriptionVideoList, rhs: SubscriptionVideoList) -> Bool {
        lhs.subscriptionId == rhs.subscriptionId && lhs.source == rhs.source && lhs.limit == rhs.limit
    }

    /// The query fetches one past the limit to tell whether more are stored
    private var hidesStoredVideos: Bool {
        limit.map { videos.count > $0 } ?? false
    }

    private var shownVideos: ArraySlice<Video> {
        videos.prefix(limit ?? videos.count)
    }

    /// While stored videos are hidden, older remote ones could be copies of them
    private var remoteCutoff: Date? {
        guard hidesStoredVideos else { return nil }
        return shownVideos.last(where: { $0.publishedDate != nil })?.publishedDate ?? .distantFuture
    }

    var body: some View {
        // one ForEach, so a row keeps its identity once it's stored
        ForEach(rows) { row in
            VideoListItem(row.video, row.id, config: row.config)
                .equatable()
                .videoListItemEntry()
        }
        .myListRowBackground()

        if hidesStoredVideos || viewModel.canLoadMore {
            showMoreButton
        }
    }

    var showMoreButton: some View {
        Button {
            if hidesStoredVideos {
                showMoreStored()
            } else {
                Task { await viewModel.loadMore(excluding: Set(shownVideos.map(\.youtubeId))) }
            }
        } label: {
            HStack(spacing: 4) {
                let loadFailed = viewModel.loadFailed && !hidesStoredVideos
                if viewModel.isLoading && !hidesStoredVideos {
                    ProgressView()
                } else {
                    Text(!loadFailed ? "showMoreResults"
                            : viewModel.signedOut ? "watchLaterSignedOut" : "channelLoadFailed")
                    Image(systemName: loadFailed ? "arrow.clockwise" : "chevron.down")
                }
            }
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
        }
        .disabled(viewModel.isLoading && !hidesStoredVideos)
        .showMoreRow()
    }

    var rows: [Row] {
        if viewModel.keepsListOrder {
            return listOrderedRows
        }
        let videos = shownVideos
        let storedIds = Set(videos.map(\.youtubeId))
        let cutoff = remoteCutoff
        let remote = viewModel.remoteVideos.filter { video in
            guard !storedIds.contains(video.youtubeId) else { return false }
            guard let cutoff else { return true }
            return (video.publishedDate ?? .distantPast) > cutoff
        }
        guard !remote.isEmpty else { return videos.map(Row.stored) }

        var result: [Row] = []
        result.reserveCapacity(videos.count + remote.count)
        var storedIndex = 0, remoteIndex = 0
        while storedIndex < videos.count || remoteIndex < remote.count {
            let stored = storedIndex < videos.count ? videos[storedIndex] : nil
            let fetched = remoteIndex < remote.count ? remote[remoteIndex] : nil
            if let stored, let fetched,
               (fetched.publishedDate ?? .distantPast) > (stored.publishedDate ?? .distantPast) {
                result.append(.remote(fetched))
                remoteIndex += 1
            } else if let stored {
                result.append(.stored(stored))
                storedIndex += 1
            } else if let fetched {
                result.append(.remote(fetched))
                remoteIndex += 1
            }
        }
        return result
    }

    private var listOrderedRows: [Row] {
        let remote = viewModel.remoteVideos
        let stored = Dictionary(videos.map { ($0.youtubeId, $0) }, uniquingKeysWith: { first, _ in first })
        let listed = Set(remote.map(\.youtubeId))
        return remote.map { stored[$0.youtubeId].map(Row.stored) ?? .remote($0) }
            + videos.filter { !listed.contains($0.youtubeId) }.map(Row.stored)
    }

    enum Row: Identifiable {
        case stored(Video)
        case remote(SendableVideo)

        var id: String {
            video.youtubeId
        }

        var video: any VideoData {
            switch self {
            case .stored(let video): video
            case .remote(let video): video
            }
        }

        var config: VideoListItemConfig {
            switch self {
            case .stored(let video):
                VideoListItemConfig(video)
            case .remote(let video):
                VideoListItemConfig(videoDuration: video.duration, showDelete: false)
            }
        }
    }
}
