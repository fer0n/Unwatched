//
//  YouTubePlayerView.swift
//  Unwatched
//

import SwiftUI
import WebKit
import OSLog
import UnwatchedShared

extension PlayerWebView {
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
        let originalAudio: Bool
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
        const originalAudio = \(options.originalAudio);

        var video = null;
        let videoFindAttempts = 0;
        var isSwiping = false;

        let overlay = document.querySelector('#player-control-overlay');
        let isNewEmbedding = !!overlay; // initially found means new embedding player


        function sendMessage(topic, payload) {
            window.webkit.messageHandlers.iosListener.postMessage("" + topic + ";" + payload);
        }

        function sendError(error) {
            if (error && error.message) {
                sendMessage("error", error.message);
            } else {
                sendMessage("error", error);
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
            addVideoListeners();
            video.playbackRate = playbackRate;
            video.muted = false;
            handleFullscreenButton();
        }
        function repairVideo(message = "") {
            video = document.querySelector('video');
            sendVideoState(video, "repairedVideo " + message);
            setupVideo();
        }

        // Overlay control
        let overlayVisible = overlay && overlay.classList.contains('fadein');
        let overlayHideTimer = null;
        let lastTapDate = null;
        let consecutiveSingleTaps = 0;
        let allowFadeinChanges = false;
        sendMessage('isNewEmbedding', isNewEmbedding);

        setupOverlay();
        if (minimalPlayerUI) {
            hideOverlay();
        }
        document.addEventListener('pointerup', function(event) {
            if (event.pointerType !== 'mouse') return;
            if (isVideoElement(event)) {
                handleOverlayTap();
            }
        });

        function isOverlayHealthy() {
            if (document.contains(overlay)) {
                return true;
            }
            console.log('isOverlayHealthy: query overlay');
            overlay = document.querySelector('#player-control-overlay');
            if (!overlay) {
                console.log('isOverlayHealthy: not in DOM');
                return false;
            }
            console.log('isOverlayHealthy: repaired');
            setupOverlay();
            return true;
        }
        function overlayHealthCheckPolling() {
            if (!isNewEmbedding) return;
            let timers = [];
            function checkOverlay() {
                const isHealthy = isOverlayHealthy();
                console.log('checkOverlay, healthy:', isHealthy);
                if (isHealthy) {
                    cancelChecks();
                }
            }
            function cancelChecks() {
                console.log("cancelChecks");
                timers.forEach(clearTimeout);
                timers = [];
            }
            timers.push(setTimeout(checkOverlay, 1000));
            timers.push(setTimeout(checkOverlay, 3000));
            timers.push(setTimeout(checkOverlay, 8000));
        }

        function toggleOverlay() {
            if (!isNewEmbedding) return;
            if (overlay) {
                if (overlayVisible) {
                    hideOverlay();
                } else {
                    showOverlay();
                }
            }
        }

        function debouncedHideOverlay(duration = 2500) {
            if (!overlayVisible || !isNewEmbedding) return;
            clearTimeout(overlayHideTimer);
            overlayHideTimer = setTimeout(() => {
                const element = document.querySelector('yt-bigboard');
                const isScrubbing = element.children.length > 0;
                if (!isScrubbing && !video.paused) {
                    hideOverlay();
                }
            }, duration);
        }

        function setupOverlay() {
            if (!overlay || !isNewEmbedding) return;
            // Override setAttribute to block fadein changes (except when we allow it)
            const originalSetAttribute = overlay.setAttribute;
            overlay.setAttribute = function(name, value) {
                if (name === 'class' && !allowFadeinChanges) {
                    const currentClasses = overlay.className.split(' ');
                    const newClasses = value.split(' ');

                    const currentHasFadein = currentClasses.includes('fadein');
                    const newHasFadein = newClasses.includes('fadein');

                if (currentHasFadein !== newHasFadein) {
                        return;
                    }
                }
                return originalSetAttribute.call(this, name, value);
            };
            // Block classList methods for fadein (except when we allow it)
            ['add', 'remove', 'toggle'].forEach(method => {
                const original = overlay.classList[method];
                overlay.classList[method] = function(...args) {
                if (args.includes('fadein') && !allowFadeinChanges) {
                    return;
                }
                return original.apply(this, args);
                };
            });
        }

        function showOverlay() {
            if (overlayVisible || !isNewEmbedding) return;
            allowFadeinChanges = true;
            overlay.classList.add('fadein');
            allowFadeinChanges = false;
            overlayVisible = true;
            sendMessage('overlay', 'show');
             if (!video.paused) {
                debouncedHideOverlay();
             }
        };

        function hideOverlay() {
            isOverlayHealthy();
            if (!overlayVisible || !isNewEmbedding) return;
            allowFadeinChanges = true;
            overlay.classList.remove('fadein');
            allowFadeinChanges = false;
            overlayVisible = false;
            sendMessage('overlay', 'hide');
            clearTimeout(overlayHideTimer);
        };


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

        function addVideoListeners() {
            video.addEventListener('seeked', () => {
                debouncedHideOverlay(1000);
            });
            video.addEventListener('ratechange', () => {
                sendMessage('playbackRate', video.playbackRate);
            });
        }
        document.addEventListener('play', (e) => {
            if (e.target.tagName === 'VIDEO') {
                startTimer();
                sendMessage("play");
            }
            hideOverlay();
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
        if (requiresFetchingVideoData) {
            fetchVideoData();
        }
        function fetchVideoData() {
            // thumbnail url
            const img = document.querySelector('.ytmVideoCoverThumbnail')?.style?.backgroundImage;
            const thumbnailUrl = img ? img.slice(5, -2) : '';

            // channelId
            const channelLink = document.querySelector('.ytmVideoInfoChannelTitle');
            let channelId = null;
            if (channelLink) {
                const href = channelLink.getAttribute('href');
                if (href && href.startsWith('/channel/')) {
                    channelId = href.split('/')[2];
                }
            }

            // channel title
            const channelTitle = document.querySelector(".ytmVideoInfoChannelTitle .ytmVideoInfoLink")?.innerText;

            // title
            let title = document.title?.replace(/- YouTube$/, '').trim();

            const data = { thumbnailUrl, channelId, channelTitle, title };
            sendMessage('videoData', JSON.stringify(data));
        }

        document.addEventListener('loadedmetadata', (e) => {
            if (e.target.tagName === 'VIDEO') {
                const duration = e.target.duration;
                sendMessage("duration", duration.toString());
                e.target.currentTime = startAtTime;
                handleAudioTrack();

                // setting video time so early breaks the overlay reference
                overlayHealthCheckPolling();
            }
        }, { capture: true, once: true });
        document.addEventListener('loadeddata', (e) => {
            if (e.target.tagName === 'VIDEO') {
                sendMessage("aspectRatio", `${e.target.videoWidth/e.target.videoHeight}`);
            }
        }, true);


        // Audio Tracks
        const ORIGINAL_TRANSLATIONS = [
            "original", // English (en)
            "оригинал", // Russian (ru_RU)
            "オリジナル", // Japanese (ja_JP)
            "原始", // Chinese Simplified (zh_CN)
            "원본", // Korean (ko_KR)
            "origineel", // Dutch (nl_NL)
            "original", // Spanish (es_ES) / Portuguese (pt_BR)
            "originale", // Italian (it_IT) / French (fr_FR)
            "original", // German (de_DE)
            "oryginał", // Polish (pl_PL)
            "původní", // Czech (cs_CZ)
            "αρχικό", // Greek (el_GR)
            "orijinal", // Turkish (tr_TR)
            "原創", // Traditional Chinese (zh_TW)
            "gốc", // Vietnamese (vi_VN)
            "asli", // Indonesian (id_ID)
            "מקורי", // Hebrew (he_IL)
            "أصلي", // Arabic (ar_EG)
            "मूल", // Hindi (hi_IN)
            "मूळ", // Marathi (mr_IN)
            "ਪ੍ਰਮਾਣਿਕ", // Punjabi (pa_IN)
            "అసలు", // Telugu (te_IN)
            "மூலம்", // Tamil (ta_IN)
            "মূল", // Bengali (bn_BD)
            "അസലി", // Malayalam (ml_IN)
            "ต้นฉบับ", // Thai (th_TH)
        ];

        function getOriginalTrack(tracks) {
            if (!tracks || !Array.isArray(tracks)) {
                return null;
            }
            let languageFieldName = null;
            for (const track of tracks) {
                if (!track || typeof track !== "object") {
                    continue;
                }
                for (const [fieldName, field] of Object.entries(track)) {
                    if (field && typeof field === "object" && field.name) {
                        languageFieldName = fieldName;
                        break;
                    }
                }
                if (languageFieldName) {
                    break;
                }
            }
            if (!languageFieldName) {
                return;
            }
            for (const track of tracks) {
                if (!track || !track[languageFieldName] || !track[languageFieldName].name) {
                    continue;
                }
                const trackName = track[languageFieldName].name.toLowerCase();
                for (const originalWord of ORIGINAL_TRANSLATIONS) {
                    if (trackName.includes(originalWord.toLowerCase())) {
                        // sendMessage(`setting original audio track as ${trackName} with id ${track.id}`);
                        return track;
                    }
                }
            }
            sendError("No original audio track found");
        }

        async function handleAudioTrack() {
            if (!originalAudio) {
                return;
            }
            const player = document.getElementById("movie_player");
            const tracks = player.getAvailableAudioTracks();
            const currentTrack = await player.getAudioTrack();

            if (!tracks || !currentTrack) {
                return;
            }
            const originalTrack = getOriginalTrack(tracks);

            if (originalTrack) {
                if (`${originalTrack}` === `${currentTrack}`) {
                    return;
                }
                const isAudioTrackSet = await player.setAudioTrack(originalTrack);
                if (isAudioTrackSet) {
                    sendMessage(`Audio track set to original: ${originalTrack.name}`);
                }
            }
        }


        // Pip
        document.addEventListener("canplay", (e) => {
            if (e.target.tagName === 'VIDEO') {
                sendMessage("pip", "canplay");

                e.target.addEventListener('webkitpresentationmodechanged', (e) => {
                    e.stopPropagation()
                }, true)
            }
        }, { capture: true, once: true });
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
            if (!isNewEmbedding) {
                style.textContent = `
                    * {
                        cursor: default !important;
                    }
                    .ytp-pause-overlay, .branding-img {
                        display: none !important;
                    }
                    @media (max-width: 200px) {
                        .ytp-gradient-top, .ytp-chrome-top, .ytp-button, .ytp-impression-link,
                        .ytp-chrome-bottom {
                            display: none !important;
                        }
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
                    ${minimalPlayerUI ? `
                        .ytp-chrome-top, .ytp-gradient-top, .ytp-airplay-button, .ytp-volume-panel,
                        .ytp-info-panel-preview, .ytp-pip-button, .ytp-mute-button {
                            display: none !important;
                        }
                        ` : ''}
                `;
            } else {
                style.textContent = `
                    * {
                        cursor: default !important;
                    }
                    .branding-img {
                        display: none !important;
                    }
                    @media (max-width: 200px) {
                        #player-control-overlay, .ytmCuedOverlayPlayButton, .ytmCuedOverlayGradient {
                            display: none !important;
                        }
                    }
                    ${!isNonEmbedding ? `
                        .ytProgressBarPlayheadProgressBarPlayheadDot,
                        .ytChapteredProgressBarChapteredPlayerBarChapterSeen,
                        .ytChapteredProgressBarChapteredPlayerBarFill,
                        .ytProgressBarLineProgressBarPlayed {
                            background: #ddd !important;
                        }
                        ` : ''}
                    ${disableCaptions ? `
                        .ytp-caption-window-container, .ytmClosedCaptioningButtonButton {
                            display: none !important;
                        }
                        ` : ''}
                    ${minimalPlayerUI ? `
                        .ytmVideoInfoVideoDetailsContainer, .icon-add_to_watch_later,
                        .fullscreen-watch-next-entrypoint-wrapper, .endscreen-replay-button,
                        .player-control-play-pause-icon, .player-controls-spinner,
                        .fullscreen-recommendations-wrapper, .ytmPaidContentOverlayHost,
                        .ytmEmbedsInfoPanelRendererButton, .ytmMuteButtonButton, .ytmCuedOverlayGradient {
                            display: none !important;
                        }
                        .player-settings-icon, .ytmClosedCaptioningButtonHost {
                            background: radial-gradient(circle, rgba(0, 0, 0, 0.18) 52%, transparent 0%) !important;
                        }
                        #player-control-overlay.fadein .player-controls-background {
                            background: linear-gradient(
                                to bottom,
                                transparent,
                                transparent calc(100% - 145px),
                                rgba(0, 0, 0, 0.6) calc(100% - 20px)
                            ) !important;
                        }
                        ` : ''}
                `;
            }
            document.head.appendChild(style);
        }


        // handleFullscreenButton
        function handleFullscreenButton() {
            if (!hijackFullscreenButton) {
                return
            }
            let fullscreenButton = null;
            if (!isNewEmbedding) {
                fullscreenButton = document.querySelector('.ytp-fullscreen-button');
            } else {
                fullscreenButton = document.querySelector('.fullscreen-icon');
            }
            if (fullscreenButton) {
                fullscreenButton.style.opacity = 1;
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
                if (isVideoElement(event)) {
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

        function isVideoElement(event) {
            return event.target.matches('video')
                || event.target.matches('.ytp-cued-thumbnail-overlay-image')
                || event.target.matches('.videowall-endscreen')
                || event.target.matches('.ytp-videowall-still-info-content')

                // new embedded player
                || event.target.matches('.player-controls-background')
                || event.target.matches('.fullscreen-action-menu')
                || event.target.matches('.ytmVideoInfoHost')
                || event.target.matches('.ytwPlayerMiddleControlsHost')
                || event.target.matches('.player-controls-bottom')
                || event.target.matches('.ytmCuedOverlayHost')
        }

        function addTouchEventListener(eventType, handler) {
            window.addEventListener(eventType, event => {
                if (isVideoElement(event)) {
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
                play();
            } else {
                video.pause();
            }
        }

        function play() {
            video.play()
                .catch(error => {
                    sendError(error);
                    repairVideo("play");
                });
            if (overlayVisible) {
                hideOverlay();
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
            } else {
                handleOverlayTap();
            }
        }

        function handleOverlayTap() {
            if (!isNewEmbedding) return;
            const now = Date.now();
            if (lastTapDate && now - lastTapDate < 300) {
                consecutiveSingleTaps += 1;
                handleDoubleTapSeek(event);
            } else {
                consecutiveSingleTaps = 0;
            }
            lastTapDate = now;
            if ((consecutiveSingleTaps ?? 0) < 1) {
                toggleOverlay();
            }
        }

        function handleDoubleTapSeek(event) {
            event.stopPropagation();
            event.preventDefault();
            showOverlay();
            const touchEndX = event.changedTouches?.[0]?.clientX;
            const screenWidth = window.innerWidth;
            const seekRel = (touchEndX < screenWidth / 2 ? -1 : 1) * 10;
            video.currentTime += seekRel;
        }

        function triggerTouchEvent() {
            if (isSwiping || longTouchSent || centerTouch) {
                return;
            }
            if (!isNewEmbedding) {
                sendMessage("interaction");
            }
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
            function checkError() {
                const errorContent = document.querySelector('.ytp-error-content')
                if (errorContent) {
                    sendMessage("youtubeError", errorContent?.innerText);
                }
            }
            // check for errors
            checkError()
            setTimeout(checkError, 1000);
            setTimeout(checkError, 3000);
            setTimeout(checkError, 5000);
            setTimeout(checkError, 10000);
        }

        // Handle link clicks
        document.addEventListener('click', function(event) {
            sendMessage("click");

            let target = event.target;
            let link = null;
            if (target.tagName === 'A') {
                link = target;
            } else if (target.parentNode?.tagName === 'A') {
                link = target.parentNode;
            } else if (target.parentNode?.parentNode?.tagName === 'A') {
                link = target.parentNode.parentNode;
            }
            if (link) {
                event.preventDefault();
                event.stopPropagation();
                sendMessage("urlClicked", link.href);
            }
        }, true);
    """
    }
    // swiftlint:enable function_body_length
}
