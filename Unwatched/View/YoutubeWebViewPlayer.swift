//
//  YoutubeWebViewPlayer.swift
//  Unwatched
//

import SwiftUI
import WebKit

struct YoutubeWebViewPlayer: UIViewRepresentable {
    let videoID: String
    @Binding var playbackSpeed: Double
    @Binding var isPlaying: Bool

    var htmlString: String {
        """
        <meta name="viewport" content="width=device-width, shrink-to-fit=YES">
        <style>
            html, body {
                margin: 0;
                padding: 0;
                width: 100%;
                height: 100%;
                overflow: hidden;
            }
        </style>
        <script src="https://www.youtube.com/iframe_api"></script>
        <script>
            var player;
            function onYouTubeIframeAPIReady() {
                player = new YT.Player("player", {
                    events: {
                        onReady: onPlayerReady,
                        onStateChange: onPlayerStateChange
                    },
                });
            }

            function onPlayerReady(event) {
                event.target.setPlaybackRate(\(playbackSpeed));
                player.play()
            }

            function onPlayerStateChange(event) {
                if (event.data == YT.PlayerState.PAUSED) {
                    window.webkit.messageHandlers.iosListener.postMessage("paused");
                } else if (event.data == YT.PlayerState.PLAYING) {
                    window.webkit.messageHandlers.iosListener.postMessage("playing");
                }
            }
        </script>
        <iframe
            id="player"
            type="text/html"
            width="100%"
            height="100%"
            src="https://www.youtube.com/embed/\(videoID)?enablejsapi=1&autoplay=1&controls=1"
            frameborder="0"
        ></iframe>
    """
    }

    func makeUIView(context: Context) -> WKWebView {
        let webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.allowsPictureInPictureMediaPlayback = true
        webViewConfiguration.mediaTypesRequiringUserActionForPlayback = []
        webViewConfiguration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: webViewConfiguration)
        webView.navigationDelegate = context.coordinator
        webView.configuration.userContentController.add(context.coordinator, name: "iosListener")
        webView.backgroundColor = UIColor(Color.backgroundGray)
        webView.isOpaque = false
        webView.loadHTMLString(htmlString, baseURL: nil)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let script = "player.setPlaybackRate(\(playbackSpeed))"
        uiView.evaluateJavaScript(script, completionHandler: nil)

        if isPlaying {
            uiView.evaluateJavaScript("player.playVideo()", completionHandler: nil)
        } else {
            uiView.evaluateJavaScript("player.pauseVideo()", completionHandler: nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: YoutubeWebViewPlayer
        var didLoadURL = false

        init(_ parent: YoutubeWebViewPlayer) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            if message.name == "iosListener", let messageBody = message.body as? String {
                if messageBody == "paused" {
                    parent.isPlaying = false
                } else if messageBody == "playing" {
                    parent.isPlaying = true
                }
            }
        }
    }
}
