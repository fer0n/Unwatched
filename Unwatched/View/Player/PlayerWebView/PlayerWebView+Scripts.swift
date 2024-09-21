//
//  YouTubePlayerView.swift
//  Unwatched
//

import SwiftUI
import WebKit
import OSLog

extension PlayerWebView {

    @MainActor
    func loadPlayer(webView: WKWebView, startAt: Double, type: PlayerType) -> Bool {
        guard let youtubeId = player.video?.youtubeId else {
            Logger.log.warning("loadPlayer: no youtubeId")
            return false
        }
        let urlString = type == .youtube
            ? UrlService.getNonEmbeddedYoutubeUrl(youtubeId, startAt)
            : UrlService.getEmbeddedYoutubeUrl(youtubeId, startAt)

        // TODO: adjust translations: ... make sure you're signed in into the in-app browser

        guard let url = URL(string: urlString) else {
            Logger.log.warning("loadPlayer: no url")
            return false
        }

        let request = URLRequest(url: url)
        webView.load(request)
        return true
    }

    func getPlayScript() -> String {
        if player.unstarted {
            Logger.log.info("PLAY: unstarted")
            return "document.elementFromPoint(window.innerWidth / 2, window.innerHeight / 2).click();"
        }
        return "document.querySelector('video').play();"
    }

    func getPauseScript() -> String {
        return "document.querySelector('video').pause();"
    }

    func getSeekToScript(_ seekTo: Double) -> String {
        return "document.querySelector('video').currentTime = \(seekTo);"
    }

    func getSetPlaybackRateScript() -> String {
        return "document.querySelector('video').playbackRate = \(player.playbackSpeed);"
    }

    // swiftlint:disable function_body_length
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

        styling()

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
            cancelErrorChecks();
        });

        function styling() {
             const style = document.createElement('style');
             style.innerHTML = '.ytp-pause-overlay, .branding-img { display: none !important; }';
             document.head.appendChild(style);
        }

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

        // Error handling
        var errorCheckTimers = [];

        function checkError() {
            const errorContent = document.querySelector('.ytp-error-content')
            if (errorContent) {
                sendMessage("error", errorContent?.innerText);
            }
        }

        function cancelErrorChecks() {
            errorCheckTimers.forEach(clearTimeout);
            errorCheckTimers = [];
        }

        // check for errors (could use improveming)
        checkError()
        errorCheckTimers.push(setTimeout(checkError, 1000));
        errorCheckTimers.push(setTimeout(checkError, 3000));
        errorCheckTimers.push(setTimeout(checkError, 5000));
        errorCheckTimers.push(setTimeout(checkError, 10000));
     """
    }
    // swiftlint:enable function_body_length
}
