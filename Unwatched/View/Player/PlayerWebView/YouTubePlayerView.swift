//
//  YouTubePlayerView.swift
//  Unwatched
//

import SwiftUI
import WebKit

extension PlayerWebView {

    @MainActor
    func setupYouTubePlayer(webView: WKWebView, startAt: Double) {
        guard let youtubeId = player.video?.youtubeId,
              let url = URL(string: UrlService.getNonEmbeddedYoutubeUrl(youtubeId, startAt)) else {
            return
        }
        let request = URLRequest(url: url)
        webView.load(request)
    }

    static func nonEmbeddedInitScript(
        _ playbackSpeed: Double,
        _ startAt: Double,
        _ requiresFetchingVideoData: Bool?
    ) -> String {
        """
        var timer;
        var video = document.querySelector('video');
        video.playbackRate = \(playbackSpeed);
        video.currentTime = \(startAt);
        video.muted = false;

        video.addEventListener('play', function() {
            startTimer();
            sendMessage("play")
        });
        video.addEventListener('pause', function() {
            stopTimer();
            const url = window.location.href;
            const payload = `${video.currentTime},${url}`;
            sendMessage("pause", payload);
        });
        video.addEventListener('ended', function() {
            sendMessage("ended");
        });
        video.addEventListener('webkitpresentationmodechanged', function (event) {
            event.stopPropagation()
        }, true)
        video.addEventListener('loadedmetadata', function() {
            const duration = video.duration;
            sendMessage("duration", duration.toString());
            \(requiresFetchingVideoData == true ? "sendMessage('updateTitle', document.title);" : "")
        });

        function startTimer() {
            clearInterval(timer);
            timer = setInterval(function() {
                sendMessage("currentTime", video.currentTime);
            }, 1000);
        }

        function stopTimer() {
            clearInterval(timer);
        }

        function sendMessage(topic, payload) {
            window.webkit.messageHandlers.iosListener.postMessage("" + topic + ";" + payload);
        }
     """
    }
}
