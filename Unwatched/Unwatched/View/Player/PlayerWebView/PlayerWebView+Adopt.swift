//
//  PlayerWebView+Adopt.swift
//  Unwatched
//

import SwiftUI
import WebKit
import OSLog
import UnwatchedShared

extension PlayerWebView {
    /// Takes over the page `WebPlayerWarmup` loaded while the previous player was still playing.
    /// It's initialized already, so all that's left is moving it to the live playback position and
    /// replaying the one-shot events the warmup swallowed.
    func adopt(_ warmed: WebPlayerWarmup.Warmed, _ coordinator: PlayerWebViewCoordinator) -> WKWebView {
        let webView = warmed.webView
        backend.resetAppliedState()
        backend.webView = webView
        backend.loadedVideoId = player.video?.youtubeId
        backend.appliedUIMode = warmed.uiMode

        attach(coordinator, to: webView)

        if warmed.didStart {
            player.unstarted = false
            evaluateJavaScript(webView, PlayerWebView.muteScript(false))
        } else {
            // the page still shows YouTube's poster until it starts, so it has to be covered from
            // the moment the swap happens, not a frame later
            withAnimation {
                player.unstarted = true
            }
        }

        let startAt = player.getStartPosition()
        Task { @MainActor in
            if !warmed.didStart, abs(startAt - warmed.startAt) > 0.5 {
                evaluateJavaScript(webView, PlayerWebView.seekToScript(startAt))
            }
            for message in warmed.messages {
                coordinator.handleJsMessages(message.topic, message.payload)
            }
            player.isLoading = nil
            // the speed the page was warmed at can be stale by now: it was read when the warm-up started, and the
            // user had the outgoing player in front of them the whole time
            if warmed.playbackSpeed != player.playbackSpeed {
                backend.setRate(player.playbackSpeed)
            }
            if !warmed.didStart {
                await PlayerWebView.awaitViewport(webView)
            }
            // `play()` confirms and re-clicks on its own, so adoption no longer needs a retry loop of its own — two
            // of them would double-click the page.
            player.handleAutoStart(webView.url)
            backend.setChapterMarkers(force: true)
        }
        return webView
    }

    /// The play click is aimed at the middle of the viewport, which is still 0×0 right after
    /// adoption: SwiftUI inserts the web view before laying it out.
    @MainActor
    static func awaitViewport(_ webView: WKWebView) async {
        let sized = await Poll.until(timeout: Self.viewportTimeout, step: Self.viewportPollSeconds) {
            let result = try? await webView.evaluateJavaScript("window.innerWidth")
            return (result as? Double ?? 0) > 0 ? .done : .retry
        }
        if !sized {
            Log.warning("adopt: viewport stayed empty")
        }
    }

    private static let viewportPollSeconds: Double = 0.03
    private static let viewportTimeout: Double = 0.9

    func attach(_ coordinator: PlayerWebViewCoordinator, to webView: WKWebView) {
        webView.navigationDelegate = coordinator
        webView.configuration.userContentController.add(coordinator, name: "iosListener")
        #if os(iOS) || os(visionOS)
        webView.scrollView.delegate = coordinator
        #endif
    }
}
