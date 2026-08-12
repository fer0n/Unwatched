//
//  TvStreamResolver.swift
//  UnwatchedTV
//

import Foundation
import UnwatchedShared

/// Resolves a video to a URL AVPlayer can play, using the shared InnerTube client.
///
/// Only the app-flavoured clients are asked. The web ones answer "the page needs to be reloaded"
/// or "video unavailable" unless the request carries a browser session — visitor data, a signature
/// timestamp and a proof-of-origin token minted by YouTube's own JavaScript — none of which is
/// obtainable on tvOS, where there is no WKWebView.
///
/// **Why 360p:** `preferredStreamURL` hands back an HLS manifest when there is one, which for
/// video-on-demand there no longer is — leaving the muxed file, and YouTube only muxes 360p. The HD
/// streams next to it are video-only and audio-only, and their CDN URLs are throttled to roughly a
/// third of realtime without that same proof-of-origin token (measured: ~50 KB/s against the
/// ~610 KB/s a 1080p stream needs, with 403s for anything read ahead of the pacing budget). They
/// also refuse any request without a closed byte range, which AVFoundation doesn't send. The muxed
/// file has neither problem — it downloads far faster than realtime. Anything better needs the web
/// player, which is why the iPhone and iPad app keeps one.
enum TvStreamResolver {
    /// One instance for the app: it holds the session, the visitor data and a network-path monitor
    /// that resets it, all of which are worth keeping across videos.
    private static let api = InnerTubeAPI()

    static func streamURL(for youtubeId: String) async throws -> URL {
        // The iOS client resolves the most videos, so it goes first even though it rarely has a
        // muxed format; Android is what usually supplies one.
        let attempts: [(client: String, fetch: () async throws -> PlayerInfo)] = [
            ("iOS", { try await api.fetchPlayerInfo(videoId: youtubeId) }),
            ("Android", { try await api.fetchPlayerInfoAndroid(videoId: youtubeId) }),
            ("Android VR", { try await api.fetchPlayerInfoAndroidVR(videoId: youtubeId) })
        ]

        var firstError: Error?
        for attempt in attempts {
            do {
                let info = try await attempt.fetch()
                if let url = info.preferredStreamURL {
                    Log.info("\(attempt.client) client resolved a stream for \(youtubeId)")
                    return url
                }
                Log.info("\(attempt.client) client returned no playable format for \(youtubeId)")
            } catch {
                Log.info("\(attempt.client) client failed for \(youtubeId): \(error.localizedDescription)")
                // The iOS client's error is the one worth surfacing: it's the only one that
                // reports on the video itself rather than on its own restrictions.
                firstError = firstError ?? error
            }
        }
        throw TvPlaybackError(firstError)
    }
}

/// The failures worth telling a viewer about, in their language — `APIError`'s own messages are
/// English-only, and most of its cases mean the same thing on a TV: this won't play.
enum TvPlaybackError: LocalizedError {
    case signInRequired
    case unavailable(String)
    case noStream

    init(_ error: Error?) {
        switch error as? APIError {
        case .signInRequired:
            self = .signInRequired
        case .unavailable(let reason), .ipBlocked(let reason):
            self = .unavailable(reason)
        default:
            self = .noStream
        }
    }

    var errorDescription: String? {
        switch self {
        case .signInRequired: String(localized: "videoRequiresSignIn")
        case .unavailable(let reason): reason
        case .noStream: String(localized: "videoNoStream")
        }
    }
}
