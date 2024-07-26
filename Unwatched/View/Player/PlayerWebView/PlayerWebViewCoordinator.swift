//
//  PlayerWebViewCoordinator.swift
//  Unwatched
//

import SwiftUI
import WebKit
import OSLog

class PlayerWebViewCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    let parent: PlayerWebView

    init(_ parent: PlayerWebView) {
        self.parent = parent
    }

    @MainActor
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
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
        case "error":
            handleError(payload)
        default:
            break
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
        guard let payload = payload, let duration = Double(payload), duration > 0 else {
            return
        }
        if let video = parent.player.video {
            VideoService.updateDuration(video, duration: duration)
        }
    }

    func handleError(_ payload: String?) {
        guard let error = YtIframeError(rawValue: payload ?? "") else {
            Logger.log.error("Unknown YtIframeError")
            return
        }

        switch error {
        case .ownerForbidsEmbedding, .ownerForbidsEmbedding2:
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
        default:
            Logger.log.error("Unhandled YtIframeError")
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
        if let urlString = urlString,
           let url = URL(string: String(urlString)),
           let videoId = UrlService.getYoutubeIdFromUrl(url: url),
           persist {
            parent.player.updateElapsedTime(time, videoId: videoId)
        }
    }

    @MainActor func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
        if parent.playerType != .youtube || !parent.player.embeddingDisabled {
            // workaround: without "!parent.player.embeddingDisabled", the video doesn't start
            // switching from a non-embedding to an embedded video, probably a race condition
            return
        }
        let script = PlayerWebView.nonEmbeddedInitScript(
            parent.player.playbackSpeed,
            parent.player.getStartPosition(),
            parent.player.requiresFetchingVideoData()
        )
        webView.evaluateJavaScript(script)
        parent.player.handleAutoStart()
    }
}
