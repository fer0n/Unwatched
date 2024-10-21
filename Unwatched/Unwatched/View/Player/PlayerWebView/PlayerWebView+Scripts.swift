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
        var requiresFetchingVideoData = \(requiresFetchingVideoData == true);
        video.playbackRate = \(playbackSpeed);
        var startAtTime = \(startAt);

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
            if (requiresFetchingVideoData) {
                sendMessage('updateTitle', document.title);
            }
            video.currentTime = startAtTime;
        });
        video.addEventListener('loadeddata', function() {
            sendMessage("aspectRatio", `${video.videoWidth/video.videoHeight}`);
        });


        // styling
        styling()
        function styling() {
            const style = document.createElement('style');
            style.innerHTML = `
                .ytp-pause-overlay, .branding-img {
                    display: none !important;
                }
            `;
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


        // swipe left/right
        var touchStartX;
        var touchStartY;
        var isPinching = false;

        function handleSwipe(event) {
            const touchEndX = event.changedTouches[0].clientX;
            const touchEndY = event.changedTouches[0].clientY;

            const deltaX = touchEndX - touchStartX;
            const deltaY = touchEndY - touchStartY;

            if (Math.abs(deltaX) > Math.abs(deltaY)) {
                if (deltaX > 50) {
                    sendMessage("swipe", "right");
                    isSwiping = true;
                } else if (deltaX < -50) {
                    sendMessage("swipe", "left");
                    isSwiping = true;
                }
            } else {
                if (deltaY > 50) {
                    sendMessage("swipe", "down");
                    isSwiping = true;
                } else if (deltaY < -50) {
                    sendMessage("swipe", "up");
                    isSwiping = true;
                }
            }
        }


        // long press & swipe
        const touchCountsAsLongPress = 300
        var touchStartTime;
        var touchTimeout;
        var centerTouch = false;
        var longTouchSent = false;
        var touchStartEvent;

        function addTouchEventListener(eventType, handler) {
            window.addEventListener(eventType, event => {
                if (event.target.matches('video') || event.target.matches('.ytp-cued-thumbnail-overlay-image')) {
                    handler(event);
                }
            }, true);
        }

        addTouchEventListener('touchstart', event => {
            touchStartEvent = event;
            if (event.touches.length > 1) {
                isPinching = true;
            }
            if (!event.isReTriggering) {
                event.stopPropagation();
                handleTouchStart(event);
            }
        });

        addTouchEventListener('touchmove', event => {
            if (!isPinching) {
                event.stopPropagation();
                handleTouchMove(event);
            }
        });

        addTouchEventListener('touchend', event => {
            if (event.touches.length === 0) {
                isPinching = false;
            }
            if (!event.isReTriggering) {
                event.stopPropagation();
                handleTouchEnd(event);
            }
        });

        addTouchEventListener('touchcancel', event => {
            if (!event.isReTriggering) {
                handleTouchEnd(event);
                event.stopPropagation();
            }
        });

        function togglePlay() {
            if (video.paused) {
                video.play();
            } else {
                video.pause();
            }
        }

        function handleTouchStart(event) {
            touchStartTime = Date.now();
            touchStartX = event.touches[0].clientX;
            touchStartY = event.touches[0].clientY;
            isSwiping = false;
            centerTouch = false;
            longTouchSent = false;

            const screenWidth = window.innerWidth;
            const touch = event.touches[0];

            const touchSize = screenWidth * 0.15;
            const isCenterTouch = Math.abs(touch.clientX - screenWidth / 2) < touchSize;

            if (isCenterTouch && !isPinching) {
                centerTouch = true;
            }

            touchTimeout = setTimeout(function() {
                if (!isSwiping && !isPinching) {
                    const side = touch.clientX < screenWidth / 2 ? "left" : "right";
                    sendMessage("longTouch", side);
                    longTouchSent = true;
                }
            }, touchCountsAsLongPress);
        }

        function handleTouchMove(event) {
            if (isSwiping || longTouchSent || isPinching) {
                return;
            }
            const touchMoveX = event.touches[0].clientX;
            const touchMoveY = event.touches[0].clientY;
            const deltaX = touchMoveX - touchStartX;
            const deltaY = touchMoveY - touchStartY;

            if (Math.abs(deltaX) > 10 || Math.abs(deltaY) > 10) {
                isSwiping = true;
                clearTimeout(touchTimeout);
            }
        }

        function handleTouchEnd(event) {
            triggerTouchEvent(event);
            clearTimeout(touchTimeout);
            if (isPinching) {
                // nothing
            } else if (longTouchSent) {
                sendMessage("longTouchEnd");
            } else if (isSwiping) {
                handleSwipe(event);
            } else if (centerTouch) {
                togglePlay();
                sendMessage("centerTouch", video.paused ? "play" : "pause");
            }
        }

        function triggerTouchEvent() {
            if (isSwiping || longTouchSent || centerTouch) {
                return;
            }
            sendMessage("interaction");
            const event = touchStartEvent;

            // Manually trigger the event again with the custom property
            const newEvent = new event.constructor('touchstart', event);
            newEvent.isReTriggering = true;
            event.target.dispatchEvent(newEvent);

            // trigger end as well
            setTimeout(function() {
                const endEvent = new event.constructor('touchend', event);
                endEvent.isReTriggering = true;
                event.target.dispatchEvent(endEvent);
            }, 0);
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
