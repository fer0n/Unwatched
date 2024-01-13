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
    var updateElapsedTime: (_ seconds: Double) -> Void
    @Bindable var chapterManager: ChapterManager
    var onVideoEnded: () -> Void

    func getYoutubeIframeHTML(youtubeId: String, playbackSpeed: Double, startAt: Double) -> String {
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
                sendMessage("playerReady");
                event.target.setPlaybackRate(\(playbackSpeed));
                player.seekTo(\(startAt), true);
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
                } else if (event.data == YT.PlayerState.ENDED) {
                    sendMessage("ended");
                } else if (event.data == YT.PlayerState.UNSTARTED) {
                    sendMessage("unstarted");
                }
            }

            function startTimer() {
                clearInterval(timer);
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
            src="https://www.youtube.com/embed/\(youtubeId)?enablejsapi=1&autoplay=1&controls=1"
            frameborder="0"
        ></iframe>
    """
    }

    func makeUIView(context: Context) -> WKWebView {
        print("MAKE UIView")
        let webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.allowsPictureInPictureMediaPlayback = true
        webViewConfiguration.mediaTypesRequiringUserActionForPlayback = []
        webViewConfiguration.allowsInlineMediaPlayback = true

        var startPosition = video.elapsedSeconds
        if let finished = video.hasFinished {
            if finished {
                startPosition = 0
            }
        }
        let htmlString = getYoutubeIframeHTML(
            youtubeId: video.youtubeId,
            playbackSpeed: playbackSpeed,
            startAt: startPosition
        )
        let webView = WKWebView(frame: .zero, configuration: webViewConfiguration)
        webView.navigationDelegate = context.coordinator
        webView.configuration.userContentController.add(context.coordinator, name: "iosListener")
        webView.backgroundColor = UIColor(Color.backgroundGray)
        webView.isOpaque = false
        webView.loadHTMLString(htmlString, baseURL: nil)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        print("updateUiView")
        let prev = context.coordinator.previousState

        if prev.playbackSpeed != playbackSpeed {
            let script = "player.setPlaybackRate(\(playbackSpeed))"
            uiView.evaluateJavaScript(script, completionHandler: nil)
            context.coordinator.previousState.playbackSpeed = playbackSpeed
        }

        if isPlaying {
            uiView.evaluateJavaScript("player.playVideo()", completionHandler: nil)
        } else {
            uiView.evaluateJavaScript("player.pauseVideo()", completionHandler: nil)
        }

        let seekPosition = chapterManager.seekPosition
        if prev.seekPosition != seekPosition, let seekTo = seekPosition {
            let script = "player.seekTo(\(seekTo), true)"
            uiView.evaluateJavaScript(script, completionHandler: nil)
            context.coordinator.previousState.seekPosition = seekPosition
        }

        if prev.videoId != video.youtubeId {
            let script = "player.loadVideoById('\(video.youtubeId)', 0)"
            uiView.evaluateJavaScript(script, completionHandler: nil)
            context.coordinator.previousState.videoId = video.youtubeId
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: YoutubeWebViewPlayer
        var didLoadURL = false
        var previousState = PreviousState()

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
                if topic != "currentTime" {
                    debugPrint(messageBody)
                }

                switch topic {
                case "paused":
                    parent.isPlaying = false
                case "playing":
                    parent.isPlaying = true
                case "ended":
                    parent.isPlaying = false
                    parent.onVideoEnded()
                case "unstarted":
                    parent.isPlaying = true
                case "currentTime":
                    guard let payload = payload, let time = Double(payload) else {
                        return
                    }
                    // print("newTime", time)
                    parent.updateElapsedTime(time)
                    parent.chapterManager.monitorChapters(time: time)
                case "duration":
                    guard let payload = payload, let duration = Double(payload) else {
                        return
                    }
                    VideoService.updateDuration(parent.video, duration: duration)
                default:
                    break
                }
            }
        }
    }
}

struct PreviousState {
    var videoId: String?
    var playbackSpeed: Double?
    var seekPosition: Double?
}
