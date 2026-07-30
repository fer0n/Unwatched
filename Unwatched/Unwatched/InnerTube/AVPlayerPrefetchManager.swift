#if !os(macOS)
import AVKit
import OSLog
import UnwatchedShared
import WebKit

// Manages background pre-building of AVPlayerItems for the next queued video.
final class AVPlayerPrefetchManager {

    struct PrefetchResult {
        let videoId: String
        /// The warmed asset, not a ready-made `AVPlayerItem`: an item may only ever be attached
        /// to one `AVPlayer`, and `replaceCurrentItem(with: nil)` does not detach it
        /// synchronously — re-attaching one that was warmed on another player raises
        /// `AVPlayerItem cannot be associated with more than one instance of AVPlayer`.
        /// The consumer builds a fresh item from this asset; the asset keeps what warming
        /// loaded (manifest/variant playlists, moov, live connections, cached segments).
        let asset: AVURLAsset
        let playerInfo: PlayerInfo?
        let headers: [String: String]
        let originalAudioLanguage: String
        let isWebViewHLS: Bool
        let masterURL: URL?
        let nSolver: (unsolved: String, solved: String)?
        let poToken: String?
        let proxyLoader: YTHLSProxyLoader?
        let audioTracks: [AudioTrack]
        let qualities: [(height: Int, label: String)]
    }

    private var prefetchTask: Task<Void, Never>?
    private var prefetchingVideoId: String?
    private(set) var result: PrefetchResult?

    private let api: InnerTubeAPI

    init(api: InnerTubeAPI) {
        self.api = api
    }

    // MARK: - Public interface

    @MainActor
    func prefetchNext(videoId: String) {
        if result?.videoId == videoId { return }
        if prefetchingVideoId == videoId { return }
        prefetchTask?.cancel()
        prefetchTask = nil
        stopWarming()
        result = nil
        prefetchingVideoId = videoId
        prefetchTask = Task {
            let built = await buildResult(videoId: videoId)
            await MainActor.run {
                guard !Task.isCancelled, self.prefetchingVideoId == videoId else { return }
                self.result = built
                self.prefetchingVideoId = nil
                if let built { self.startWarming(built.asset) }
            }
        }
    }

    /// Returns and clears the prefetched result for `videoId`, cancelling any in-flight task.
    /// Returns `nil` if no matching result is ready.
    @MainActor
    func consumeResult(for videoId: String) -> PrefetchResult? {
        guard result?.videoId == videoId else { return nil }
        let pre = result
        result = nil
        stopWarming()
        prefetchTask?.cancel()
        prefetchTask = nil
        prefetchingVideoId = nil
        return pre
    }

    /// Drops whatever is held unless it is for `videoId`. See `AVPlayerViewModel.discardPrefetch`.
    @MainActor
    func discardUnlessHolding(_ videoId: String?) {
        guard let held = result?.videoId ?? prefetchingVideoId, held != videoId else { return }
        Log.info("[AVPlayerView] discarding stale prefetch: \(held)")
        cancelAll()
    }

    @MainActor
    func cancelAll() {
        prefetchTask?.cancel()
        prefetchTask = nil
        prefetchingVideoId = nil
        stopWarming()
        result = nil
    }

    // MARK: - Warm-up

    /// Paused, muted player whose only job is to make AVFoundation actually load the prefetched
    /// asset. An `AVPlayerItem` that is never some player's `currentItem` performs no I/O at
    /// all — it stays `.unknown` until it is attached — so without this the "prefetch" would
    /// only save the InnerTube round-trip and the manifest would still be fetched at switch time.
    ///
    /// The warmed item is a throwaway; only the *asset* is handed on (see `PrefetchResult`).
    /// What survives is what dominates start-up latency: parsed master/variant playlists or the
    /// moov atom, an established TLS connection to the CDN, and the initial segments in
    /// AVFoundation's HTTP cache.
    @MainActor private var warmupPlayer: AVPlayer?
    @MainActor private var warmupItem: AVPlayerItem?

    /// Caps how much bandwidth warming steals from the video that is actually playing.
    private static let warmupBufferSeconds: Double = 10

    @MainActor
    private func startWarming(_ asset: AVURLAsset) {
        let player = warmupPlayer ?? {
            let new = AVPlayer()
            new.isMuted = true
            new.volume = 0
            warmupPlayer = new
            return new
        }()
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = Self.warmupBufferSeconds
        warmupItem = item
        player.replaceCurrentItem(with: item)
        player.pause()
        Log.info("[AVPlayerView] prefetch warming started")
    }

    @MainActor
    private func stopWarming() {
        warmupPlayer?.replaceCurrentItem(with: nil)
        warmupItem = nil
    }

    // MARK: - Building

    private struct ClientResult: @unchecked Sendable {
        let priority: Int
        let client: String
        let info: PlayerInfo
    }

    private func buildResult(videoId: String) async -> PrefetchResult? {
        Log.info("[AVPlayerView] prefetch starting: \(videoId)")

        if let cached = await MainActor.run(body: { WKHLSManager.shared.validEntry(for: videoId) }) {
            Log.info("[AVPlayerView] prefetch wkHLS cache hit: \(videoId)")
            return await buildWebViewHLSResult(url: cached.url, nSolver: cached.nSolver,
                                               poToken: cached.poToken, originalAudioLanguage: "",
                                               videoId: videoId)
        }

        // Deliberately no WKWebView extraction here: it takes up to 40 s, it can only ever
        // finish long after the user has moved on, and it monopolises the shared singleton
        // extractor that the foreground `primaryRace` needs.
        let results = await fetchAllClients(videoId: videoId)
        guard !Task.isCancelled else { return nil }

        // 1. HLS, in the same client-priority order the playback loop prefers.
        if let hit = results.first(where: { $0.info.hlsURL != nil }), let hlsURL = hit.info.hlsURL {
            let headers = StreamHeaders.hls(forClient: hit.client)
            let asset = AVURLAsset(url: hlsURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            Log.info("[AVPlayerView] prefetch built asset (HLS/\(hit.client)): \(videoId)")
            return PrefetchResult(videoId: videoId, asset: asset,
                                  playerInfo: hit.info, headers: headers,
                                  originalAudioLanguage: hit.info.originalAudioLanguage,
                                  isWebViewHLS: false, masterURL: nil, nSolver: nil,
                                  poToken: nil, proxyLoader: nil, audioTracks: [],
                                  qualities: StreamQualityHelper.videoQualities(from: hit.info))
        }

        // 2. Muxed direct MP4 (360p) — `exhaustiveRetry`'s last resort. Android only, exactly
        //    as the playback loop does it: other clients hand out muxed URLs that AVPlayer
        //    cannot open (observed: MWEB's itag=18 fails with -11829 "Cannot Open"), which
        //    would burn the prefetch on a stream that is guaranteed to fail.
        //    SABR URLs serve binary UMP data rather than a playable MP4, so they're excluded.
        for hit in results where hit.client == "Android" {
            guard let muxedURL = hit.info.bestMuxedDownloadURL,
                  !muxedURL.absoluteString.contains("c=TVHTML5") else { continue }
            let userAgent = AVPlayerViewModel.userAgent(forStreamURL: muxedURL)
            let asset = AVURLAsset(url: muxedURL,
                                   options: ["AVURLAssetHTTPHeaderFieldsKey": ["User-Agent": userAgent]])
            Log.info("[AVPlayerView] prefetch built asset (muxed/\(hit.client)): \(videoId)")
            return PrefetchResult(videoId: videoId, asset: asset,
                                  playerInfo: hit.info, headers: [:],
                                  originalAudioLanguage: hit.info.originalAudioLanguage,
                                  isWebViewHLS: false, masterURL: nil, nSolver: nil,
                                  poToken: nil, proxyLoader: nil, audioTracks: [],
                                  qualities: StreamQualityHelper.videoQualities(from: hit.info, muxedOnly: true))
        }

        Log.info("[AVPlayerView] prefetch found no playable stream: \(videoId)")
        return nil
    }

    /// Fires the same InnerTube clients as `AVPlayerViewModel.exhaustiveRetry`, in parallel,
    /// and returns every success ordered by preference (lower = preferred).
    ///
    /// Deliberately a separate implementation rather than a shared helper: `exhaustiveRetry`
    /// is kept structurally aligned with upstream SmartTubeIOS so syncs stay a straight
    /// diff-and-apply, and it plays items as they arrive — which a prefetch must not do.
    /// A single pass only; when it comes up empty the normal load path runs as usual.
    private func fetchAllClients(videoId: String) async -> [ClientResult] {
        let api = self.api
        var results: [ClientResult] = []

        await withTaskGroup(of: Optional<ClientResult>.self) { group in
            group.addTask {
                (try? await retryWithBackoff(label: "prefetch/MWEB") {
                    try await api.fetchPlayerInfoMWEB(videoId: videoId)
                }).map { ClientResult(priority: 1, client: "MWEB", info: $0) }
            }
            group.addTask {
                (try? await retryWithBackoff(label: "prefetch/TVEmbedded") {
                    try await api.fetchPlayerInfoTVEmbedded(videoId: videoId)
                }).map { ClientResult(priority: 2, client: "TVEmbedded", info: $0) }
            }
            group.addTask {
                (try? await retryWithBackoff(label: "prefetch/WebSafari") {
                    try await api.fetchPlayerInfoWebSafari(videoId: videoId)
                }).map { ClientResult(priority: 3, client: "WebSafari", info: $0) }
            }
            group.addTask {
                (try? await retryWithBackoff(label: "prefetch/iOS") {
                    try await api.fetchPlayerInfo(videoId: videoId)
                }).map { ClientResult(priority: 4, client: "iOS", info: $0) }
            }
            group.addTask {
                (try? await retryWithBackoff(label: "prefetch/Android") {
                    try await api.fetchPlayerInfoAndroid(videoId: videoId)
                }).map { ClientResult(priority: 5, client: "Android", info: $0) }
            }
            group.addTask {
                (try? await retryWithBackoff(label: "prefetch/AndroidVR") {
                    try await api.fetchPlayerInfoAndroidVR(videoId: videoId)
                }).map { ClientResult(priority: 6, client: "AndroidVR", info: $0) }
            }

            for await maybe in group {
                if Task.isCancelled { group.cancelAll(); return }
                if let hit = maybe { results.append(hit) }
            }
        }

        results.sort { $0.priority < $1.priority }
        return results
    }

    private func buildWebViewHLSResult(url: URL, nSolver: (unsolved: String, solved: String)?,
                                       poToken: String? = nil, originalAudioLanguage: String,
                                       videoId: String, playerInfo: PlayerInfo? = nil) async -> PrefetchResult? {
        let ua = WKHLSManager.desktopSafariUA
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue(ua, forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let manifestText = String(data: data, encoding: .utf8), !manifestText.isEmpty else {
            Log.info("[AVPlayerView] prefetch wkHLS manifest probe failed: \(videoId)")
            return nil
        }
        guard let proxyURL = url.proxyURL else { return nil }
        let proxyLoader = YTHLSProxyLoader(ua: ua, nSolver: nSolver, poToken: poToken)
        let asset = AVURLAsset(url: proxyURL)
        asset.resourceLoader.setDelegate(proxyLoader, queue: .global(qos: .userInitiated))
        let qualities = StreamQualityHelper.qualitiesFromHLSManifest(manifestText)
        let audioTracks = parseHLSAudioLanguages(from: manifestText)
        Log.info("[AVPlayerView] prefetch built asset (wkHLS): \(videoId)")
        return PrefetchResult(videoId: videoId, asset: asset,
                              playerInfo: playerInfo, headers: [:],
                              originalAudioLanguage: originalAudioLanguage,
                              isWebViewHLS: true, masterURL: url, nSolver: nSolver,
                              poToken: poToken, proxyLoader: proxyLoader, audioTracks: audioTracks,
                              qualities: qualities)
    }
}
#endif
