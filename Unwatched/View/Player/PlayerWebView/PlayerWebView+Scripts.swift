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
    static func initScript(
        _ playbackSpeed: Double,
        _ startAt: Double,
        _ requiresFetchingVideoData: Bool?
    ) -> String {
        """
        var video = document.querySelector('video');
        video.playbackRate = \(playbackSpeed);
        video.currentTime = \(startAt);
        video.muted = false;

        function sendMessage(topic, payload) {
            window.webkit.messageHandlers.iosListener.postMessage("" + topic + ";" + payload);
        }


        // play, pause, ended
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


        // meta data
        video.addEventListener('loadedmetadata', function() {
            const duration = video.duration;
            sendMessage("duration", duration.toString());
            \(requiresFetchingVideoData == true ? "sendMessage('updateTitle', document.title);" : "")
            cancelErrorChecks();
        });
        video.addEventListener('loadeddata', function() {
            sendMessage("aspectRatio", `${video.videoWidth/video.videoHeight}`);
        });


        // styling
        styling()
        function styling() {
             const style = document.createElement('style');
             style.innerHTML = '.ytp-pause-overlay, .branding-img { display: none !important; }';
             document.head.appendChild(style);
        }


        // elapsed time
        var timer;
        function startTimer() {
            clearInterval(timer);
            timer = setInterval(function() {
                sendMessage("currentTime", video.currentTime);
            }, 1000);
        }
        function stopTimer() {
            clearInterval(timer);
        }


        // long press
        const touchCountsAsLongPress = 300
        var touchStartTime;
        var touchTimeout;
        var longTouchSent = false;

        document.addEventListener('touchstart', function(event) {
            handleTouchStart(event);
            sendMessage("interaction")
        });
        document.addEventListener('touchend', function(event) {
            handleTouchEnd(event);
        });
        document.addEventListener('touchcancel', function(event) {
            handleTouchEnd(event);
        });

        function handleTouchStart(event) {
            touchStartTime = Date.now();
            touchTimeout = setTimeout(function() {
                const touch = event.touches[0];
                const screenWidth = window.innerWidth;
                const side = touch.clientX < screenWidth / 2 ? "left" : "right";
                sendMessage("longTouch", side);
                longTouchSent = true;
            }, touchCountsAsLongPress);
        }

        function handleTouchEnd(event) {
            clearTimeout(touchTimeout);
            if (longTouchSent) {
                sendMessage("longTouchEnd");
                longTouchSent = false;
            }
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
