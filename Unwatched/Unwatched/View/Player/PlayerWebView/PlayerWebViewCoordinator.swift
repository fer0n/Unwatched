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
    var zoomWorkaroundActive = false
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

    @MainActor func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
        let disableCaptions = UserDefaults.standard.bool(forKey: Const.disableCaptions)
        let minimalPlayerUI = UserDefaults.standard.bool(forKey: Const.minimalPlayerUI)
        let enableLogging = UserDefaults.standard.bool(forKey: Const.enableLogging)
        let originalAudio = UserDefaults.standard.bool(forKey: Const.originalAudio)

        let playbackId = UUID().uuidString
        UserDefaults.standard.set(playbackId, forKey: Const.playbackId)

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
            enableLogging: enableLogging,
            originalAudio: originalAudio,
            playbackId: playbackId,
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

#if os(iOS)
extension PlayerWebViewCoordinator: UIScrollViewDelegate {
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if scale <= 1 && !zoomWorkaroundActive {
            guard let webView = parent.webViewState.webView else {
                Log.error("scrollViewDidEndZooming: no webView")
                return
            }

            // workaround: zoom is now messed up, requires continuously resetting it
            let script = """
                let previousWidth = window.innerWidth;
                window.addEventListener('resize', (e) => {
                    const change = Math.abs(window.innerWidth - previousWidth);
                    sendMessage("resize change", change);
                    if (change > 100 || change === 0) {
                        // only send if the width changed significantly
                        // (ignore mini player resize, only orientation change which is sometimes 0)
                        sendMessage("resize");
                    }
                    previousWidth = window.innerWidth;
                });
            """
            parent.evaluateJavaScript(webView, script)
            zoomWorkaroundActive = true
        }
    }
}
#endif
