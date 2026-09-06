//
//  DebugSeed.swift
//  UnwatchedWatch
//

#if DEBUG
import SwiftData
import UnwatchedShared

/// Fills the store with a queue to look at, for a simulator that has no iCloud account to sync one
/// from. Launch with the `seed-demo` argument; it does nothing otherwise, and nothing in a release
/// build.
enum DebugSeed {
    @MainActor
    static func runIfRequested(_ context: ModelContext) {
        guard CommandLine.arguments.contains("seed-demo") else { return }
        guard (try? context.fetch(FetchDescriptor<QueueEntry>()))?.isEmpty != false else { return }

        let channel = Subscription(link: nil, title: "Veritasium", youtubeChannelId: "UCHnyfMqiRRG1u-2MsSQLbXA")
        let podcastShow = Subscription(link: nil, title: "SoundHelix", youtubeChannelId: "demo-podcast")
        podcastShow.isPodcast = true
        context.insert(channel)
        context.insert(podcastShow)

        let videos = [
            Video(
                title: "What Game Theory Reveals About Life, The Universe, and Everything",
                url: URL(string: "https://www.youtube.com/watch?v=mScpHTIi-kM"),
                youtubeId: "mScpHTIi-kM",
                thumbnailUrl: URL(string: "https://i2.ytimg.com/vi/mScpHTIi-kM/hqdefault.jpg")
            ),
            Video(
                title: "How screens actually affect your sleep",
                url: URL(string: "https://www.youtube.com/watch?v=isPxdnIND5k"),
                youtubeId: "isPxdnIND5k",
                thumbnailUrl: URL(string: "https://i2.ytimg.com/vi/isPxdnIND5k/hqdefault.jpg")
            )
        ]
        for video in videos {
            video.subscription = channel
        }

        let episode = Video(
            title: "SoundHelix Song 1",
            url: URL(string: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"),
            youtubeId: "demo-episode-1"
        )
        episode.mediaUrl = URL(string: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3")
        episode.isAudioOnly = true
        episode.subscription = podcastShow

        let all = videos + [episode]
        for (index, video) in all.enumerated() {
            context.insert(video)
            context.insert(QueueEntry(video: video, order: index))
        }

        // One include tag holding only the podcast show, to exercise the filter.
        let tag = Tag(name: "Podcasts", order: 0, symbol: "mic.fill")
        context.insert(tag)
        tag.subscriptions = [podcastShow]

        try? context.save()
        Log.info("DebugSeed: seeded \(all.count) videos")
    }

    /// Makes the sync indicator appear on a simulator, which has no iCloud account to sync from
    /// and so never reports a real import. `fake-syncing`.
    @MainActor
    static func fakeSyncingIfRequested(_ syncer: SyncManager) {
        guard CommandLine.arguments.contains("fake-syncing") else { return }
        // The container's own setup event ends (with "no iCloud account") shortly after launch and
        // would clear the flag again, so hold it on rather than setting it once.
        Task {
            while !Task.isCancelled {
                syncer.isSyncing = true
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    /// Starts one queue entry and reports what the player does for the next half minute, so
    /// playback can be checked on a simulator that takes no taps. `autoplay:<order>`.
    @MainActor
    static func autoplayIfRequested(_ context: ModelContext, _ player: WatchAudioPlayer) {
        guard let arg = CommandLine.arguments.first(where: { $0.hasPrefix("autoplay:") }),
              let order = Int(arg.dropFirst("autoplay:".count)) else { return }

        var descriptor = FetchDescriptor<QueueEntry>(
            predicate: #Predicate { $0.order == order },
            sortBy: [SortDescriptor(\QueueEntry.order)]
        )
        descriptor.fetchLimit = 1
        guard let video = (try? context.fetch(descriptor))?.first?.video else {
            Log.info("DebugSeed: no queue entry at order \(order)")
            return
        }

        Log.info("DebugSeed: autoplaying '\(video.title)'")
        player.play(video)

        Task {
            for _ in 0..<15 {
                try? await Task.sleep(for: .seconds(2))
                Log.info(
                    "DebugSeed: \(player.debugState) "
                        + "time=\(String(format: "%.1f", player.currentTime)) "
                        + "duration=\(player.duration.map { String(format: "%.1f", $0) } ?? "-") "
                        + "error=\(player.errorMessage ?? "-")"
                )
            }
        }
    }
}
#endif
