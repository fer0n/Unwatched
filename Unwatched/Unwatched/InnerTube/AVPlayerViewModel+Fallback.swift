//
//  AVPlayerViewModel+Fallback.swift
//  Unwatched
//

import AVKit
import OSLog
import SwiftUI
import UnwatchedShared

extension APIError {
    static func isRemoved(_ error: Error?) -> Bool {
        if case .removed = error as? APIError { true } else { false }
    }
}

/// What the player does when resolving a stream produced a verdict no client will get past.
extension AVPlayerViewModel {

    /// A premiere or live stream that hasn't started has nothing to resolve, on any client.
    @MainActor
    func handleScheduledVideo(_ error: Error, videoId: String) -> Bool {
        guard case APIError.scheduled(let date) = error else { return false }
        guard player.video?.youtubeId == videoId else { return true }
        Log.player.info("[AVPlayerView] scheduled video \(videoId): starts \(date?.formatted() ?? "unknown")")
        player.isLoading = nil
        player.pause()
        clearPendingReposition()
        loadError = error
        if let date {
            player.deferVideoDate = date
        } else {
            // no start time to pre-fill; the selector opens on its own default
            NavigationManager.shared.showDeferDateSelector = true
        }
        return true
    }

    /// Age gates are handed off to the YouTube page, the one player with the user's session.
    @MainActor
    func handleAgeRestrictedVideo(_ error: Error, videoId: String) -> Bool {
        guard case APIError.ageRestricted = error else { return false }
        guard player.video?.youtubeId == videoId else { return true }
        Log.player.info("[AVPlayerView] age-restricted, no client can serve it: \(videoId)")
        if !failPlayback(error) {
            player.pause()
        }
        return true
    }

    /// Shows the error, or hands off to the YouTube page if the native player was a fallback.
    @MainActor
    @discardableResult
    func failPlayback(_ error: Error?) -> Bool {
        clearPendingReposition()
        // the YouTube page can't play a removed video either
        if !APIError.isRemoved(error), handOffToWebsitePlayer() { return true }
        player.isLoading = nil
        loadError = error
        return false
    }

    @MainActor
    private func handOffToWebsitePlayer() -> Bool {
        #if os(iOS)
        // the page can't load without a screen
        guard player.nativeFallbackActive, !BackgroundMonitor.inBackground else { return false }
        Log.player.info("[AVPlayerView] native fallback failed: handing off to the YouTube page")
        player.nativeFallbackActive = false
        player.swapToWebsitePlayer(forceResume: true)
        player.restorePickedPlayer()
        return true
        #else
        return false
        #endif
    }

    // MARK: - Cut-short streams

    /// A live stream that just ended is served as a few minutes of its live playlist until YouTube has processed it.
    @MainActor
    func isCutShort(_ item: AVPlayerItem) -> Bool {
        let length = item.duration.seconds
        guard let reportedLength, length.isFinite, length > 0 else { return false }
        return reportedLength - length > max(60, reportedLength * 0.1)
    }

    @MainActor
    func handlePlayedToEnd(item: AVPlayerItem, videoId: String) {
        if let window = liveWindow(of: item), hasLiveEdgeMoved(item, to: window.end.seconds) {
            Log.player.info("[AVPlayerView] caught up with the live stream: \(videoId)")
            lastStalledAt = Date()
            let recommended = item.recommendedTimeOffsetFromLive.seconds
            let offset = recommended.isFinite ? max(recommended, Self.minLiveEdgeOffset) : Self.minLiveEdgeOffset
            seek(to: max(window.start.seconds, window.end.seconds - offset))
            return
        }
        guard isCutShort(item) else {
            onVideoEnded()
            return
        }
        Log.player.warning("[AVPlayerView] cut-short stream ran out, not ending the video: \(videoId)")
        if !failPlayback(APIError.unavailable("Unable to play this video")) {
            player.pause()
        }
    }

    // MARK: - Live edge

    static let liveEdgeZone: Double = 30
    static let liveEdgeStallZone: Double = 5
    static let minLiveEdgeOffset: Double = 10

    /// Close enough to a live stream's edge that playing faster would run out.
    @MainActor
    var isNearLiveEdge: Bool { (distanceFromLiveEdge ?? .infinity) < Self.liveEdgeZone }

    @MainActor
    var isAtLiveEdge: Bool { (distanceFromLiveEdge ?? .infinity) < Self.liveEdgeStallZone }

    @MainActor
    private var distanceFromLiveEdge: Double? {
        guard let window = liveWindow(of: avPlayer.currentItem) else { return nil }
        return window.end.seconds - (lastObservedTime ?? avPlayer.currentTime().seconds)
    }

    @MainActor
    private func liveWindow(of item: AVPlayerItem?) -> CMTimeRange? {
        guard let item, item.duration.isIndefinite else { return nil }
        return item.seekableTimeRanges.last?.timeRangeValue
    }

    /// A broadcast that stopped without ending its playlist keeps the same edge.
    @MainActor
    private func hasLiveEdgeMoved(_ item: AVPlayerItem, to edge: Double) -> Bool {
        defer { lastCaughtUpLiveEdge = (ObjectIdentifier(item), edge) }
        guard let last = lastCaughtUpLiveEdge, last.item == ObjectIdentifier(item) else { return true }
        return edge > last.edge
    }

    @MainActor
    func restoreSpeedAfterLiveSeek() {
        guard liveWindow(of: avPlayer.currentItem) != nil, player.isPlaying, avPlayer.rate != 0 else { return }
        startAtCurrentSpeed()
    }
}
