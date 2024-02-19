//
//  EmbeddedPlayerView.swift
//  Unwatched
//

import SwiftUI
import WebKit

extension PlayerWebView {

    @MainActor
    func setupEmbeddedYouTubePlayer(webView: WKWebView, startAt: Double) {
        let htmlString = PlayerWebView.getYoutubeIframeHTML(
            youtubeId: player.video?.youtubeId ?? "",
            playbackSpeed: player.playbackSpeed,
            startAt: startAt
        )
        webView.loadHTMLString(htmlString, baseURL: nil)
    }

    // swiftlint:disable function_body_length
    static func getYoutubeIframeHTML(youtubeId: String, playbackSpeed: Double, startAt: Double) -> String {
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
                        onStateChange: onPlayerStateChange,
                        onPlaybackRateChange: function(event) {
                            sendMessage("playbackRate", event.data);
                        },
                        onError: function(event) {
                            sendMessage("error", event.data);
                        },
                    },
                });
            }

            function onPlayerReady(event) {
                event.target.setPlaybackRate(\(playbackSpeed));
                player.cueVideoById('\(youtubeId)', \(startAt));
                sendMessage("playerReady");
                sendMessage("duration", player.getDuration());
            }

            function onPlayerStateChange(event) {
                if (event.data == YT.PlayerState.PAUSED) {
                    const url = player.getVideoUrl();
                    const payload = `${player.getCurrentTime()},${url}`;
                    sendMessage("pause", payload);
                    stopTimer();
                } else if (event.data == YT.PlayerState.PLAYING) {
                    sendMessage("play");
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
    // swiftlint:enable function_body_length
}
