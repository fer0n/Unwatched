//
//  PlayerWebViewCoordinator+pause.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

extension PlayerWebViewCoordinator {
    /// All a page that has left the hierarchy may still do: report where its own video got to. It must not steer
    /// the player, which by now may be on a different video and a different engine.
    func handleRetiredMessage(_ topic: String, _ payload: String?) {
        guard topic == "pause" else {
            return
        }
        let pause = PausePayload(payload)
        guard let time = pause.time,
              let videoId = pause.videoId else {
            return
        }
        StatsService.shared.handleVideoTimeUpdate(videoId: videoId, time: time, persist: true)
        parent.player.updateElapsedTime(time, videoId: videoId)
    }

    func handlePause(_ payload: String?) {
        guard let payload else {
            Log.warning("No payload given for handlePause")
            return
        }
        let pause = PausePayload(payload)
        let playbackId = UserDefaults.standard.string(forKey: Const.playbackId) ?? ""
        if pause.playbackId != playbackId {
            Log.info("handlePause: playbackId mismatch, not pausing")
            return
        }
        parent.player.reportPaused()

        flushStats(timeString: pause.timeString, urlString: pause.urlString)

        #if os(iOS)
        BackgroundMonitor.handlePause()
        #endif
    }

    func flushStats(timeString: String? = nil, urlString: String? = nil) {
        let videoId: String?
        if let urlString, let url = URL(string: urlString) {
            videoId = UrlService.getYoutubeIdFromUrl(url: url)
        } else {
            videoId = parent.player.video?.youtubeId
        }
        let resolvedTime = timeString ?? parent.player.currentTime.map { String($0) }
        if let videoId {
            handleTimeUpdate(resolvedTime, persist: true, youtubeId: videoId)
        }
    }
}

/// The comma separated fields the page sends with `pause`.
struct PausePayload {
    let timeString: String?
    let playbackId: String?
    let urlString: String?

    init(_ payload: String?) {
        let fields = payload?.split(separator: ",").map(String.init) ?? []
        timeString = fields[safe: 0]
        playbackId = fields[safe: 1]
        urlString = fields[safe: 2]
    }

    var time: Double? {
        timeString.flatMap(Double.init)
    }

    var videoId: String? {
        urlString
            .flatMap { URL(string: $0) }
            .flatMap { UrlService.getYoutubeIdFromUrl(url: $0) }
    }
}
