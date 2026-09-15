//
//  WatchStreamResolver.swift
//  UnwatchedWatch
//

import Foundation
import UnwatchedShared

/// Turns a queued video into a URL the watch can stream audio from.
///
/// Podcast episodes carry their own media URL and need no lookup at all. YouTube videos go through
/// the shared InnerTube client, exactly as tvOS does and for the same reason: the web clients want a
/// browser session (visitor data, a signature timestamp, a proof-of-origin token minted by YouTube's
/// own JavaScript) that a device with no WKWebView cannot produce.
///
/// **Why the muxed file first, and why a list at all:** the adaptive audio-only format looks like
/// the obvious pick — at ~130 kbps it is a sixth of the bytes and the radio time of the 360p muxed
/// file, and this app throws the picture away regardless. It does not work. Those CDN URLs are the
/// ones the tvOS resolver describes as refusing requests without a closed byte range, and
/// AVFoundation does not send one: measured on watchOS 26.5, the item goes to `.failed` with
/// `unknown error` about 200 ms in, every time. So the muxed file leads, exactly as on tvOS, and
/// audio-only follows as a candidate in case a given video or a real device disagrees — a failed
/// candidate costs the fraction of a second it takes the item to fail.
enum WatchStreamResolver {
    /// One instance for the app: it holds the session, the visitor data and a network-path monitor
    /// that resets it, all of which are worth keeping across videos.
    private static let api = InnerTubeAPI()

    /// Playable URLs for a video, best first. A podcast episode has exactly one.
    static func streamCandidates(for video: Video) async throws -> [URL] {
        if let mediaUrl = video.mediaUrl {
            return [mediaUrl]
        }
        return try await youtubeCandidates(for: video.youtubeId)
    }

    static func youtubeCandidates(for youtubeId: String) async throws -> [URL] {
        // The iOS client resolves the most videos, so it goes first even though it rarely has a
        // muxed format; Android is what usually supplies one.
        let attempts: [(client: String, fetch: () async throws -> PlayerInfo)] = [
            ("iOS", { try await api.fetchPlayerInfo(videoId: youtubeId) }),
            ("Android", { try await api.fetchPlayerInfoAndroid(videoId: youtubeId) }),
            ("Android VR", { try await api.fetchPlayerInfoAndroidVR(videoId: youtubeId) })
        ]

        var firstError: Error?
        var muxed: [URL] = []
        var audioOnly: [URL] = []

        for attempt in attempts {
            do {
                let info = try await attempt.fetch()
                if let url = info.preferredStreamURL { muxed.append(url) }
                if let url = info.bestAdaptiveAudioURL { audioOnly.append(url) }
                Log.info(
                    "\(attempt.client) client: \(info.preferredStreamURL == nil ? 0 : 1) muxed, "
                        + "\(info.bestAdaptiveAudioURL == nil ? 0 : 1) audio-only for \(youtubeId)"
                )
                // The muxed file is the one that actually plays, so stop as soon as one turns up
                // rather than paying for the remaining clients' round trips.
                if !muxed.isEmpty { break }
            } catch {
                Log.info("\(attempt.client) client failed for \(youtubeId): \(error.localizedDescription)")
                // The iOS client's error is the one worth surfacing: it's the only one that
                // reports on the video itself rather than on its own restrictions.
                firstError = firstError ?? error
            }
        }

        let candidates = muxed + audioOnly
        if !candidates.isEmpty {
            return candidates
        }
        throw WatchPlaybackError(firstError)
    }
}

/// The failures worth telling a listener about. `APIError`'s own messages are English-only, and on a
/// watch most of its cases come to the same thing: this won't play here.
enum WatchPlaybackError: LocalizedError {
    case signInRequired
    case unavailable(String)
    case noStream

    init(_ error: Error?) {
        switch error as? APIError {
        case .signInRequired, .ageRestricted:
            self = .signInRequired
        case .unavailable(let reason), .ipBlocked(let reason):
            self = .unavailable(reason)
        default:
            self = .noStream
        }
    }

    var errorDescription: String? {
        switch self {
        case .signInRequired: String(localized: "watchVideoRequiresSignIn")
        case .unavailable(let reason): reason
        case .noStream: String(localized: "watchVideoNoStream")
        }
    }
}
