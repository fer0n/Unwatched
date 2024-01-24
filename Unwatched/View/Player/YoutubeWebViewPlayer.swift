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

    var onVideoEnded: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        var startPosition = player.video?.elapsedSeconds ?? 0
        if player.video?.hasFinished == true {
            startPosition = 0
        }
        let htmlString = getYoutubeIframeHTML(
            youtubeId: player.video?.youtubeId ?? "",
            playbackSpeed: player.playbackSpeed,
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
        // print("updateUiView")
        let prev = context.coordinator.previousState

        if prev.playbackSpeed != player.playbackSpeed {
            let script = "player.setPlaybackRate(\(player.playbackSpeed))"
            uiView.evaluateJavaScript(script, completionHandler: nil)
            context.coordinator.previousState.playbackSpeed = player.playbackSpeed
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

        if prev.videoId != player.video?.youtubeId, let videoId = player.video?.youtubeId {
            print("cueVideoById")
            let script = "player.cueVideoById('\(videoId)', \(player.video?.elapsedSeconds ?? 0));"
            uiView.evaluateJavaScript(script, completionHandler: nil)
            context.coordinator.previousState.videoId = player.video?.youtubeId
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
                let body = messageBody.split(separator: ";")
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
                parent.player.pause()
                handleTimeUpdate(payload, persist: true)
            case "playing":
                parent.player.play()
            case "ended":
                parent.onVideoEnded()
            case "unstarted", "playerReady":
                handleAutoStart()
            case "currentTime":
                handleTimeUpdate(payload)
            case "duration":
                guard let payload = payload, let duration = Double(payload) else {
                    return
                }
                if let video = parent.player.video {
                    VideoService.updateDuration(video, duration: duration)
                }
            default:
                break
            }
        }

        func handleAutoStart() {
            print("parent.player.videoSource", parent.player.videoSource)
            switch parent.player.videoSource {
            case .continuousPlay:
                let continuousPlay = UserDefaults.standard.bool(forKey: Const.continuousPlay)
                if continuousPlay {
                    parent.player.play()
                }
            case .nextUp:
                break
            case .userInteraction:
                let autoPlay = UserDefaults.standard.bool(forKey: Const.autoplayVideos)
                if  autoPlay {
                    parent.player.play()
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
            if let urlString = urlString,
               let url = URL(string: String(urlString)),
               let videoId = UrlService.getYoutubeIdFromUrl(url: url),
               persist {
                parent.player.updateElapsedTime(time, videoId: videoId)
            }
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
                event.target.setPlaybackRate(\(playbackSpeed));
                sendMessage("playerReady");
                player.seekTo(\(startAt), true);
                sendMessage("duration", player.getDuration());
            }

            function onPlayerStateChange(event) {
                if (event.data == YT.PlayerState.PAUSED) {
                    const url = player.getVideoUrl();
                    const payload = `${player.getCurrentTime()},${url}`;
                    sendMessage("paused", payload);
                    stopTimer();
                } else if (event.data == YT.PlayerState.PLAYING) {
                    sendMessage("playing");
                    startTimer();
                } else if (event.data == YT.PlayerState.ENDED) {
                    sendMessage("ended");
                    stopTimer();
                } else if (event.data == YT.PlayerState.UNSTARTED) {
                    sendMessage("unstarted");
                    sendMessage("duration", player.getDuration());
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
                window.webkit.messageHandlers.iosListener.postMessage("" + topic + ";" + payload);
            }
        </script>
        <iframe
            id="player"
            type="text/html"
            width="100%"
            height="100%"
            src="\(UrlService.getEmbeddedYoutubeUrl(youtubeId))"
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
