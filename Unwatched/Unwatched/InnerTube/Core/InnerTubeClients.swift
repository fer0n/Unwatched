import Foundation

// MARK: - InnerTubeClients
//
// Single source of truth for YouTube InnerTube client identifiers and versions.
// Used by InnerTubeAPI (request bodies + headers) and AuthService (TV context body).

enum InnerTubeClients {

    enum Web {
        static let name      = "WEB"
        static let nameID    = "1"
        static let version   = "2.20260206.01.00"
        /// Browser UA used by the YouTube web client.
        static let userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }

    enum iOS {
        static let name      = "iOS"
        static let nameID    = "5"
        static let version   = "21.02.3"
        /// Returns the running iOS version formatted as "MAJOR_MINOR_PATCH" (or "MAJOR_MINOR"
        /// when the patch is 0). Dynamically derived from ProcessInfo so the User-Agent always
        /// reflects the actual device OS — prevents YouTube from rejecting requests sent from
        /// devices running iOS versions newer than the hardcoded string.
        static var currentOSVersionString: String {
            let v = ProcessInfo.processInfo.operatingSystemVersion
            return v.patchVersion == 0
                ? "\(v.majorVersion)_\(v.minorVersion)"
                : "\(v.majorVersion)_\(v.minorVersion)_\(v.patchVersion)"
        }
        static var userAgent: String {
            "com.google.ios.youtube/\(version) (iPhone16,2; U; CPU iOS \(currentOSVersionString) like Mac OS X;)"
        }
    }

    /// Android client — used exclusively for downloads.
    /// CDN URLs signed by the Android client are reliably downloadable using just
    /// the Android UA; no session cookies or PO tokens required.
    /// Exact params from yt-dlp to avoid YouTube bot detection / HTTP 400.
    enum Android {
        static let name              = "ANDROID"
        static let nameID            = "3"
        static let version           = "21.02.35"
        static let androidSdkVersion = 30  // Android 11
        static let userAgent         = "com.google.android.youtube/\(version) (Linux; U; Android 11) gzip"
    }

    /// Android VR client (Oculus Quest identity) — used as an unauthenticated fallback
    /// for audio-only mode. Per yt-dlp research (May 2026), this client does not require
    /// a Proof-of-Origin (PO) token for adaptive streams. Monitor for future enforcement.
    /// Note: clientVersion must not exceed 1.65 — higher versions return SABR streams only.
    enum AndroidVR {
        static let name    = "ANDROID_VR"
        static let nameID  = "28"
        static let version = "1.65.10"
        // eureka-user build string matches yt-dlp's android_vr UA exactly (May 2026).
        static let userAgent = "com.google.android.apps.youtube.vr.oculus/\(version) (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip"
    }

    /// Web Embedded Player client — the current YouTube iframe embedded player.
    /// Replaces the deprecated TVHTML5_SIMPLY_EMBEDDED_PLAYER (nameID=85) which was
    /// removed from yt-dlp in 2026 after YouTube blocked it with "no longer supported".
    /// Requires `thirdParty.embedUrl` in the request body — yt-dlp's `_fix_embedded_ytcfg`
    /// injects this automatically; our `fetchPlayerInfoTVEmbedded` sets it explicitly.
    enum TVEmbedded {
        static let name    = "WEB_EMBEDDED_PLAYER"
        static let nameID  = "56"
        static let version = "1.20260115.01.00"
    }

    /// Mobile web client (YouTube m.youtube.com, iPad Safari).
    /// Per yt-dlp research, MWEB does NOT require a PO Token for HLS streams
    /// (`required=False, recommended=True`). Unlike WEB_EMBEDDED_PLAYER it has no
    /// embedding restriction, so it may return `hlsManifestUrl` for videos that
    /// TVEmbedded cannot serve (embedding disabled). Also returns "ultralow" HLS
    /// variants for data-saver contexts alongside standard 360p–1080p tiers.
    enum MWEB {
        static let name      = "MWEB"
        static let nameID    = "2"
        static let version   = "2.20260115.01.00"
        static let userAgent = "Mozilla/5.0 (iPad; CPU OS 16_7_10 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1,gzip(gfe)"
    }

    /// YouTube Studio (creator) web client. Per yt-dlp research, this client is exempt
    /// from Proof-of-Origin (rqh=1) CDN enforcement on adaptive streams, unlike the
    /// standard WEB (1), iOS (5), or Android (3) clients. Its adaptive stream URLs can
    /// be used in AVMutableComposition without a pot= token.
    enum WebCreator {
        static let name    = "WEB_CREATOR"
        static let nameID  = "62"
        static let version = "1.20240723.03.00"
    }

    /// WEB client with macOS Safari UA — mirrors yt-dlp's `web_safari` client config.
    /// YouTube returns `hlsManifestUrl` for this client even for non-embeddable videos,
    /// while returning only `serverAbrStreamingUrl` (SABR) for the Chrome-UA WEB client.
    /// HLS manifest CDN URLs (manifest.googlevideo.com) do not require a pot= token.
    enum WebSafari {
        static let name      = "WEB"
        static let nameID    = "1"
        static let version   = "2.20260114.08.00"
        static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.5 Safari/605.1.15,gzip(gfe)"
    }

    enum TV {
        static let name      = "TVHTML5"
        static let nameID    = "7"
        static let version   = "7.20260311.12.00"
        static let userAgent = "Mozilla/5.0 (ChromiumStylePlatform) Cobalt/Version"
    }

    static let maxVideoResults = 20
}
