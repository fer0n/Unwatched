#if !os(macOS)
import AVKit
import OSLog
import UnwatchedShared
import WebKit

extension AVPlayerViewModel {

    // MARK: - Audio language change

    @MainActor
    func handleAudioLanguageChange(_ lang: String) {
        guard !lang.isEmpty else { return }
        if isUsingWebViewHLS {
            // WKWebView HLS: audio is encoded per-variant via YT-EXT-AUDIO-CONTENT-ID,
            // not via #EXT-X-MEDIA groups, so AVFoundation can't switch tracks without
            // reloading the item. Rebuild the proxy with the new content ID filter.
            if let entry = webViewHLSAudioContentIDs[lang] {
                webViewHLSSelectedContentID = entry
            } else {
                webViewHLSSelectedContentID = nil
            }
            reloadWebViewHLSForLanguage()
            return
        }
        guard let item = avPlayer.currentItem else { return }
        Task { await self.selectAudioTrack(lang, for: item) }
    }

    @MainActor
    private func reloadWebViewHLSForLanguage() {
        guard let masterURL = webViewHLSMasterURL,
              let proxyURL = masterURL.proxyURL else { return }
        let ua = WKHLSManager.desktopSafariUA
        let proxyLoader = YTHLSProxyLoader(ua: ua, nSolver: webViewHLSNSolver,
                                           selectedLanguageContentID: webViewHLSSelectedContentID,
                                           poToken: webViewHLSPoToken)
        let asset = AVURLAsset(url: proxyURL)
        asset.resourceLoader.setDelegate(proxyLoader, queue: .global(qos: .userInitiated))
        let item = AVPlayerItem(asset: asset)
        let height = player.selectedVideoQuality
        if height > 0 {
            item.preferredMaximumResolution = CGSize(width: Double(height) * 4, height: Double(height))
            item.preferredPeakBitRate = StreamQualityHelper.peakBitRate(for: height)
        }
        let savedTime = avPlayer.currentTime().seconds
        if savedTime > 1 { pendingSeekToTime = savedTime }
        webViewHLSProxyLoader = proxyLoader
        startObservingItem(item, videoId: player.video?.youtubeId ?? "")
        avPlayer.replaceCurrentItem(with: item)
    }

    // MARK: - Quality change

    @MainActor
    func handleQualityChange(height: Int) {
        if isUsingWebViewHLS, let masterURL = webViewHLSMasterURL {
            let ua = WKHLSManager.desktopSafariUA
            guard let proxyURL = masterURL.proxyURL else { return }
            let proxyLoader = YTHLSProxyLoader(ua: ua, nSolver: webViewHLSNSolver,
                                               selectedLanguageContentID: webViewHLSSelectedContentID,
                                               poToken: webViewHLSPoToken)
            let asset = AVURLAsset(url: proxyURL)
            asset.resourceLoader.setDelegate(proxyLoader, queue: .global(qos: .userInitiated))
            let item = AVPlayerItem(asset: asset)
            if height == 0 {
                item.preferredMaximumResolution = .zero
                item.preferredPeakBitRate = 0
            } else {
                item.preferredMaximumResolution = CGSize(width: Double(height) * 4, height: Double(height))
                item.preferredPeakBitRate = StreamQualityHelper.peakBitRate(for: height)
            }
            let savedTime = avPlayer.currentTime().seconds
            if savedTime > 1 { pendingSeekToTime = savedTime }
            webViewHLSProxyLoader = proxyLoader
            startObservingItem(item, videoId: player.video?.youtubeId ?? "")
            avPlayer.replaceCurrentItem(with: item)
        } else if isUsingComposition, let info = currentPlayerInfo {
            let savedTime = avPlayer.currentTime().seconds
            loadTask?.cancel()
            loadTask = Task {
                await self.rebuildCompositionForQuality(height: height, info: info, savedTime: savedTime)
            }
        } else if let hlsURL = currentPlayerInfo?.hlsURL {
            // HLS: must replace the item so AVPlayer renegotiates ABR from scratch.
            // Setting hints on an already-playing item does not force a quality change.
            let savedTime = avPlayer.currentTime().seconds
            let asset = AVURLAsset(url: hlsURL,
                                   options: ["AVURLAssetHTTPHeaderFieldsKey": currentHLSHeaders])
            let item = AVPlayerItem(asset: asset)
            if height == 0 {
                item.preferredMaximumResolution = .zero
                item.preferredPeakBitRate = 0
            } else {
                item.preferredMaximumResolution = CGSize(width: Double(height) * 4, height: Double(height))
                item.preferredPeakBitRate = StreamQualityHelper.peakBitRate(for: height)
            }
            if savedTime > 1 { pendingSeekToTime = savedTime }
            startObservingItem(item, videoId: player.video?.youtubeId ?? "")
            avPlayer.replaceCurrentItem(with: item)
        } else {
            guard let item = avPlayer.currentItem else { return }
            if height == 0 {
                item.preferredMaximumResolution = .zero
                item.preferredPeakBitRate = 0
            } else {
                item.preferredMaximumResolution = CGSize(width: Double(height) * 4, height: Double(height))
                item.preferredPeakBitRate = StreamQualityHelper.peakBitRate(for: height)
            }
        }
    }

    // MARK: - DASH composition quality switching

    func rebuildCompositionForQuality(height: Int, info: PlayerInfo, savedTime: Double) async {
        let videoId = await MainActor.run { player.video?.youtubeId ?? "" }
        let ua = InnerTubeClients.Android.userAgent

        // height == 0 means Auto: pick highest bitrate.
        let videoURL: URL?
        if height == 0 {
            videoURL = info.formats.filter {
                $0.mimeType.hasPrefix("video/mp4") && !$0.mimeType.contains(", ") &&
                !$0.mimeType.contains("vp09") && $0.url != nil
            }.sorted { ($0.bitrate ?? 0) > ($1.bitrate ?? 0) }.first?.url
        } else {
            videoURL = info.formats.filter {
                $0.height == height && $0.mimeType.hasPrefix("video/") &&
                !$0.mimeType.contains("vp09") && $0.url != nil
            }.sorted { ($0.bitrate ?? 0) > ($1.bitrate ?? 0) }.first?.url
        }

        guard let videoURL, let audioURL = info.bestAdaptiveAudioURL else {
            Log.error("[AVPlayerView] rebuildCompositionForQuality: no URL for height=\(height)")
            return
        }

        await MainActor.run { player.isLoading = Date() }

        let videoAsset = AVURLAsset(url: videoURL, options: ["AVURLAssetHTTPHeaderFieldsKey": ["User-Agent": ua]])
        let audioAsset = AVURLAsset(url: audioURL, options: ["AVURLAssetHTTPHeaderFieldsKey": ["User-Agent": ua]])

        do {
            async let videoTracks = videoAsset.loadTracks(withMediaType: .video)
            async let audioTracks = audioAsset.loadTracks(withMediaType: .audio)
            let (vTracks, aTracks) = try await (videoTracks, audioTracks)

            guard let sourceVideo = vTracks.first, let sourceAudio = aTracks.first else {
                Log.error("[AVPlayerView] rebuildCompositionForQuality: missing tracks: \(videoId)")
                await MainActor.run { player.isLoading = nil }
                return
            }

            let duration = try await videoAsset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: duration)

            let composition = AVMutableComposition()
            guard let compVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                  let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                await MainActor.run { player.isLoading = nil }
                return
            }

            try compVideo.insertTimeRange(timeRange, of: sourceVideo, at: .zero)
            try compAudio.insertTimeRange(timeRange, of: sourceAudio, at: .zero)

            if Task.isCancelled { return }

            Log.info("[AVPlayerView] rebuildCompositionForQuality built: \(videoId) height=\(height)")
            let item = AVPlayerItem(asset: composition)
            await MainActor.run {
                pendingSeekToTime = savedTime
                startObservingItem(item, videoId: videoId)
                avPlayer.replaceCurrentItem(with: item)
            }
        } catch {
            if Task.isCancelled { return }
            Log.error("[AVPlayerView] rebuildCompositionForQuality failed: \(videoId) height=\(height) — \(error.localizedDescription)")
            await MainActor.run { player.isLoading = nil }
        }
    }

    // MARK: - Audio track selection

    func selectOriginalAudioTrack(for item: AVPlayerItem) async {
        guard let group = try? await item.asset.loadMediaSelectionGroup(for: .audible) else { return }
        guard group.options.count > 1 else { return }

        let languages = group.options.compactMap { opt -> (code: String, name: String)? in
            guard let code = opt.locale?.languageCode else { return nil }
            return (code: code, name: opt.displayName)
        }
        let (detectedLang, currentLang) = await MainActor.run { (originalAudioLanguage, player.selectedAudioLanguage) }
        await MainActor.run { player.availableAudioLanguages = languages }

        // On a quality switch the item is replaced but the user's language choice should survive.
        if !currentLang.isEmpty,
           let existing = group.options.first(where: { $0.locale?.languageCode == currentLang }) {
            await MainActor.run { item.select(existing, in: group) }
            return
        }

        // Initial load: prefer the video's detected original language.
        if let lang = detectedLang,
           let byLang = group.options.first(where: { $0.locale?.languageCode == lang || $0.locale?.identifier == lang }) {
            Log.info("[AVPlayerView] selecting audio by lang '\(lang)': \(byLang.displayName)")
            await MainActor.run {
                item.select(byLang, in: group)
                player.selectedAudioLanguage = byLang.locale?.languageCode ?? ""
            }
            return
        }

        // Language unknown or not found — use AVFoundation characteristics to identify
        // the original (non-dubbed) track, mirroring SmartTubeIOS's approach.
        let option = originalAudioOption(in: group)
        if let option {
            Log.info("[AVPlayerView] selecting audio via characteristic detection: \(option.displayName) locale=\(option.locale?.identifier ?? "nil")")
            await MainActor.run {
                item.select(option, in: group)
                player.selectedAudioLanguage = option.locale?.languageCode ?? ""
            }
        }
    }

    private func originalAudioOption(in group: AVMediaSelectionGroup) -> AVMediaSelectionOption? {
        // Phase 1: isMainProgramContent — authoritative, but only when it discriminates.
        // YouTube sometimes sets it on every dubbed track, making it useless in that case.
        let mainContent = group.options.filter { $0.hasMediaCharacteristic(.isMainProgramContent) }
        if !mainContent.isEmpty && mainContent.count < group.options.count {
            return mainContent.first
        }
        // Phase 2: HLS DEFAULT=YES — the track the manifest marks as default.
        if let def = group.defaultOption, group.options.contains(where: { $0 === def }) {
            return def
        }
        // Phase 3: non-auxiliary — AI-dubbed tracks carry isAuxiliaryContent; the original does not.
        let nonAuxiliary = group.options.filter { !$0.hasMediaCharacteristic(.isAuxiliaryContent) }
        if nonAuxiliary.count == 1 { return nonAuxiliary.first }
        // Phase 4: YouTube appends the creator's original audio last when AI dubs are present.
        return group.options.last
    }

    private func selectAudioTrack(_ lang: String, for item: AVPlayerItem) async {
        guard let group = try? await item.asset.loadMediaSelectionGroup(for: .audible) else { return }
        let option = group.options.first { $0.locale?.languageCode == lang || $0.locale?.identifier == lang }
        if let option {
            await MainActor.run { item.select(option, in: group) }
        }
    }
}
#endif
