//
//  BrowserManager.swift
//  Unwatched
//

import SwiftUI
import WebKit
import UnwatchedShared

@Observable class BrowserManager {
    var info: SubscriptionInfo?
    var currentUrl: URL?

    var desktopUserName: String?
    var firstPageLoaded = false
    var isMobileVersion = true
    var isVideoUrl = false

    var hasCheckedInfo = false

    @MainActor
    @ObservationIgnored weak var webView: WKWebView?

    var channelTextRepresentation: String? {
        if info?.playlistId != nil {
            return "Playlist\(info?.title != nil ? " (\(info?.title ?? ""))" : "")"
        }
        if let name = info?.title ?? info?.userName {
            return name
        }
        if hasCheckedInfo {
            return info?.channelId ?? info?.rssFeed
        }
        return nil
    }

    func setFoundInfo(_ info: SubscriptionInfo) {
        self.info = info
    }

    func clearInfo() {
        self.info = nil
        self.desktopUserName = nil
        self.hasCheckedInfo = false
    }

    @MainActor
    func stopPlayback() {
        guard let webView else {
            return
        }
        webView.pauseAllMediaPlayback()
    }

    @MainActor
    func getCurrentTime() async -> Double? {
        guard let webView else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(getCurrentTimeScript()) { (result, error) in
                var currentTimeResult: Double?
                if let error {
                    Log.error("JavaScript evaluation error: \(error)")
                } else if let currentTime = result as? Double {
                    Log.info("Current time: \(currentTime)")
                    currentTimeResult = currentTime
                } else {
                    Log.warning("Could not get current time from video")
                }
                continuation.resume(returning: currentTimeResult)
            }
        }
    }

    func getCurrentTimeScript() -> String {
        """
        (function() {
            const video = document.querySelector('video');
            if (video) {
                return video.currentTime;
            } else {
                return null;
            }
        })();
        """
    }
}
