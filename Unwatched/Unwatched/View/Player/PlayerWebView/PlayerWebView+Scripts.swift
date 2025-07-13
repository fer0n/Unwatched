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

        var request = URLRequest(url: url)
        let referer = "https://app.local.com"
        request.setValue(referer, forHTTPHeaderField: "Referer")
        webView.load(request)
        return true
    }

    func getPlayScript() -> String {
        if player.unstarted {
            Log.info("PLAY: unstarted")
            return """
                hideOverlay();
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
}
