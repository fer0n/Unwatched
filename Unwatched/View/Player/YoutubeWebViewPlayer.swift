//
//  YoutubeWebViewPlayer.swift
//  Unwatched
//

import SwiftUI
import WebKit

struct YoutubeWebViewPlayer: UIViewRepresentable {
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.autoplayVideos) var autoplayVideos: Bool = true
    @Environment(PlayerManager.self) var player

    let video: Video
    @Binding var playbackSpeed: Double
    var onVideoEnded: () -> Void

    func makeUIView(context: Context) -> WKWebView {
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
        let webViewConfig = WKWebViewConfiguration()
        webViewConfig.allowsPictureInPictureMediaPlayback = true
        if autoplayVideos {
            webViewConfig.mediaTypesRequiringUserActionForPlayback = []
        }
        if !playVideoFullscreen {
            webViewConfig.allowsInlineMediaPlayback = true
        }

        let webView = WKWebView(frame: .zero, configuration: webViewConfig)
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

        if prev.isPlaying != player.isPlaying {
            if player.isPlaying {
                uiView.evaluateJavaScript("player.playVideo()", completionHandler: nil)
            } else {
                uiView.evaluateJavaScript("player.pauseVideo()", completionHandler: nil)
            }
            context.coordinator.previousState.isPlaying = player.isPlaying
        }

        let seekPosition = player.seekPosition
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
                let body = messageBody.split(separator: ":")
                guard let topic = body[safe: 0] else {
                    return
                }
                let payload = body[safe: 1]
                let payloadString = payload.map { String($0) }
                if topic != "currentTime" {
                    debugPrint(messageBody)
                }
                handleJsMessages(String(topic), payloadString)
            }
        }

        func handleJsMessages(_ topic: String, _ payload: String?) {
            switch topic {
            case "paused":
                parent.player.isPlaying = false
                handleTimeUpdate(payload, persist: true)
            case "playing":
                parent.player.isPlaying = true
            case "ended":
                parent.player.isPlaying = false
                parent.onVideoEnded()
            case "unstarted", "playerReady":
                handleAutoStart()
            case "currentTime":
                handleTimeUpdate(payload)
            case "duration":
                guard let payload = payload, let duration = Double(payload) else {
                    return
                }
                VideoService.updateDuration(parent.video, duration: duration)
            default:
                break
            }
        }

        func handleAutoStart() {
            if parent.autoplayVideos {
                parent.player.isPlaying = true
            }
        }

        func handleTimeUpdate(_ payload: String?, persist: Bool = false) {
            guard let payload = payload, let time = Double(payload) else {
                return
            }
            if persist {
                parent.player.updateElapsedTime(time)
            }
            parent.player.monitorChapters(time: time)
        }
    }

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
                sendMessage("duration", player.getDuration());
                event.target.setPlaybackRate(\(playbackSpeed));
                player.seekTo(\(startAt), true);
                \(autoplayVideos ? "player.play()" : "")
            }

            function onPlayerStateChange(event) {
                if (event.data == YT.PlayerState.PAUSED) {
                    sendMessage("paused", player.getCurrentTime());
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
}

struct PreviousState {
    var videoId: String?
    var playbackSpeed: Double?
    var seekPosition: Double?
    var isPlaying: Bool = false
}
