//
//  DebugSeed.swift
//  UnwatchedWatch
//

#if DEBUG
import SwiftData
import SwiftUI
import UnwatchedShared

/// Fills the store with a queue to look at, for a simulator that has no iCloud account to sync one
/// from. Launch with the `seed-demo` argument; it does nothing otherwise, and nothing in a release
/// build.
enum DebugSeed {
    @MainActor
    static func runIfRequested(_ context: ModelContext) {
        guard CommandLine.arguments.contains("seed-demo") else { return }
        seed(context)
    }

    /// The same queue in the synced store, to exercise the full-sync side. `seed-mirror`.
    @MainActor
    static func seedMirrorIfRequested() {
        guard CommandLine.arguments.contains("seed-mirror") else { return }
        seed(DataProvider.shared.container.mainContext)
    }

    @MainActor
    private static func seed(_ context: ModelContext) {
        guard (try? context.fetch(FetchDescriptor<QueueEntry>()))?.isEmpty != false else { return }

        let channel = Subscription(link: nil, title: "Veritasium", youtubeChannelId: "UCHnyfMqiRRG1u-2MsSQLbXA")
        let podcastShow = Subscription(link: nil, title: "SoundHelix", youtubeChannelId: "demo-podcast")
        podcastShow.isPodcast = true
        podcastShow.thumbnailUrl = URL(string: "https://lagedernation.org/wp-content/blogs.dir/10/files/2020/06/apple_podcast_artwork_reverse.png")
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

    /// Pretends the phone is playing, for the pages that draw it. `fake-remote`, or
    /// `fake-remote-square` for a podcast episode with square cover art.
    @MainActor
    static func fakeRemoteIfRequested() {
        let isSquare = CommandLine.arguments.contains("fake-remote-square")
        guard isSquare || CommandLine.arguments.contains("fake-remote") else { return }
        let squareArt =
            "https://lagedernation.org/wp-content/blogs.dir/10/files/2020/06/apple_podcast_artwork_reverse.png"
        WatchNavigator.shared.controlsPhone = true
        WatchNavigator.shared.showPlayer(force: true)
        var state = WatchRemoteState(
            isPlaying: true,
            title: "What Game Theory Reveals About Life",
            channelTitle: "Veritasium",
            thumbnailUrl: URL(string: isSquare ? squareArt : "https://i2.ytimg.com/vi/mScpHTIi-kM/hqdefault.jpg"),
            isAudioOnly: isSquare,
            duration: 1800,
            position: 420,
            speed: 1.5,
            hasCustomSpeed: true,
            canSetCustomSpeed: true,
            hasPreviousChapter: true,
            hasNextChapter: true,
            chapterTitle: "The Prisoner's Dilemma, and why it matters",
            chapterEndTime: 1800,
            continuousPlay: true,
            trimSilence: true,
            canTrimSilence: true
        )
        WatchQueueClient.shared.debugSetRemote(state)

        // `fake-chapter-cycle`: a new chapter every 2 s, for watching the title change.
        guard CommandLine.arguments.contains("fake-chapter-cycle") else { return }
        let titles = ["The Prisoner's Dilemma, and why it matters", "Intro", "Tit for Tat"]
        Task {
            for index in 1... {
                try? await Task.sleep(for: .seconds(2))
                state.chapterTitle = titles[index % titles.count]
                withAnimation {
                    WatchQueueClient.shared.debugSetRemote(state)
                }
            }
        }
    }

    /// Imports a snapshot of the shape the phone sends, without needing a phone. `seed-snapshot`.
    @MainActor
    static func seedSnapshotIfRequested() {
        guard CommandLine.arguments.contains("seed-snapshot") else { return }
        let show = URL(
            string: "https://lagedernation.org/wp-content/blogs.dir/10/files/2020/06/apple_podcast_artwork_reverse.png"
        )
        let snapshot = WatchQueueSnapshot(
            items: [
                WatchQueueSnapshot.Item(
                    youtubeId: "pod-demo-1",
                    title: "An episode with no art of its own",
                    order: 0,
                    thumbnailUrl: show,
                    duration: 3600,
                    channelTitle: "Lage der Nation",
                    channelThumbnailUrl: show,
                    isAudioOnly: true
                ),
                WatchQueueSnapshot.Item(
                    youtubeId: "mScpHTIi-kM",
                    title: "What Game Theory Reveals About Life",
                    order: 1,
                    thumbnailUrl: URL(string: "https://i2.ytimg.com/vi/mScpHTIi-kM/hqdefault.jpg"),
                    channelTitle: "Veritasium"
                )
            ],
            tags: [
                WatchQueueSnapshot.TagItem(
                    name: "Podcasts",
                    order: 0,
                    mode: 0,
                    symbol: "mic.fill",
                    channelTitles: ["Lage der Nation"]
                )
            ]
        )
        do {
            let coded = try WatchQueueSnapshot.decoded(try snapshot.encoded())
            try WatchQueueStore.replace(with: coded)
            Log.info("DebugSeed: imported a snapshot of \(coded.items.count) items, \(coded.tags.count) tags")
        } catch {
            Log.error("DebugSeed: snapshot import failed: \(error)")
        }
    }

    /// Drives the `WatchConnectivity` queue request without a tap, for a paired simulator pair.
    @MainActor
    static func requestQueueIfRequested() async {
        guard CommandLine.arguments.contains("request-queue") else { return }
        await WatchQueueClient.shared.requestSnapshot()
        let client = WatchQueueClient.shared
        Log.info("debug request-queue: error=\(client.lastError ?? "none") update=\(client.lastUpdate?.description ?? "none")")
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
