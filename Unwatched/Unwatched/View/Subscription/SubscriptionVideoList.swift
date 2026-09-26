//
//  SubscriptionVideoList.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct SubscriptionVideoList: View {
    @Query var videos: [Video]
    @State private var viewModel: SubscriptionVideoListVM

    init(subscriptionId: PersistentIdentifier, source: SubscriptionVideoListVM.Source, title: String) {
        _videos = VideoListView.query(subscriptionId: subscriptionId)
        _viewModel = State(initialValue: SubscriptionVideoListVM(source: source, title: title))
    }

    var body: some View {
        // one ForEach, so a row keeps its identity once it's stored
        ForEach(rows) { row in
            VideoListItem(row.video, row.id, config: row.config)
                .equatable()
                .videoListItemEntry()
        }
        .myListRowBackground()

        if viewModel.canLoadMore {
            showMoreButton
        }
    }

    var showMoreButton: some View {
        Button {
            Task { await viewModel.loadMore(excluding: Set(videos.map(\.youtubeId))) }
        } label: {
            HStack(spacing: 4) {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Text(viewModel.loadFailed ? "channelLoadFailed" : "showMoreResults")
                    Image(systemName: viewModel.loadFailed ? "arrow.clockwise" : "chevron.down")
                }
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .disabled(viewModel.isLoading)
        .listRowSeparator(.hidden)
        .myListRowBackground()
    }

    var rows: [Row] {
        let storedIds = Set(videos.map(\.youtubeId))
        let remote = viewModel.remoteVideos.filter { !storedIds.contains($0.youtubeId) }
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
