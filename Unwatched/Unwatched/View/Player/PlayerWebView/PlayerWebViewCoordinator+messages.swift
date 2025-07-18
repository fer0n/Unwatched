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
            parent.player.previousState.isPlaying = true
            updateUnstarted()
            parent.player.play()
        case "ended":
            parent.player.previousState.isPlaying = false
            parent.onVideoEnded()
        case "currentTime":
            handleTimeUpdate(payload)
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
        default:
            break
        }
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
              let url = URL(string: payload),
              let youtubeId = UrlService.getYoutubeIdFromUrl(url: url) else {
            return
        }
        if youtubeId == parent.player.video?.youtubeId {
            Log.info("handleUrlClicked: current video")
            return
        }

        let task = VideoService.addForeignUrls([url], in: .queue)
        let notification = AppNotificationData(
            title: "addingVideo",
            isLoading: true,
            timeout: 0
        )
        parent.appNotificationVM.show(notification)
        Task {
            do {
                try await task.value
                let notification = AppNotificationData(
                    title: "addedVideo",
                    icon: Const.checkmarkSF,
                    timeout: 1
                )
                parent.appNotificationVM.show(notification)
            } catch { }
        }
    }

    func handlePip(_ payload: String?) {
        guard let payload else {
            return
        }
        if payload == "enter" {
            parent.player.previousState.pipEnabled = true
            parent.player.setPip(true)
        } else if payload == "exit" {
            parent.player.previousState.pipEnabled = false
            parent.player.setPip(false)
        } else if payload == "canplay" {
            parent.player.previousState.pipEnabled = false
            parent.player.canPlayPip = true
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
        parent.player.handleAspectRatio(aspectRatio)
    }

    func handleInteraction() {
        parent.autoHideVM.setShowControls()
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
        if parent.player.unstarted {
            withAnimation {
                parent.player.unstarted = false
            }
        }
    }

    func handlePause(_ payload: String?) {
        parent.player.pause()
        handleTimeUpdate(payload, persist: true)
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

        if youtube {
            if parent.player.embeddingDisabled {
                return
            }

            parent.player.isLoading = true
            parent.player.previousIsPlaying = parent.player.videoSource == .userInteraction
                ? true
                : parent.player.isPlaying

            parent.player.videoSource = .errorSwap
            parent.player.previousState.isPlaying = false

            withAnimation {
                parent.player.pause()
                parent.player.embeddingDisabled = true
            }
            return
        }
    }

    func handleTimeUpdate(_ payload: String?, persist: Bool = false) {
        guard let payload else {
            return
        }
        // "paused:2161.00033421,https://www.youtube.com/watch?t=2161&v=dKbT0iFia0I"
        let payloadArray = payload.split(separator: ",")
        let timeString = payloadArray[safe: 0]
        let urlString = payloadArray[safe: 1]
        guard let time = timeString.flatMap({ Double($0) }) else {
            return
        }
        if parent.player.isPlaying {
            parent.player.monitorChapters(time: time)
        }

        updateTimeCounter += 1
        if persist,
           let urlString,
           let url = URL(string: String(urlString)),
           let videoId = UrlService.getYoutubeIdFromUrl(url: url) {
            updateTimeCounter = 0
            parent.player.updateElapsedTime(time, videoId: videoId)
        } else if updateTimeCounter >= Const.updateDbTimeSeconds {
            updateTimeCounter = 0
            parent.player.updateElapsedTime(time)
        }
    }
}
