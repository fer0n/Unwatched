//
//  TvStreamResolver.swift
//  UnwatchedTV
//

import AVFoundation
import UnwatchedShared

/// Resolves a video to something AVPlayer can play, using the shared InnerTube client.
///
/// **HD:** the VISIONOS client is the one client that still returns an HLS manifest for
/// video-on-demand without a browser session — H.264 up to 1080p, no proof-of-origin token, and the
/// CDN serves it far faster than realtime. Its master also lists VP9 variants, which
/// `TvHLSMasterLoader` filters out.
///
/// **360p fallback:** the app-flavoured clients. Their `preferredStreamURL` is HLS when there is
/// one (live), otherwise the muxed file, and YouTube only muxes 360p. The HD streams next to it are
/// video-only and audio-only, and their CDN URLs are throttled to roughly a third of realtime
/// without a proof-of-origin token, which needs YouTube's own JavaScript — so a web view, and tvOS
/// has none. The web clients answer "the page needs to be reloaded" or "video unavailable" for the
/// same reason.
enum TvStreamResolver {
    /// One instance for the app: it holds the session, the visitor data and a network-path monitor
    /// that resets it, all of which are worth keeping across videos.
    private static let api = InnerTubeAPI()

    /// The filtered VISIONOS HLS stream, or nil when that client has none for this video.
    static func hdItem(for youtubeId: String) async -> AVPlayerItem? {
        do {
            guard let master = try await api.fetchPlayerInfoVisionOS(videoId: youtubeId).hlsURL,
                  let asset = TvHLSMasterLoader.asset(for: master) else {
                Log.info("VisionOS client returned no HLS for \(youtubeId)")
                return nil
            }
            Log.info("VisionOS client resolved an HD stream for \(youtubeId)")
            return AVPlayerItem(asset: asset)
        } catch {
            Log.info("VisionOS client failed for \(youtubeId): \(error.localizedDescription)")
            return nil
        }
    }

    /// The 360p fallback: a muxed file, or HLS for live streams.
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
        case .signInRequired: String(localized: "videoRequiresSignIn")
        case .unavailable(let reason): reason
        case .noStream: String(localized: "videoNoStream")
        }
    }
}
