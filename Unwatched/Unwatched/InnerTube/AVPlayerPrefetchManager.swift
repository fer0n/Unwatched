#if !os(macOS)
import AVKit
import OSLog
import UnwatchedShared
import WebKit

// Manages background pre-building of AVPlayerItems for the next queued video.
final class AVPlayerPrefetchManager {

    struct PrefetchResult {
        let videoId: String
        let item: AVPlayerItem
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
        result = nil
        prefetchingVideoId = videoId
        prefetchTask = Task {
            let built = await buildResult(videoId: videoId)
            await MainActor.run {
                guard !Task.isCancelled, self.prefetchingVideoId == videoId else { return }
                self.result = built
                self.prefetchingVideoId = nil
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
        prefetchTask?.cancel()
        prefetchTask = nil
        prefetchingVideoId = nil
        return pre
    }

    @MainActor
    func cancelAll() {
        prefetchTask?.cancel()
        prefetchTask = nil
        prefetchingVideoId = nil
        result = nil
    }

    // MARK: - Building

    private func buildResult(videoId: String) async -> PrefetchResult? {
        Log.info("[AVPlayerView] prefetch starting: \(videoId)")

        if let cached = await MainActor.run(body: { WKHLSManager.shared.validEntry(for: videoId) }) {
            Log.info("[AVPlayerView] prefetch wkHLS cache hit: \(videoId)")
            return await buildWebViewHLSResult(url: cached.url, nSolver: cached.nSolver,
                                               poToken: cached.poToken, originalAudioLanguage: "",
                                               videoId: videoId)
        }

        let webViewTask: Task<URL?, Never> = Task {
            await YouTubeWebViewHLSExtractor.shared.extractHLSURL(videoId: videoId)
        }

        do {
            let info = try await api.fetchPlayerInfo(videoId: videoId)
            if Task.isCancelled { webViewTask.cancel(); return nil }

            if info.hlsURL != nil {
                await YouTubeWebViewHLSExtractor.shared.cancel()
                webViewTask.cancel()
            } else {
                let webViewURL = await webViewTask.value
                if Task.isCancelled { return nil }

                let (pot, nSolver) = await MainActor.run {
                    (YouTubeWebViewHLSExtractor.shared.extractedPoToken,
                     YouTubeWebViewHLSExtractor.shared.extractedNSolver)
                }
                if let pot { await api.storeExternalPoToken(pot, for: videoId) }
                if let url = webViewURL {
                    await MainActor.run {
                        WKHLSManager.shared.store(url: url, nSolver: nSolver, for: videoId)
                    }
                    return await buildWebViewHLSResult(url: url, nSolver: nSolver,
                                                       poToken: pot,
                                                       originalAudioLanguage: info.originalAudioLanguage,
                                                       videoId: videoId, playerInfo: info)
                }
                return nil
            }

            guard !Task.isCancelled, let streamURL = info.preferredStreamURL else { return nil }

            let isHLS = info.hlsURL != nil && streamURL == info.hlsURL
            let headers: [String: String] = isHLS ? [
                "User-Agent": InnerTubeClients.Web.userAgent,
                "Origin": "https://www.youtube.com",
                "Referer": "https://www.youtube.com/"
            ] : ["User-Agent": InnerTubeClients.iOS.userAgent]
            let asset = AVURLAsset(url: streamURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            let item = AVPlayerItem(asset: asset)
            let qualities = StreamQualityHelper.videoQualities(from: info, muxedOnly: !isHLS)
            Log.info("[AVPlayerView] prefetch built AVPlayerItem (iOS): \(videoId)")
            return PrefetchResult(videoId: videoId, item: item,
                                  playerInfo: info, headers: isHLS ? headers : [:],
                                  originalAudioLanguage: info.originalAudioLanguage,
                                  isWebViewHLS: false, masterURL: nil, nSolver: nil,
                                  poToken: nil, proxyLoader: nil, audioTracks: [],
                                  qualities: qualities)
        } catch {
            if !Task.isCancelled {
                Log.info("[AVPlayerView] prefetch failed for \(videoId): \(error.localizedDescription)")
            }
            return nil
        }
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
        let item = AVPlayerItem(asset: asset)
        let qualities = StreamQualityHelper.qualitiesFromHLSManifest(manifestText)
        let audioTracks = parseHLSAudioLanguages(from: manifestText)
        Log.info("[AVPlayerView] prefetch built AVPlayerItem (wkHLS): \(videoId)")
        return PrefetchResult(videoId: videoId, item: item,
                              playerInfo: playerInfo, headers: [:],
                              originalAudioLanguage: originalAudioLanguage,
                              isWebViewHLS: true, masterURL: url, nSolver: nSolver,
                              poToken: poToken, proxyLoader: proxyLoader, audioTracks: audioTracks,
                              qualities: qualities)
    }
}
#endif
