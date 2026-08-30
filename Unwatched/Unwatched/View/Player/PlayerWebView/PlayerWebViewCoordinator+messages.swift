//
//  PlayerWebViewCoordinator.swift
//  Unwatched
//

import SwiftUI
import WebKit
import OSLog
import UnwatchedShared

extension PlayerWebViewCoordinator {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func handleJsMessages(_ topic: String, _ payload: String?) {
        switch topic {
        case "pause":
            handlePause(payload)
        case "play":
            handlePlay()
        case "ended":
            flushStats()
            parent.onVideoEnded()
        case "currentTime":
            handleTimeUpdate(payload)
        case "seek":
            handleSeekTime(payload)
        case "videoData":
            handleVideoData(payload)
        case "duration":
            handleDuration(payload)
        case "playbackRate":
            handlePlaybackSpeed(payload)
        case "longTouch":
            handleLongTouchStart(payload)
            parent.autoHideVM.setKeepVisible(true, "longTouch")
        case "longTouchEnd":
            handleLongTouchEnd()
            parent.autoHideVM.setKeepVisible(false, "longTouch")
        case "interaction":
            handleInteraction()
        case "overlay":
            handleOverlay(payload)
        case "aspectRatio":
            handleAspectRatio(payload)
            handleChapters()
        case "swipe":
            handleSwipe(payload)
        case "centerTouch":
            handleCenterTouch(payload)
        case "pip":
            handlePip(payload)
        case "urlClicked":
            handleUrlClicked(payload)
        case "offline":
            handleOffline(payload)
        case "keyboardEvent":
            handleKeyboard(payload)
        case "youtubeError":
            handleError(payload, youtube: true)
        case "error":
            handleError(payload)
        case "fullscreen":
            handleFullscreen()
        case "transcriptUrl":
            handleTranscriptUrl(payload)
        case "resize":
            handleResize()
        default:
            break
        }
    }

    func handleResize() {
        #if os(iOS)
        if parent.backend.webView?.scrollView.zoomScale != 1.0 {
            parent.backend.webView?.scrollView.setZoomScale(1.0, animated: true)
        }
        #endif
    }

    func handleTranscriptUrl(_ payload: String?) {
        if let payload {
            parent.player.transcriptUrl = payload
        } else {
            parent.player.transcriptUrl = ""
        }
    }

    func handleFullscreen() {
        PlayerShortcut.toggleFullscreen.trigger()
    }

    func handleKeyboard(_ payload: String?) {
        guard let payload, !payload.isEmpty else {
            Log.warning("handleKeyboard: Empty payload")
            return
        }

        let components = payload.split(separator: "|")
        guard components.count == 5 else { return }
        let keyRaw = String(components[0])
        guard let key = PlayerShortcut.parseKey(keyRaw) else {
            Log.warning("Key not recognized: \(keyRaw)")
            return
        }

        let meta = components[1] == "true"
        let ctrl = components[2] == "true"
        let alt = components[3] == "true"
        let shift = components[4] == "true"

        var modifiers: EventModifiers = []
        if meta { modifiers.insert(.command) }
        if ctrl { modifiers.insert(.control) }
        if alt { modifiers.insert(.option) }
        if shift { modifiers.insert(.shift) }

        if let shortcut = PlayerShortcut.fromKeyCombo(key: key, modifiers: modifiers) {
            shortcut.trigger()
        } else {
            Log.info("No shortcut found to trigger for: \(keyRaw) + \(modifiers)")
        }
    }

    func handleOffline(_ payload: String?) {
        guard let payload, !payload.isEmpty else {
            return
        }
        if let date = Date.parseYtOfflineDate(payload) {
            Log.info("handleOffline: defer video to: \(date)")
            parent.player.deferVideoDate = date
            parent.player.pause()
        }
    }

    func handleUrlClicked(_ payload: String?) {
        guard let payload,
              let url = URL(string: payload) else {
            return
        }

        guard let youtubeId = UrlService.getYoutubeIdFromUrl(url: url) else {
            Log.info("handleUrlClicked: not a youtube url")
            NavigationManager.shared.openUrlInApp(.url(payload))
            return
        }
        if youtubeId == parent.player.video?.youtubeId {
            Log.info("handleUrlClicked: current video")
            return
        }

        let task = VideoService.addForeignUrls([url], in: .queue)
        parent.appNotificationVM.show(.addingVideo)
        Task {
            do {
                try await task.value
                parent.appNotificationVM.show(.addedVideo)
            } catch { }
        }
    }

    func handlePip(_ payload: String?) {
        guard let payload else {
            return
        }
        if payload == "enter" {
            parent.player.reportPip(true)
        } else if payload == "exit" {
            parent.player.reportPip(false)
        } else if payload == "canplay" {
            parent.player.canPlayPip = true
            parent.backend.handleCanPlayPip()
        }
    }

    func handleCenterTouch(_ payload: String?) {
        guard let payload else {
            return
        }
        let play = payload == "play"
        parent.overlayVM.show(play ? .pause : .play)
    }

    func handleSwipe(_ payload: String?) {
        guard let direction = payload,
              let parsed = SwipeDirecton(rawValue: direction) else {
            Log.warning("No side given for longTouch")
            return
        }
        parent.handleSwipe(parsed)
    }

    func handleAspectRatio(_ payload: String?) {
        guard let value = payload,
              let aspectRatio = Double(value) else {
            Log.warning("Aspect ratio couldn't be parsed: \(payload ?? "-")")
            return
        }
        // videoWidth/videoHeight is 0/0 while there's no video track, which the page sends as
        // "NaN"/"Infinity" — both of which `Double(_:)` happily parses.
        guard aspectRatio.isUsableAspectRatio else {
            Log.warning("Aspect ratio isn't a usable number: \(value)")
            return
        }
        parent.player.handleAspectRatio(aspectRatio)
    }

    func handleChapters() {
        Task {
            try await Task.sleep(for: .seconds(1))
            parent.backend.setChapterMarkers(force: true)
        }
    }

    func handleInteraction() {
        parent.autoHideVM.handlePlayerInteraction()
    }

    func handleOverlay(_ payload: String?) {
        guard let payload else {
            Log.warning("No payload given for handleOverlay")
            return
        }
        withAnimation(.default.speed(2)) {
            switch payload {
            case "show":
                parent.autoHideVM.setKeepVisible(true, "overlay")
            case "hide":
                parent.autoHideVM.setKeepVisible(false, "overlay")
            default:
                break
            }
        }
    }

    func handleLongTouchStart(_ payload: String?) {
        guard let side = payload else {
            Log.warning("No side given for longTouch")
            return
        }
        if side == "left" {
            parent.player.temporarySlowDown()
            return
        }
        if side == "right" {
            parent.player.temporarySpeedUp()
        }
    }

    func handleLongTouchEnd() {
        parent.player.resetTemporaryPlaybackSpeed()
    }

    func updateUnstarted() {
        Log.info("updateUnstarted")
        if parent.player.unstarted {
            withAnimation {
                parent.player.unstarted = false
            }
        }
    }

    func handlePlay() {
        updateUnstarted()
        parent.player.reportPlaying()
        #if os(iOS)
        BackgroundMonitor.handlePlay()
        #endif
    }

    func handlePause(_ payload: String?) {
        guard let payload else {
            Log.warning("No payload given for handlePause")
            return
        }
        let payloadArray = payload.split(separator: ",").map { String($0) }
        let payloadPlaybackId = payloadArray[safe: 1]
        let playbackId = UserDefaults.standard.string(forKey: Const.playbackId) ?? ""
        if payloadPlaybackId != playbackId {
            Log.info("handlePause: playbackId mismatch, not pausing")
            return
        }
        parent.player.reportPaused()

        flushStats(timeString: payloadArray[safe: 0], urlString: payloadArray[safe: 2])

        #if os(iOS)
        BackgroundMonitor.handlePause()
        #endif
    }

    func handlePlaybackSpeed(_ payload: String?) {
        guard let payload,
              let playbackRate = Double(payload),
              parent.player.playbackSpeed != playbackRate else {
            return
        }
        parent.player.playbackSpeed = playbackRate
    }

    func handleVideoData(_ payload: String?) {
        guard let payload,
              let jsonData = payload.data(using: .utf8) else {
            Log.warning("No payload given for handleTitleUpdate")
            return
        }
        let decoder = JSONDecoder()
        do {
            let result = try decoder.decode(FetchVideoData.self, from: jsonData)
            let videoId = parent.player.video?.persistentModelID
            let video = VideoService.updateVideoData(videoId, videoData: result)
            parent.player.setNextVideo(video, .hotSwap)
        } catch {
            Log.warning("couldn't decode result: \(error)")
        }
    }

    func handleDuration(_ payload: String?) {
        Log.info("handleDuration")
        guard let payload, let duration = Double(payload), duration > 0 else {
            Log.info("handleDuration: not updating")
            return
        }

        if let video = parent.player.video {
            VideoService.updateDuration(video, duration: duration)

            ChapterService.updateDuration(
                video,
                duration: duration
            )
        }
    }

    func handleError(_ payload: String?, youtube: Bool = false) {
        Log.error("video player error: \(payload ?? "Unknown")")

        // Only the embedded player reports errors — the init script's checker is behind
        // `if (!isNonEmbedding)` — and it re-checks up to 10s after load. So once a fallback is
        // up, any further error is the replaced embed still talking.
        guard youtube, !parent.player.embeddingDisabled, !retired else {
            return
        }

        #if os(iOS)
        // the embed's error text is localized, so only the native player's InnerTube fetch can say
        // *why* this failed — and hand an age gate on to the YouTube page from there
        if switchToNativePlayer() { return }
        #endif
        Log.info("videoPlayer: embedded error, switching to the YouTube page")
        parent.player.swapToWebsitePlayer()
    }

    #if os(iOS)
    /// `PlayerView` only renders `.native` on iOS, so other platforms keep the website fallback.
    /// Returns whether it took the error; `false` leaves it to the caller's website swap.
    private func switchToNativePlayer() -> Bool {
        let current = PlayerTypeSetting.stored
        // already there: the erroring embed is on its way out
        guard current != .native else { return true }
        guard PlayerManager.nativeFallbackEnabled else { return false }
        Log.info("videoPlayer: embedded error, switching to the native player")
        UserDefaults.standard.set(current.rawValue, forKey: Const.previousPlayerType)
        UserDefaults.standard.set(PlayerTypeSetting.native.rawValue, forKey: Const.playerType)
        parent.player.nativeFallbackActive = true
        PlayerSwitchManager.shared.handleSettingChanged()
        return true
    }
    #endif

    func handleTimeUpdate(_ timeString: String?, persist: Bool = false, youtubeId: String? = nil) {
        guard let timeString, let time = Double(timeString) else {
            return
        }
        if parent.player.isPlaying {
            parent.player.monitorChapters(time: time)
        }
        statsTimeCounter += 1
        if persist || statsTimeCounter >= Const.updateDbTimeSeconds {
            statsTimeCounter = 0
            if let videoId = youtubeId ?? parent.player.video?.youtubeId {
                StatsService.shared.handleVideoTimeUpdate(videoId: videoId, time: time, persist: persist)
            }
        }

        updateTimeCounter += 1
        if persist || updateTimeCounter >= Const.elapsedTimePersistSeconds {
            updateTimeCounter = 0
            parent.player.updateElapsedTime(time, videoId: youtubeId)
        }
    }

    /// Applies a seek target right when the seek is issued
    func handleSeekTime(_ timeString: String?) {
        guard let timeString, let time = Double(timeString) else {
            return
        }
        withAnimation(.seekScrubber) {
            parent.player.currentTime = time
        }
    }

    func flushStats(timeString: String? = nil, urlString: String? = nil) {
        let videoId: String?
        if let urlString, let url = URL(string: urlString) {
            videoId = UrlService.getYoutubeIdFromUrl(url: url)
        } else {
            videoId = parent.player.video?.youtubeId
        }
        let resolvedTime = timeString ?? parent.player.currentTime.map { String($0) }
        if let videoId {
            handleTimeUpdate(resolvedTime, persist: true, youtubeId: videoId)
        }
    }
}
