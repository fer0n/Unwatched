//
//  YoutubeWebViewPlayer.swift
//  Unwatched
//

import SwiftUI
import WebKit

struct YoutubeWebViewPlayer: UIViewRepresentable {
    let video: Video
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
            var timer;

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
                player.seekTo(\(video.elapsedSeconds), true);
                sendMessage("duration", player.getDuration());
                player.play()
            }

            function onPlayerStateChange(event) {
                if (event.data == YT.PlayerState.PAUSED) {
                    sendMessage("paused");
                    stopTimer();
                } else if (event.data == YT.PlayerState.PLAYING) {
                    sendMessage("playing");
                    startTimer();
                }
            }

            function startTimer() {
                timer = setInterval(function() {
                sendMessage("currentTime", player.getCurrentTime());
                }, 1000);
            }

            function stopTimer() {
                clearInterval(timer);
            }

            function sendMessage(topic, payload) {
                window.webkit.messageHandlers.iosListener.postMessage("" + topic + ":" + payload);
            }
        </script>
        <iframe
            id="player"
            type="text/html"
            width="100%"
            height="100%"
            src="https://www.youtube.com/embed/\(video.youtubeId)?enablejsapi=1&autoplay=1&controls=1"
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
                // split into topic:content
                let body = messageBody.split(separator: ":")
                let topic = body[safe: 0]
                let payload = body[safe: 1]

                print("topic", topic)
                print("payload", payload)
                print("messageBody", messageBody)

                switch topic {
                case "paused":
                    parent.isPlaying = false
                case "playing":
                    parent.isPlaying = true
                case "currentTime":
                    guard let payload = payload, let time = Double(payload) else {
                        return
                    }
                    print("newTime", time)
                    parent.video.elapsedSeconds = time
                case "duration":
                    guard let payload = payload, let duration = Double(payload) else {
                        return
                    }
                    print("duration", duration)
                    parent.video.duration = duration
                default:
                    break
                }

            }
        }
    }
}


