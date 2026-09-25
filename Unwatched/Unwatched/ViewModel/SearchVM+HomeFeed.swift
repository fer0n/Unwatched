//
//  SearchVM+HomeFeed.swift
//  Unwatched
//

import SwiftData
import SwiftUI
import UnwatchedShared

extension SearchVM {
    private static let homeFeedLifetime: TimeInterval = 30 * 60
    private static let homeFeedSeedCount = 3

    func loadHomeFeedIfNeeded(force: Bool = false) {
        if !force {
            guard homeFeedTask == nil else { return }
            if let loaded = homeFeedLoadedAt, Date().timeIntervalSince(loaded) < Self.homeFeedLifetime {
                return
            }
        }
        homeFeedTask?.cancel()
        isLoadingHomeFeed = homeFeed.isEmpty
        let seeds = Self.homeFeedSeeds()
        homeFeedTask = Task {
            do {
                let page = try await HomeFeedService.shared.fetch(seedIds: seeds)
                if Task.isCancelled { return }
                withAnimation {
                    homeFeed = Self.unwatchedVideos(page.videos)
                }
                homeFeedToken = page.nextPageToken
                homeFeedLoadedAt = .now
            } catch {
                if Task.isCancelled { return }
                Log.error("home feed failed: \(error)")
            }
            isLoadingHomeFeed = false
            homeFeedTask = nil
        }
    }

    func reloadHomeFeed() async {
        loadHomeFeedIfNeeded(force: true)
        await homeFeedTask?.value
    }

    func loadMoreHomeFeedIfNeeded(currentItem: SendableVideo) {
        guard let index = homeFeed.firstIndex(where: { $0.youtubeId == currentItem.youtubeId }),
              index >= homeFeed.count - 3,
              let token = homeFeedToken, !isLoadingMoreHomeFeed, homeFeedTask == nil else { return }
        isLoadingMoreHomeFeed = true
        Task {
            defer { isLoadingMoreHomeFeed = false }
            do {
                let page = try await HomeFeedService.shared.fetchMore(token: token)
                guard token == homeFeedToken else { return }
                let existing = Set(homeFeed.map(\.youtubeId))
                let new = Self.unwatchedVideos(page.videos).filter { !existing.contains($0.youtubeId) }
                withAnimation {
                    homeFeed.append(contentsOf: new)
                }
                homeFeedToken = page.nextPageToken
            } catch {
                Log.error("home feed loadMore failed: \(error)")
            }
        }
    }

    private static func unwatchedVideos(_ videos: [ITVideo]) -> [SendableVideo] {
        let sendable = videos.map(sendable(from:))
        let stored = storedStatuses(for: sendable.map(\.youtubeId))
        return sendable.compactMap { video in
            guard let match = stored[video.youtubeId] else { return video }
            return match.watchedDate == nil ? match : nil
        }
    }

    // the last watched videos, topped up from the queue
    private static func homeFeedSeeds() -> [String] {
        let context = DataProvider.mainContext
        var watched = FetchDescriptor<Video>(
            predicate: #Predicate { $0.watchedDate != nil && $0.mediaUrl == nil },
            sortBy: [SortDescriptor(\.watchedDate, order: .reverse)]
        )
        watched.fetchLimit = homeFeedSeedCount
        var seeds = ((try? context.fetch(watched)) ?? []).map(\.youtubeId)
        if seeds.count < homeFeedSeedCount {
            var queue = FetchDescriptor<QueueEntry>(sortBy: [SortDescriptor(\.order)])
            queue.fetchLimit = homeFeedSeedCount * 2
            let queued = ((try? context.fetch(queue)) ?? [])
                .compactMap { $0.video }
                .filter { $0.mediaUrl == nil }
                .map(\.youtubeId)
            seeds += queued.filter { !seeds.contains($0) }
        }
        return Array(seeds.prefix(homeFeedSeedCount))
    }
}
