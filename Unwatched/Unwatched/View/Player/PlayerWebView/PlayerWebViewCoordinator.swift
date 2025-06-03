//
//  PlayerWebViewCoordinator.swift
//  Unwatched
//

import SwiftUI
import WebKit
import OSLog
import UnwatchedShared

class PlayerWebViewCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    let parent: PlayerWebView
    var updateTimeCounter: Int = 0

    init(_ parent: PlayerWebView) {
        self.parent = parent
    }

    @MainActor
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        Log.info("webViewWebContentProcessDidTerminate")
        parent.player.isLoading = true
        parent.loadWebContent(webView)
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        if message.name == "iosListener", let messageBody = message.body as? String {
            let body = messageBody.split(separator: ";")
            guard let topic = body[safe: 0] else {
                return
            }
            let payload = body[safe: 1]
            let payloadString = payload.map { String($0) }
            if topic != "currentTime" {
                Log.info(">\(messageBody)")
            }
            handleJsMessages(String(topic), payloadString)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
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
        case "updateTitle":
            handleTitleUpdate(payload)
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
        default:
            break
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
        guard let payload = payload,
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
        guard let payload = payload else {
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
        guard let payload = payload,
              let playbackRate = Double(payload),
              parent.player.playbackSpeed != playbackRate else {
            return
        }
        parent.player.playbackSpeed = playbackRate
    }

    func handleTitleUpdate(_ title: String?) {
        if let title = UrlService.getCleanTitle(title) {
            self.parent.player.video?.title = title
        }
    }

    func handleDuration(_ payload: String?) {
        Log.info("handleDuration")
        guard let payload = payload, let duration = Double(payload), duration > 0 else {
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
        guard let payload = payload else {
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
           let urlString = urlString,
           let url = URL(string: String(urlString)),
           let videoId = UrlService.getYoutubeIdFromUrl(url: url) {
            updateTimeCounter = 0
            parent.player.updateElapsedTime(time, videoId: videoId)
        } else if updateTimeCounter >= Const.updateDbTimeSeconds {
            updateTimeCounter = 0
            parent.player.updateElapsedTime(time)
        }
    }

    @MainActor func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
        let disableCaptions = UserDefaults.standard.bool(forKey: Const.disableCaptions)
        let minimalPlayerUI = UserDefaults.standard.bool(forKey: Const.minimalPlayerUI)
        let enableLogging = UserDefaults.standard.bool(forKey: Const.enableLogging)
        var hijackFullscreenButton = false
        #if os(macOS)
        hijackFullscreenButton = true
        #endif
        let options = PlayerWebView.InitScriptOptions(
            playbackSpeed: parent.player.playbackSpeed,
            startAt: parent.player.getStartPosition(),
            requiresFetchingVideoData: parent.player.requiresFetchingVideoData(),
            disableCaptions: disableCaptions,
            minimalPlayerUI: minimalPlayerUI,
            isNonEmbedding: parent.player.embeddingDisabled,
            hijackFullscreenButton: hijackFullscreenButton,
            fullscreenTitle: "\(String(localized: "toggleFullscreen")) (f)",
            enableLogging: enableLogging
        )
        let script = PlayerWebView.initScript(options)
        Log.info("InitScriptOptions: \(options)")
        parent.evaluateJavaScript(webView, script)
        withAnimation {
            parent.player.unstarted = true
        }
        parent.player.handleAutoStart()
    }
}

enum SwipeDirecton: String {
    case left
    case right
    // swiftlint:disable:next identifier_name
    case up
    case down
}

enum PlayerError: Error {
    case javascriptError(_ message: String)
}
