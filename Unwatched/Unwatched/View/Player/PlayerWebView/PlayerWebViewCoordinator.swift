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
    /// Whether this coordinator's web view has left the hierarchy.
    private(set) var retired = false
    var zoomWorkaroundActive = false
    var updateTimeCounter: Int = 0
    var statsTimeCounter: Int = 0

    init(_ parent: PlayerWebView) {
        self.parent = parent
    }

    @MainActor
    func retire() {
        retired = true
    }

    @MainActor
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        Log.info("webViewWebContentProcessDidTerminate")
        // reloading a page nothing shows any more would only take the player's state with it
        guard !retired else { return }
        parent.player.isLoading = Date()
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
        guard !retired else {
            // its view is gone: initialising it, clearing `isLoading` or — worst — consuming the auto-start would all
            // be done on the player's behalf by a page nobody can see
            Log.info("didFinish: page already dismantled")
            return
        }
        // everything below is for this page, so it has to be the one commands reach
        parent.backend.takeOver(webView)
        let uiMode = parent.uiMode
        parent.backend.appliedUIMode = uiMode
        let options = PlayerWebView.initScriptOptions(
            startAt: parent.player.getStartPosition(),
            uiMode: uiMode,
            player: parent.player
        )
        let script = PlayerWebView.initScript(options)
        Log.info("InitScriptOptions: \(options)")
        parent.evaluateJavaScript(webView, script)
        withAnimation {
            parent.player.unstarted = true
        }
        parent.player.isLoading = nil
        parent.player.handleAutoStart(webView.url)
        // the switch's own play may have been spent on the web view this page took over from
        parent.backend.ensurePlaying()
    }
}

#if os(iOS) || os(visionOS)
extension PlayerWebViewCoordinator: UIScrollViewDelegate {
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if scale <= 1 && !zoomWorkaroundActive {
            guard let webView = parent.backend.webView else {
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
