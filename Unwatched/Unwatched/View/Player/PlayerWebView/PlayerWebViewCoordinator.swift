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

    @MainActor func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
        let disableCaptions = UserDefaults.standard.bool(forKey: Const.disableCaptions)
        let minimalPlayerUI = UserDefaults.standard.bool(forKey: Const.minimalPlayerUI)
        let enableLogging = UserDefaults.standard.bool(forKey: Const.enableLogging)
        let originalAudio = UserDefaults.standard.bool(forKey: Const.originalAudio)

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
            originalAudio: originalAudio
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
