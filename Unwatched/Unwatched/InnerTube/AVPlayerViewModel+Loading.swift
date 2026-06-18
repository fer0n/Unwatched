#if !os(macOS)
import AVKit
import OSLog
import SwiftUI
import UnwatchedShared
import WebKit

extension AVPlayerViewModel {

    // MARK: - Entry point

    /// Loads and plays `videoId`. Mirrors SmartTubeIOS's playback strategy adapted for Unwatched:
    ///   1. Fast path — a cached WKWebView HLS URL from a prior extraction / prefetch.
    ///   2. Primary race — iOS client HLS vs. an in-flight WKWebView extraction (Unwatched's
    ///      lightweight stand-in for upstream's BotGuard race; needs no extra infrastructure).
    ///   3. `exhaustiveRetry` — the 3-attempt loop that fetches ~6 InnerTube clients in parallel,
    ///      plays the first HLS to arrive, then adaptive in priority order, then muxed.
    ///
    /// `useAndroidFallback` is retained for the mid-playback recovery path; when set, the front
    /// race is skipped and we go straight to the exhaustive parallel retry.
    @MainActor
    func fetchAndPlay(videoId: String, useAndroidFallback: Bool = false) async {
        Log.info("[AVPlayerView] fetchAndPlay: \(videoId) android=\(useAndroidFallback)")

        if !useAndroidFallback,
           let cached = WKHLSManager.shared.validEntry(for: videoId) {
            Log.info("[AVPlayerView] wkHLS: cache hit for \(videoId)")
            if await playWebViewHLS(url: cached.url, nSolver: cached.nSolver, poToken: cached.poToken, videoId: videoId) {
                return
            }
        }

        if !useAndroidFallback {
            if await primaryRace(videoId: videoId) { return }
            if Task.isCancelled { return }
        }

        await exhaustiveRetry(videoId: videoId)
    }

    // MARK: - Primary race (iOS client HLS vs WKWebView extraction)

    /// Starts WKWebView HLS extraction in parallel with the iOS client fetch. If iOS returns HLS,
    /// that plays immediately and the extractor is cancelled. Otherwise the in-progress extraction
    /// (already ~1–2 s in) is awaited and played. Returns `true` if a stream reached `.readyToPlay`.
    @MainActor
    func primaryRace(videoId: String) async -> Bool {
        let webViewTask = Task { await YouTubeWebViewHLSExtractor.shared.extractHLSURL(videoId: videoId) }

        let info: PlayerInfo
        do {
            info = try await retryWithBackoff(label: "iOS-primary") {
                try await self.api.fetchPlayerInfo(videoId: videoId)
            }
        } catch {
            // IP-block / sign-in / transient: let exhaustiveRetry surface a precise error.
            YouTubeWebViewHLSExtractor.shared.cancel()
            webViewTask.cancel()
            Log.error("[AVPlayerView] primary iOS fetch failed: \(videoId) — \(error.localizedDescription)")
            return false
        }

        if info.hlsURL != nil {
            YouTubeWebViewHLSExtractor.shared.cancel()
            webViewTask.cancel()
            return await tryHLS(videoId: videoId, info: info, client: "iOS")
        }

        // iOS has no HLS — await the in-progress WKWebView extraction.
        Log.info("[AVPlayerView] iOS has no HLS — awaiting WKWebView extraction: \(videoId)")
        let webViewURL = await webViewTask.value
        if Task.isCancelled { return false }

        let pot = YouTubeWebViewHLSExtractor.shared.extractedPoToken
        let nSolver = YouTubeWebViewHLSExtractor.shared.extractedNSolver
        if let pot { await api.storeExternalPoToken(pot, for: videoId) }
        if let url = webViewURL {
            WKHLSManager.shared.store(url: url, nSolver: nSolver, for: videoId)
            originalAudioLanguage = info.originalAudioLanguage
            applyTranscriptUrl(from: info)
            if await playWebViewHLS(url: url, nSolver: nSolver, poToken: pot, videoId: videoId) {
                return true
            }
        }
        return false
    }

    // MARK: - Exhaustive parallel retry

    /// The new spine, mirroring SmartTubeIOS `exhaustiveRetry`'s attempt loop (lines 241-454):
    /// repeat up to 3 times, each attempt firing all clients in parallel. HLS results are played
    /// immediately as they arrive (first success wins); adaptive-only results are queued and tried
    /// in priority order; muxed is the last resort. IP-block short-circuits the whole loop.
    @MainActor
    func exhaustiveRetry(videoId: String) async {
        struct FetchResult: @unchecked Sendable {
            let priority: Int
            let client: String
            let info: PlayerInfo
        }
        enum FetchOutcome: @unchecked Sendable {
            case result(FetchResult)
            case ipBlocked(Error)
        }

        let api = self.api

        for attempt in 1...3 {
            guard !Task.isCancelled, player.video?.youtubeId == videoId else { return }
            Log.info("[AVPlayerView] exhaustiveRetry \(attempt)/3: \(videoId)")

            var pendingNonHLS: [FetchResult] = []
            var androidInfoForMuxed: PlayerInfo?
            var ipBlockError: Error?
            var played = false

            // Fire all clients concurrently. Each fetch survives transient network blips via
            // retryWithBackoff; iOS/Android additionally surface APIError.ipBlocked.
            // Priority (lower = preferred): MWEB, TVEmbedded, WebSafari, iOS, Android, AndroidVR.
            await withTaskGroup(of: Optional<FetchOutcome>.self) { group in
                group.addTask {
                    (try? await retryWithBackoff(label: "MWEB[\(attempt)]") {
                        try await api.fetchPlayerInfoMWEB(videoId: videoId)
                    }).map { .result(FetchResult(priority: 1, client: "MWEB", info: $0)) }
                }
                group.addTask {
                    (try? await retryWithBackoff(label: "TVEmbedded[\(attempt)]") {
                        try await api.fetchPlayerInfoTVEmbedded(videoId: videoId)
                    }).map { .result(FetchResult(priority: 2, client: "TVEmbedded", info: $0)) }
                }
                group.addTask {
                    (try? await retryWithBackoff(label: "WebSafari[\(attempt)]") {
                        try await api.fetchPlayerInfoWebSafari(videoId: videoId)
                    }).map { .result(FetchResult(priority: 3, client: "WebSafari", info: $0)) }
                }
                group.addTask {
                    do {
                        let info = try await retryWithBackoff(label: "iOS[\(attempt)]") {
                            try await api.fetchPlayerInfo(videoId: videoId)
                        }
                        return .result(FetchResult(priority: 4, client: "iOS", info: info))
                    } catch {
                        if case APIError.ipBlocked = error { return .ipBlocked(error) }
                        return nil
                    }
                }
                group.addTask {
                    do {
                        let info = try await retryWithBackoff(label: "Android[\(attempt)]") {
                            try await api.fetchPlayerInfoAndroid(videoId: videoId)
                        }
                        return .result(FetchResult(priority: 5, client: "Android", info: info))
                    } catch {
                        if case APIError.ipBlocked = error { return .ipBlocked(error) }
                        return nil
                    }
                }
                group.addTask {
                    (try? await retryWithBackoff(label: "AndroidVR[\(attempt)]") {
                        try await api.fetchPlayerInfoAndroidVR(videoId: videoId)
                    }).map { .result(FetchResult(priority: 6, client: "AndroidVR", info: $0)) }
                }

                for await maybe in group {
                    guard let outcome = maybe else { continue }
                    switch outcome {
                    case .ipBlocked(let err):
                        ipBlockError = err
                        group.cancelAll()
                        return
                    case .result(let r):
                        if r.client == "Android" { androidInfoForMuxed = r.info }
                        if r.info.hlsURL != nil {
                            // HLS present → try immediately; first success wins.
                            if await tryAllStreams(videoId: videoId, info: r.info,
                                                   client: r.client, label: "\(r.client)[\(attempt)]",
                                                   skipMuxed: true) {
                                played = true
                                group.cancelAll()
                                return
                            }
                        } else {
                            pendingNonHLS.append(r)
                        }
                    }
                }
            }

            if played { return }

            if let ipBlockError {
                Log.error("[AVPlayerView] IP blocked during parallel fetch: \(videoId)")
                player.isLoading = nil
                loadError = ipBlockError
                return
            }
            guard !Task.isCancelled, player.video?.youtubeId == videoId else { return }

            // Adaptive-only results, in priority order. AndroidVR is deferred when a muxed
            // fallback exists — muxed plays instantly and backgroundQualityUpgrade retries VR.
            pendingNonHLS.sort { $0.priority < $1.priority }
            let hasMuxedFallback = androidInfoForMuxed?.bestMuxedDownloadURL != nil
            for candidate in pendingNonHLS {
                guard !Task.isCancelled, player.video?.youtubeId == videoId else { return }
                if hasMuxedFallback && candidate.client == "AndroidVR" { continue }
                if await tryAllStreams(videoId: videoId, info: candidate.info,
                                       client: candidate.client, label: "\(candidate.client)[\(attempt)]",
                                       skipMuxed: true) {
                    return
                }
            }

            guard !Task.isCancelled, player.video?.youtubeId == videoId else { return }

            // Muxed direct MP4 (360p last resort). On success, upgrade quality in the background.
            if let androidInfo = androidInfoForMuxed, androidInfo.bestMuxedDownloadURL != nil {
                if await tryAllStreams(videoId: videoId, info: androidInfo,
                                       client: "Android", label: "Android[\(attempt)]/muxed",
                                       skipMuxed: false) {
                    let upgradeId = videoId
                    let fallback = androidInfo
                    backgroundQualityUpgradeTask?.cancel()
                    backgroundQualityUpgradeTask = Task { await self.backgroundQualityUpgrade(videoId: upgradeId, fallbackInfo: fallback) }
                    return
                }
            }
        }

        guard !Task.isCancelled, player.video?.youtubeId == videoId else { return }
        Log.error("[AVPlayerView] all retry attempts exhausted: \(videoId)")
        player.isLoading = nil
        loadError = APIError.unavailable("Unable to play this video")
    }

    /// Tries HLS → adaptive composition → (optionally) muxed from one `PlayerInfo`.
    /// Returns `true` as soon as a stream reaches `.readyToPlay`.
    @MainActor
    func tryAllStreams(videoId: String, info: PlayerInfo, client: String,
                       label: String, skipMuxed: Bool) async -> Bool {
        Log.info("[AVPlayerView] \(label): HLS=\(info.hlsURL != nil) adaptiveV=\(info.bestAdaptiveVideoURL != nil) muxed=\(info.bestMuxedDownloadURL != nil) skipMuxed=\(skipMuxed)")

        // 1. HLS — native AVPlayer ABR, alternate audio renditions.
        if info.hlsURL != nil {
            if await tryHLS(videoId: videoId, info: info, client: client) { return true }
            if Task.isCancelled || player.video?.youtubeId != videoId { return false }
        }

        // 2. Adaptive composition (video-only + audio-only).
        if info.bestAdaptiveVideoURL != nil, info.bestAdaptiveAudioURL != nil {
            let isVR = client == "AndroidVR"
            if info.containsSabrFormats {
                Log.info("[AVPlayerView] \(label): adaptive URLs are SABR (c=TVHTML5) — skipping composition")
            } else if info.containsRqhAdaptiveFormats && !isVR {
                // rqh=1 stalls loadTracks unless the client is CDN-exempt (AndroidVR).
                Log.info("[AVPlayerView] \(label): adaptive URLs are rqh=1 and client not CDN-exempt — skipping composition")
            } else {
                if await playAdaptiveComposition(videoId: videoId, info: info) { return true }
                if Task.isCancelled || player.video?.youtubeId != videoId { return false }
            }
        }

        // 3. Muxed direct MP4 (last resort).
        if !skipMuxed {
            if await tryMuxed(videoId: videoId, info: info, client: client) { return true }
        }

        return false
    }

    // MARK: - Stream attempts

    /// Plays the HLS manifest from `info`. UA mirrors SmartTubeIOS's two playback paths:
    ///  • iOS client HLS → Chrome/Web UA unlocks higher-quality variants
    ///  • WebSafari HLS  → Safari macOS UA (CDN validates it)
    ///  • all other HLS  → iOS UA
    @MainActor
    func tryHLS(videoId: String, info: PlayerInfo, client: String) async -> Bool {
        guard let hlsURL = info.hlsURL else { return false }
        let hlsUA: String
        switch client {
        case "WebSafari": hlsUA = InnerTubeClients.WebSafari.userAgent
        case "iOS":       hlsUA = InnerTubeClients.Web.userAgent
        default:          hlsUA = InnerTubeClients.iOS.userAgent
        }
        let headers = [
            "User-Agent": hlsUA,
            "Origin": "https://www.youtube.com",
            "Referer": "https://www.youtube.com/"
        ]
        let asset = AVURLAsset(url: hlsURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let item = AVPlayerItem(asset: asset)
        let qualities = StreamQualityHelper.videoQualities(from: info, muxedOnly: false)

        originalAudioLanguage = info.originalAudioLanguage
        currentPlayerInfo = info
        currentHLSHeaders = headers
        isUsingComposition = false
        isUsingWebViewHLS = false
        player.availableVideoQualities = qualities
        applyTranscriptUrl(from: info)
        applyAspectRatioFromFormats(info)

        return await attemptItem(item, videoId: videoId)
    }

    /// Composes a video-only + audio-only adaptive stream pair via `AVMutableComposition`.
    /// VP9 is excluded (decode failures on some Apple hardware) and H.264 preferred.
    @MainActor
    func playAdaptiveComposition(videoId: String, info: PlayerInfo) async -> Bool {
        let videoURL: URL? = {
            let candidates = info.formats.filter {
                $0.mimeType.hasPrefix("video/mp4") &&
                !$0.mimeType.contains(", ") &&
                !$0.mimeType.contains("vp09") &&
                $0.url != nil
            }
            return candidates.sorted { lhs, rhs in
                let lH264 = lhs.mimeType.contains("avc1")
                let rH264 = rhs.mimeType.contains("avc1")
                if lH264 != rH264 { return lH264 }
                return (lhs.bitrate ?? 0) > (rhs.bitrate ?? 0)
            }.first?.url
        }()
        guard let videoURL, let audioURL = info.bestAdaptiveAudioURL else { return false }

        Log.info("[AVPlayerView] adaptive composition starting: \(videoId)")
        let ua = Self.userAgent(forStreamURL: videoURL)
        let videoAsset = AVURLAsset(url: videoURL, options: ["AVURLAssetHTTPHeaderFieldsKey": ["User-Agent": ua]])
        let audioAsset = AVURLAsset(url: audioURL, options: ["AVURLAssetHTTPHeaderFieldsKey": ["User-Agent": ua]])

        do {
            // 8-second timeout: rqh=1 CDN enforcement can stall loadTracks indefinitely.
            struct TrackPair: @unchecked Sendable {
                let video: [AVAssetTrack]
                let audio: [AVAssetTrack]
            }
            let (trackStream, trackCont) = AsyncStream<TrackPair?>.makeStream()
            let capturedVideo = videoAsset
            let capturedAudio = audioAsset
            Task.detached {
                if let v = try? await capturedVideo.loadTracks(withMediaType: .video),
                   let a = try? await capturedAudio.loadTracks(withMediaType: .audio) {
                    trackCont.yield(TrackPair(video: v, audio: a))
                } else {
                    trackCont.yield(nil)
                }
                trackCont.finish()
            }
            Task.detached {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                trackCont.yield(nil)
                trackCont.finish()
            }
            guard let pairOrNil = await trackStream.first(where: { _ in true }),
                  let pair = pairOrNil else {
                Log.error("[AVPlayerView] adaptive composition: loadTracks timed out or failed: \(videoId)")
                return false
            }

            guard let sourceVideo = pair.video.first, let sourceAudio = pair.audio.first else {
                Log.error("[AVPlayerView] adaptive composition: missing video or audio track: \(videoId)")
                return false
            }

            let duration = try await videoAsset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: duration)

            let composition = AVMutableComposition()
            guard let compVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                  let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                Log.error("[AVPlayerView] adaptive composition: could not add tracks: \(videoId)")
                return false
            }

            try compVideo.insertTimeRange(timeRange, of: sourceVideo, at: .zero)
            try compAudio.insertTimeRange(timeRange, of: sourceAudio, at: .zero)

            if Task.isCancelled { return false }

            Log.info("[AVPlayerView] adaptive composition built: \(videoId)")
            let item = AVPlayerItem(asset: composition)
            let qualities = StreamQualityHelper.videoQualities(from: info)
            originalAudioLanguage = info.originalAudioLanguage
            currentPlayerInfo = info
            isUsingComposition = true
            isUsingWebViewHLS = false
            player.availableVideoQualities = qualities
            applyTranscriptUrl(from: info)
            applyAspectRatioFromFormats(info)
            return await attemptItem(item, videoId: videoId)
        } catch {
            if Task.isCancelled { return false }
            Log.error("[AVPlayerView] adaptive composition failed: \(videoId) — \(error.localizedDescription)")
            return false
        }
    }

    /// Plays the muxed (combined video+audio) MP4 — 360p last resort.
    @MainActor
    func tryMuxed(videoId: String, info: PlayerInfo, client: String) async -> Bool {
        guard let muxedURL = info.bestMuxedDownloadURL else { return false }
        // TVHTML5 SABR-protocol URLs serve binary data, not a playable MP4 (AVPlayer -11828).
        if muxedURL.absoluteString.contains("c=TVHTML5") {
            Log.info("[AVPlayerView] skipping SABR muxed URL (c=TVHTML5): \(videoId)")
            return false
        }
        let ua = Self.userAgent(forStreamURL: muxedURL)
        let asset = AVURLAsset(url: muxedURL, options: ["AVURLAssetHTTPHeaderFieldsKey": ["User-Agent": ua]])
        let item = AVPlayerItem(asset: asset)
        let qualities = StreamQualityHelper.videoQualities(from: info, muxedOnly: true)

        originalAudioLanguage = info.originalAudioLanguage
        currentPlayerInfo = info
        currentHLSHeaders = [:]
        isUsingComposition = false
        isUsingWebViewHLS = false
        player.availableVideoQualities = qualities
        applyTranscriptUrl(from: info)
        applyAspectRatioFromFormats(info)

        return await attemptItem(item, videoId: videoId)
    }

    // MARK: - Background quality upgrade

    /// After a low-quality muxed (360p) stream starts playing, fetch an HLS manifest in the
    /// background (TVEmbedded → MWEB) and swap the item at the current position so the user sees
    /// no gap. If the upgrade fails to play, the muxed fallback is restored. Mirrors
    /// SmartTubeIOS `backgroundQualityUpgrade`.
    @MainActor
    func backgroundQualityUpgrade(videoId: String, fallbackInfo: PlayerInfo) async {
        try? await Task.sleep(nanoseconds: 700_000_000)   // let readyToPlay fire first
        guard !Task.isCancelled, player.video?.youtubeId == videoId else { return }

        var upgradeInfo: PlayerInfo?
        if let tv = try? await retryWithBackoff(label: "upgrade/TVEmbedded", {
            try await self.api.fetchPlayerInfoTVEmbedded(videoId: videoId)
        }), tv.hlsURL != nil {
            upgradeInfo = tv
        } else if let mw = try? await retryWithBackoff(label: "upgrade/MWEB", {
            try await self.api.fetchPlayerInfoMWEB(videoId: videoId)
        }), mw.hlsURL != nil {
            upgradeInfo = mw
        }

        guard !Task.isCancelled, player.video?.youtubeId == videoId else { return }
        guard let upgradeInfo else {
            Log.info("[AVPlayerView] no HLS quality upgrade available — staying on muxed: \(videoId)")
            return
        }

        let pos = avPlayer.currentTime().seconds
        let resume = (pos > 0.5 && !pos.isNaN && !pos.isInfinite) ? pos : nil
        pendingSeekToTime = resume
        Log.info("[AVPlayerView] attempting background HLS quality upgrade: \(videoId)")
        if await tryHLS(videoId: videoId, info: upgradeInfo, client: "TVEmbedded") { return }

        // Upgrade failed — restore the muxed fallback at the saved position.
        Log.info("[AVPlayerView] HLS upgrade failed — restoring muxed fallback: \(videoId)")
        pendingSeekToTime = resume
        _ = await tryMuxed(videoId: videoId, info: fallbackInfo, client: "Android")
    }

    // MARK: - WKWebView HLS playback

    @MainActor
    func playWebViewHLS(url: URL, nSolver: (unsolved: String, solved: String)?, poToken: String?, videoId: String) async -> Bool {
        Log.info("[AVPlayerView] wkHLS: probing manifest: \(videoId)")
        let ua = WKHLSManager.desktopSafariUA
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue(ua, forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let manifestText = String(data: data, encoding: .utf8),
              !manifestText.isEmpty else {
            Log.error("[AVPlayerView] wkHLS: manifest fetch failed: \(videoId)")
            return false
        }

        guard let proxyURL = url.proxyURL else { return false }
        let proxyLoader = YTHLSProxyLoader(ua: ua, nSolver: nSolver, poToken: poToken)
        let asset = AVURLAsset(url: proxyURL)
        asset.resourceLoader.setDelegate(proxyLoader, queue: .global(qos: .userInitiated))

        let item = AVPlayerItem(asset: asset)
        let qualities = StreamQualityHelper.qualitiesFromHLSManifest(manifestText)
        let audioTracks = parseHLSAudioLanguages(from: manifestText)

        currentPlayerInfo = nil
        currentHLSHeaders = [:]
        isUsingComposition = false
        isUsingWebViewHLS = true
        webViewHLSMasterURL = url
        webViewHLSNSolver = nSolver
        webViewHLSPoToken = poToken
        webViewHLSProxyLoader = proxyLoader
        webViewHLSSelectedContentID = nil  // default = original audio
        webViewHLSAudioContentIDs = Dictionary(uniqueKeysWithValues: audioTracks.map { ($0.languageCode, $0.contentID) })
        player.availableVideoQualities = qualities
        if !audioTracks.isEmpty {
            player.availableAudioLanguages = audioTracks.map { (code: $0.languageCode, name: $0.name) }
            player.selectedAudioLanguage = audioTracks.first(where: \.isOriginal)?.languageCode
                ?? audioTracks.first?.languageCode
                ?? ""
        }
        return await attemptItem(item, videoId: videoId)
    }

    // MARK: - Item lifecycle

    /// Replaces the current item and awaits its first terminal status. Returns `true` on
    /// `.readyToPlay` (running success side-effects and installing the ongoing observers),
    /// `false` on `.failed`, timeout, or cancellation. This is the loop's per-stream primitive —
    /// the equivalent of SmartTubeIOS's `attemptURL` awaiting `readyToPlay` before reporting success.
    @MainActor
    func attemptItem(_ item: AVPlayerItem, videoId: String, timeout: Double = 18) async -> Bool {
        guard player.video?.youtubeId == videoId, !Task.isCancelled else { return false }
        statusObserverTask?.cancel()
        setupSecondaryObservers(item: item, videoId: videoId)
        Log.info("[AVPlayerView] attemptItem replaceCurrentItem: \(videoId)")
        avPlayer.replaceCurrentItem(with: item)

        let played: Bool = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let resumer = ResumeOnce(cont)
            let obsTask = Task { @MainActor in
                for await status in self.statusStream(for: item) {
                    if Task.isCancelled { resumer.resume(false); return }
                    switch status {
                    case .readyToPlay:
                        resumer.resume(true); return
                    case .failed:
                        Log.error("[AVPlayerView] attemptItem failed: \(videoId) — \(item.error?.localizedDescription ?? "unknown")")
                        resumer.resume(false); return
                    default:
                        continue
                    }
                }
                resumer.resume(false)
            }
            statusObserverTask = obsTask
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if resumer.resume(false) {
                    Log.info("[AVPlayerView] attemptItem timed out (\(Int(timeout))s): \(videoId)")
                    obsTask.cancel()
                }
            }
        }

        guard played, player.video?.youtubeId == videoId, !Task.isCancelled else { return false }
        await handleReadyToPlay(item: item, videoId: videoId)
        startFailureObserver(item: item, videoId: videoId)
        return true
    }

    /// Long-lived observers that stay valid for the item's whole lifetime: presentation size
    /// (aspect ratio) and play-to-end.
    @MainActor
    func setupSecondaryObservers(item: AVPlayerItem, videoId: String) {
        presentationSizeObserver?.invalidate()
        presentationSizeObserver = item.observe(\.presentationSize, options: [.new]) { [weak self] _, change in
            guard let size = change.newValue, size.width > 0, size.height > 0 else { return }
            Task { @MainActor [weak self] in
                self?.player.handleAspectRatio(size.width / size.height)
            }
        }
        endObserverTask?.cancel()
        endObserverTask = Task {
            let notifications = NotificationCenter.default.notifications(
                named: AVPlayerItem.didPlayToEndTimeNotification,
                object: item
            )
            for await _ in notifications {
                guard !Task.isCancelled else { return }
                await MainActor.run { onVideoEnded() }
            }
        }
    }

    /// Success side-effects, shared by `attemptItem` (loop) and `startObservingItem`
    /// (quality / language / prefetch paths).
    @MainActor
    func handleReadyToPlay(item: AVPlayerItem, videoId: String) async {
        Log.info("[AVPlayerView] AVPlayerItem readyToPlay: \(videoId)")
        await selectOriginalAudioTrack(for: item)
        Log.info("[AVPlayerView] clearing isLoading (readyToPlay): \(videoId)")
        player.isLoading = nil
        withAnimation { player.unstarted = false }
        let size = avPlayer.currentItem?.presentationSize ?? .zero
        if size.width > 0 && size.height > 0 {
            player.handleAspectRatio(size.width / size.height)
        }
        if let t = pendingSeekToTime, t > 0, !t.isNaN, !t.isInfinite {
            avPlayer.seek(to: CMTime(seconds: t, preferredTimescale: 600),
                          toleranceBefore: .zero, toleranceAfter: .zero) { _ in }
            pendingSeekToTime = nil
        } else {
            let startPos = player.getStartPosition()
            if startPos > 1 {
                avPlayer.seek(to: CMTime(seconds: startPos, preferredTimescale: 600)) { _ in }
            }
        }
        player.handleAutoStart(nil)
        syncPlayPause(persistTime: false)
        updateNowPlayingInfo()
        let dur = avPlayer.currentItem?.duration.seconds
        if let dur, !dur.isNaN, !dur.isInfinite, dur > 0, let video = player.video {
            VideoService.updateDuration(video, duration: dur)
            ChapterService.updateDuration(video, duration: dur)
        }
        player.handleChapterRefresh()
    }

    /// Post-success status observer: catches a mid-playback `.failed` (e.g. an expired/403
    /// segment) and routes it through the recovery policy.
    @MainActor
    func startFailureObserver(item: AVPlayerItem, videoId: String) {
        statusObserverTask?.cancel()
        statusObserverTask = Task { @MainActor in
            for await status in self.statusStream(for: item) {
                if Task.isCancelled { return }
                if status == .failed {
                    Log.error("[AVPlayerView] item failed during playback: \(videoId) — \(item.error?.localizedDescription ?? "unknown")")
                    handleItemFailure(item: item, videoId: videoId)
                    return
                }
            }
        }
    }

    /// Observer used by non-loop callers (quality switch, language switch, prefetch). Owns both
    /// the readyToPlay side-effects and failure recovery for items it didn't await inline.
    @MainActor
    func startObservingItem(_ item: AVPlayerItem, videoId: String) {
        Log.info("[AVPlayerView] startObservingItem: \(videoId)")
        setupSecondaryObservers(item: item, videoId: videoId)
        statusObserverTask?.cancel()
        statusObserverTask = Task { @MainActor in
            for await status in self.statusStream(for: item) {
                if Task.isCancelled { return }
                switch status {
                case .readyToPlay:
                    await handleReadyToPlay(item: item, videoId: videoId)
                case .failed:
                    Log.error("[AVPlayerView] AVPlayerItem failed: \(videoId) — \(item.error?.localizedDescription ?? "unknown")")
                    handleItemFailure(item: item, videoId: videoId)
                    return
                case .unknown:
                    continue
                @unknown default:
                    continue
                }
            }
        }
    }

    /// Classifies an item failure via `qualityRecoveryAction` and either re-fetches fresh
    /// streams (the exhaustive parallel retry) or surfaces the error. Mirrors SmartTubeIOS's
    /// `QualityRecoveryPolicy` wiring. Guarded by `hasRetriedPlayback` to avoid loops.
    @MainActor
    func handleItemFailure(item: AVPlayerItem, videoId: String) {
        guard !hasRetriedPlayback else {
            Log.error("[AVPlayerView] retry already attempted, giving up: \(videoId)")
            player.isLoading = nil
            loadError = item.error
            return
        }
        let nsErr = (item.error as NSError?) ?? NSError(domain: "AVFoundationErrorDomain", code: 0)
        let action = qualityRecoveryAction(for: nsErr,
                                           quality: player.selectedVideoQuality,
                                           hasAppliedH264Cap: hasAppliedH264Cap)
        switch action {
        case .fail(let err):
            Log.error("[AVPlayerView] unrecoverable failure: \(videoId)")
            player.isLoading = nil
            loadError = err ?? item.error
        case .revertToAuto:
            Log.info("[AVPlayerView] quality \(player.selectedVideoQuality)p failed — reverting to Auto and retrying: \(videoId)")
            player.selectedVideoQuality = 0
            reExhaust(videoId: videoId)
        case .retry403Recovery:
            Log.info("[AVPlayerView] HTTP 403 — re-fetching fresh streams: \(videoId)")
            reExhaust(videoId: videoId)
        case .retryWithH264Cap:
            Log.info("[AVPlayerView] H.264 decode error — retrying (H.264/avc1 preferred): \(videoId)")
            hasAppliedH264Cap = true
            reExhaust(videoId: videoId)
        }
    }

    @MainActor
    private func reExhaust(videoId: String) {
        hasRetriedPlayback = true
        player.isLoading = Date()
        loadTask?.cancel()
        loadTask = Task { await self.exhaustiveRetry(videoId: videoId) }
    }

    // MARK: - Observation

    func statusStream(for item: AVPlayerItem) -> AsyncStream<AVPlayerItem.Status> {
        AsyncStream { continuation in
            let token = item.observe(\.status, options: [.initial, .new]) { _, _ in
                continuation.yield(item.status)
            }
            continuation.onTermination = { _ in token.invalidate() }
        }
    }

    // MARK: - Helpers

    /// Picks the UA matching the URL's signing client (the `c=` query param), so the CDN
    /// accepts adaptive/muxed segment requests. Mirrors SmartTubeIOS's per-URL UA selection.
    static func userAgent(forStreamURL url: URL) -> String {
        let client = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "c" })?.value?.uppercased() ?? ""
        switch client {
        case "ANDROID_VR":          return InnerTubeClients.AndroidVR.userAgent
        case "ANDROID":             return InnerTubeClients.Android.userAgent
        case "MWEB":                return InnerTubeClients.MWEB.userAgent
        case "WEB", "WEB_CREATOR":  return InnerTubeClients.Web.userAgent
        case "TVHTML5":             return InnerTubeClients.TV.userAgent
        default:                    return InnerTubeClients.iOS.userAgent
        }
    }

    @MainActor
    func applyAspectRatioFromFormats(_ info: PlayerInfo) {
        guard let fmt = info.formats.first(where: { $0.mimeType.hasPrefix("video/") && $0.width > 0 && $0.height > 0 }) else { return }
        player.handleAspectRatio(Double(fmt.width) / Double(fmt.height))
    }

    // MARK: - Playback sync

    @MainActor
    func syncPlayPause(persistTime: Bool = true) {
        if player.isPlaying {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try? AVAudioSession.sharedInstance().setActive(true)
            avPlayer.rate = Float(player.playbackSpeed)
        } else {
            avPlayer.pause()
            if persistTime {
                let t = avPlayer.currentTime().seconds
                if !t.isNaN && !t.isInfinite {
                    player.updateElapsedTime(t)
                    if let videoId = player.video?.youtubeId {
                        StatsService.shared.handleVideoTimeUpdate(videoId: videoId, time: t)
                    }
                }
            }
        }
    }
}

/// Guards a `CheckedContinuation` so the readyToPlay/failed observer and the timeout race to
/// resume it exactly once. Both resume on the main actor, so a plain flag suffices.
@MainActor
private final class ResumeOnce {
    private var cont: CheckedContinuation<Bool, Never>?
    init(_ cont: CheckedContinuation<Bool, Never>) { self.cont = cont }

    /// Resumes the continuation. Returns `true` if this call actually resumed it (i.e. it won
    /// the race), `false` if it had already been resumed.
    @discardableResult
    func resume(_ value: Bool) -> Bool {
        guard let cont else { return false }
        self.cont = nil
        cont.resume(returning: value)
        return true
    }
}
#endif
