//
//  YouTubePlayerView.swift
//  Unwatched
//

import SwiftUI
import WebKit
import OSLog
import UnwatchedShared

extension PlayerWebView {

    @MainActor
    func loadPlayer(webView: WKWebView, startAt: Double, type: PlayerType) -> Bool {
        guard let youtubeId = player.video?.youtubeId else {
            Log.warning("loadPlayer: no youtubeId")
            return false
        }
        let urlString = type == .youtube
            ? UrlService.getNonEmbeddedYoutubeUrl(youtubeId, startAt)
            : UrlService.getEmbeddedYoutubeUrl(youtubeId, startAt)

        guard let url = URL(string: urlString) else {
            Log.warning("loadPlayer: no url")
            return false
        }
        Log.info("loadPlayer: \(urlString)")

        let request = URLRequest(url: url)
        webView.load(request)
        return true
    }

    func getPlayScript() -> String {
        if player.unstarted {
            Log.info("PLAY: unstarted")
            return """
                function attemptClick() {
                    document.elementFromPoint(window.innerWidth / 2, window.innerHeight / 2)?.click();
                }
                attemptClick();
                setTimeout(() => checkResult(0), 50);
                function checkResult(retries) {
                    const retryClicks = window.location.href.includes('youtube-nocookie');
                    if (!video.paused) {
                        return;
                    }
                    if (isNaN(video?.duration)) {
                        const offlineElement = document.querySelector('.ytp-offline-slate-subtitle-text');
                        if (offlineElement) {
                            sendMessage("offline", offlineElement.innerText);
                        } else {
                            if (retryClicks) {
                                // workaround: click seems to happen too fast with nocookie url
                                // no other way of awaiting loading worked. Using this sometimes led to the
                                // regular player being stuck with YouTube's loading indicator
                                const element = document.elementFromPoint(
                                    window.innerWidth / 2,
                                    window.innerHeight / 2
                                );
                                if (element.classList.contains('ytp-button') || retries > 0) {
                                    attemptClick();
                                }
                            }
                            if (retries < 4) {
                                setTimeout(() => checkResult(retries + 1), 50 * (retries + 1) * 2);
                            }
                        }
                    }
                }

                // theater mode - workaround: using setTimeout on macOS leads to auto play in some cases
                if (!(video?.offsetWidth >= window.innerWidth * 0.98)) {
                    const theaterButton = document.querySelector(".ytp-size-button");
                    if (theaterButton) {
                        theaterButton.click();
                    }
                }
            """
        }
        return "play();"
    }

    func getPauseScript() -> String {
        """
        video.pause();
        """
    }

    func getSeekToScript(_ seekTo: Double) -> String {
        """
        video.currentTime = \(seekTo);
        startAtTime = \(seekTo);
        """
    }

    func getSeekRelScript(_ seekRel: Double) -> String {
        """
        if (video.duration) {
            video.currentTime = Math.min(video.currentTime + \(seekRel), video.duration - 0.2);
        } else {
            video.currentTime += \(seekRel);
        }
        """
    }

    func getSetPlaybackRateScript() -> String {
        "video.playbackRate = \(player.playbackSpeed);"
    }

    func getEnterPipScript() -> String {
        """
        if (document.pictureInPictureEnabled && !document.pictureInPictureElement) {
            video.requestPictureInPicture().catch(error => {
                sendMessage('pip', error);
            });
        } else {
            sendMessage('pip', "not even trying")
        }
        """
    }

    func getExitPipScript() -> String {
        "document.exitPictureInPicture();"
    }

    struct InitScriptOptions {
        let playbackSpeed: Double
        let startAt: Double
        let requiresFetchingVideoData: Bool?
        let disableCaptions: Bool
        let minimalPlayerUI: Bool
        let isNonEmbedding: Bool
        let hijackFullscreenButton: Bool
        let fullscreenTitle: String
        let enableLogging: Bool
    }

    // swiftlint:disable function_body_length
    static func initScript(_ options: InitScriptOptions) -> String {
        """
        var requiresFetchingVideoData = \(options.requiresFetchingVideoData == true);
        var playbackRate = \(options.playbackSpeed);
        var startAtTime = \(options.startAt);
        var disableCaptions = \(options.disableCaptions);
        var minimalPlayerUI = \(options.minimalPlayerUI);
        const interceptKeys = \(PlayerShortcut.interceptKeysJS);
        const isNonEmbedding = \(options.isNonEmbedding);
        const hijackFullscreenButton = \(options.hijackFullscreenButton);
        const fullscreenTitle = "\(options.fullscreenTitle)";
        const timerInterval = \(Const.elapsedTimeMonitorSeconds * 1000);
        const enableLogging = \(options.enableLogging);

        var video = null;
        let videoFindAttempts = 0;
        var isSwiping = false;


        function sendMessage(topic, payload) {
            window.webkit.messageHandlers.iosListener.postMessage("" + topic + ";" + payload);
        }

        function sendError(error, prefix = "") {
            if (error && error.message) {
                sendMessage("error", `${prefix}${error.message}`);
            } else {
                sendMessage("error", `${prefix}${error}`);
            }
        }


        // Video setup
        findVideo();
        function findVideo() {
            try {
                video = document.querySelector('video');
                if (enableLogging) {
                    sendVideoState(video);
                }
                if (video) {
                    setupVideo();
                } else {
                    const observer = new MutationObserver(() => {
                        video = document.querySelector('video');
                        if (enableLogging) {
                            sendVideoState(video, "videoMutation");
                        }
                        if (video) {
                            observer.disconnect();
                            setupVideo();
                        }
                    });
                    observer.observe(document.body, { childList: true, subtree: true });
                }
            } catch (error) {
                sendError(error);
            }
        }
        function setupVideo() {
            video.playbackRate = playbackRate;
            video.muted = false;
            handleFullscreenButton();
        }
        function repairVideo(message = "") {
            video = document.querySelector('video');
            if (enableLogging) {
                sendVideoState(video, "repairedVideo " + message);
            }
        }


        // Prevent specific keyboard shortcuts from being captured
        function shouldInterceptKeys(event) {
            // Allow all input in text fields
            if (event.target.tagName === 'INPUT' || event.target.tagName === 'TEXTAREA') {
                return false;
            }

            // Check if the current key combination matches any inside the intercept list
            const currentModifiers = [];
            if (event.metaKey) currentModifiers.push('Meta');
            if (event.shiftKey) currentModifiers.push('Shift');
            if (event.ctrlKey) currentModifiers.push('Control');
            if (event.altKey) currentModifiers.push('Alt');

            const key = event.key.toLowerCase?.() || event.key;
            return interceptKeys.some(combo =>
                combo.key === key &&
                combo.modifiers.length === currentModifiers.length &&
                combo.modifiers.every(mod => currentModifiers.includes(mod))
            );
        }
        document.addEventListener('keyup', function(event) {
            if (shouldInterceptKeys(event)) {
                event.stopPropagation();
                event.preventDefault();
            }
        }, true);
        document.addEventListener('keydown', function(event) {
            if (shouldInterceptKeys(event)) {
                event.stopPropagation();
                event.preventDefault();
                const payload = `${event.key}|${event.metaKey}|${event.ctrlKey}|${event.altKey}|${event.shiftKey}`;
                sendMessage('keyboardEvent', payload);
            }
        }, true);


        // Check video state
        function sendVideoState(v, message = "checkVideoState") {
            let info = {
                inDom: document.contains(v),
                sameVideo: video === v,
                video: !!v,
                readyState: v?.readyState,
                networkState: v?.networkState,
                paused: v?.paused,
                ended: v?.ended,
                currentTime: v?.currentTime,
                duration: v?.duration,
                videoWidth: v?.videoWidth,
                videoHeight: v?.videoHeight,
                src: v?.src,
                className: v?.className,
                id: v?.id
            };
            sendMessage(message, JSON.stringify(info));
        }

        if (enableLogging) {
            function checkVideoState() {
                const videos = document.querySelectorAll('video');
                sendMessage('videoCount', videos.length);

                videos.forEach((v, index) => {
                    sendVideoState(v, `checkVideoState ${index}`);
                });
            }
            checkVideoState();
            setInterval(checkVideoState, 3000);
        }


        document.addEventListener('play', (e) => {
            if (e.target.tagName === 'VIDEO') {
                startTimer();
                sendMessage("play")
            }
        }, true);
        document.addEventListener('pause', (e) => {
            if (e.target.tagName === 'VIDEO') {
                stopTimer();
                const url = window.location.href;
                const payload = `${e.target.currentTime},${url}`;
                sendMessage("pause", payload);
            }
        }, true);
        document.addEventListener('ended', (e) => {
            if (e.target.tagName === 'VIDEO') {
                sendMessage("ended");
            }
        }, true);

        // meta data
        document.addEventListener('loadedmetadata', (e) => {
            if (e.target.tagName === 'VIDEO') {
                const duration = e.target.duration;
                sendMessage("duration", duration.toString());
                if (requiresFetchingVideoData) {
                    sendMessage('updateTitle', document.title);
                }
                e.target.currentTime = startAtTime;
            }
        }, true);
        document.addEventListener('loadeddata', (e) => {
            if (e.target.tagName === 'VIDEO') {
                sendMessage("aspectRatio", `${e.target.videoWidth/e.target.videoHeight}`);
            }
        }, true);


        // Pip
        document.addEventListener("canplay", (e) => {
            if (e.target.tagName === 'VIDEO') {
                sendMessage("pip", "canplay");

                e.target.addEventListener('webkitpresentationmodechanged', (e) => {
                    e.stopPropagation()
                }, true)
            }
        }, true);
        document.addEventListener("enterpictureinpicture", (e) => {
            if (e.target.tagName === 'VIDEO') {
                sendMessage("pip", "enter");
            }
        }, true);
        document.addEventListener("leavepictureinpicture", (e) => {
            if (e.target.tagName === 'VIDEO') {
                sendMessage("pip", "exit");
            }
        }, true);


        // styling
        styling()
        function styling() {
            const style = document.createElement('style');
            style.innerHTML = `
                .ytp-pause-overlay, .branding-img {
                    display: none !important;
                }
                ${!isNonEmbedding
                    ? '.ytp-play-progress { background: #ddd !important; }'
                    : ''}
                .videowall-endscreen {
                    opacity: 0.2;
                }
                body, html {
                    overflow: hidden !important;
                    touch-action: none !important;
                }
                ${disableCaptions
                    ? '.ytp-caption-window-container, .ytp-subtitles-button { display: none !important; }'
                    : ''}
                ${minimalPlayerUI
                    ? '.ytp-chrome-top, .ytp-gradient-top, .ytp-airplay-button, .ytp-info-panel-preview, ' +
                      '.ytp-pip-button, .ytp-mute-button { display: none !important; } '
                    : ''}
            `;
            document.head.appendChild(style);
        }


        // handleFullscreenButton
        function handleFullscreenButton() {
            if (!hijackFullscreenButton) {
                return
            }
            const fullscreenButton = document.querySelector('.ytp-fullscreen-button');
            if (fullscreenButton) {
                fullscreenButton.style.opacity = 1;
                fullscreenButton.style.cursor = 'pointer';
                fullscreenButton.disabled = false;
                fullscreenButton.title = fullscreenTitle;
                fullscreenButton.addEventListener('click', function(event) {
                    event.stopPropagation();
                    event.preventDefault();
                    sendMessage("fullscreen");
                }, true);
            }

            // Listen for double click and send fullscreen message
            let clickTimeout;
            let clickCount = 0;
            let pendingClick = null;

            document.addEventListener('click', function(event) {
                if (event.target.matches('video')
                    || event.target.matches('.ytp-cued-thumbnail-overlay-image')
                    || event.target.matches('.videowall-endscreen')
                    || event.target.matches('.ytp-videowall-still-info-content')) {
                    if (event.isReTriggering) {
                        return;
                    }
                    event.stopPropagation();
                    event.preventDefault();
                    if (pendingClick) {
                        // This is the second click - it's a double click
                        clearTimeout(clickTimeout);
                        pendingClick = null;
                        sendMessage("fullscreen");
                    } else {
                        // This is the first click - wait to see if there's a second one
                        pendingClick = event;
                        clickTimeout = setTimeout(function() {
                            const newEvent = new event.constructor('click', event);
                            newEvent.isReTriggering = true;
                            pendingClick.target.dispatchEvent(newEvent);
                            pendingClick = null;
                        }, 200);
                    }
                }
            }, true);
        }


        // elapsed time
        var timer;
        function startTimer() {
            clearInterval(timer);
            timer = setInterval(function() {
                let time = video?.currentTime || null;
                sendMessage("currentTime", time);
                if (time === null || document.contains(video) === false) {
                    repairVideo("startTimer");
                }
            }, timerInterval);
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
                if (event.target.matches('video')
                    || event.target.matches('.ytp-cued-thumbnail-overlay-image')
                    || event.target.matches('.videowall-endscreen')
                    || event.target.matches('.ytp-videowall-still-info-content')) {
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

        function play() {
            video.play()
                .catch(error => {
                    sendError(error, "silent ");
                    repairVideo("play");
                });
        }

        function togglePlay() {
            if (video.paused) {
                play();
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
            const screenHeight = window.innerHeight;
            const touch = event.touches[0];

            const maxTouchSize = Math.min(100, screenWidth * 0.15);
            const isHorizontalCenter = Math.abs(touch.clientX - screenWidth / 2) < maxTouchSize;
            const isVerticalCenter = Math.abs(touch.clientY - screenHeight / 2) < maxTouchSize;

            if (isHorizontalCenter && isVerticalCenter && !isPinching) {
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
        if (!isNonEmbedding) {
            var errorCheckTimers = [];

            function checkError() {
                const errorContent = document.querySelector('.ytp-error-content')
                if (errorContent) {
                    sendMessage("youtubeError", errorContent?.innerText);
                }
            }
            function cancelErrorChecks() {
                errorCheckTimers.forEach(clearTimeout);
                errorCheckTimers = [];
            }

            // check for errors
            checkError()
            errorCheckTimers.push(setTimeout(checkError, 1000));
            errorCheckTimers.push(setTimeout(checkError, 3000));
            errorCheckTimers.push(setTimeout(checkError, 5000));
            errorCheckTimers.push(setTimeout(checkError, 10000));
        }

        // Handle link clicks
        document.addEventListener('click', function(event) {
            sendMessage("click");
            // Find if the clicked element is an <a> tag or is inside one
            let target = event.target;
            if (target.tagName === 'A' || target.parentNode?.tagName === 'A') {
                event.preventDefault();
                event.stopPropagation();

                const href = target.tagName === 'A' ? target.href : target.parentNode.href;
                sendMessage("urlClicked", href);
            }
        }, true);
    """
    }
    // swiftlint:enable function_body_length
}
