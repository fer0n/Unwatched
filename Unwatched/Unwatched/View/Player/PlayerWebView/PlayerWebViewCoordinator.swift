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
                Logger.log.info(">\(messageBody)")
            }
            handleJsMessages(String(topic), payloadString)
        }
    }

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
        case "unstarted":
            parent.player.handleAutoStart()
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
        case "error":
            handleError(payload)
        default:
            break
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
        }
    }

    func handleCenterTouch(_ payload: String?) {
        guard let payload = payload else {
            return
        }
        let play = payload == "play"
        parent.overlayVM.show(play ? .play : .pause)
    }

    func handleSwipe(_ payload: String?) {
        guard let direction = payload,
              let parsed = SwipeDirecton(rawValue: direction) else {
            Logger.log.warning("No side given for longTouch")
            return
        }
        parent.handleSwipe(parsed)
    }

    func handleAspectRatio(_ payload: String?) {
        guard let value = payload,
              let aspectRatio = Double(value) else {
            Logger.log.warning("Aspect ratio couldn't be parsed: \(payload ?? "-")")
            return
        }
        parent.player.handleAspectRatio(aspectRatio)
    }

    func handleInteraction() {
        parent.autoHideVM.setShowControls()
    }

    func handleLongTouchStart(_ payload: String?) {
        guard let side = payload else {
            Logger.log.warning("No side given for longTouch")
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
            parent.player.unstarted = false
        }
    }

    func handlePause(_ payload: String?) {
        if !parent.player.isInBackground {
            // workaround: hard pause when entering background (resumes playing otherwise when coming back)
            parent.player.previousState.isPlaying = false
        }
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
        print("handleDuration")
        guard let payload = payload, let duration = Double(payload), duration > 0 else {
            Logger.log.info("handleDuration: not updating")
            return
        }

        if let video = parent.player.video {
            VideoService.updateDuration(video, duration: duration)

            ChapterService.updateDuration(
                video,
                duration: duration,
                parent.player.container
            )
        }
    }

    func handleError(_ payload: String?) {
        Logger.log.error("video player error: \(payload ?? "Unknown")")

        if !parent.player.embeddingDisabled {
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
        let script = PlayerWebView.initScript(
            parent.player.playbackSpeed,
            parent.player.getStartPosition(),
            parent.player.requiresFetchingVideoData()
        )
        webView.evaluateJavaScript(script)
        parent.player.unstarted = true
        parent.player.handleAutoStart()
    }
}

enum SwipeDirecton: String {
    case left = "left"
    case right = "right"
    case up = "up"
    case down = "down"
}
