import Foundation
import os
import Network
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private let tubeLog = Logger(subsystem: appSubsystem, category: "InnerTube")

// MARK: - InnerTubeAPI
//
// Implements a subset of the unofficial YouTube InnerTube API used by
// the Android SmartTube client (MediaServiceCore). This layer replaces
// the Java-based youtubeapi module.
//
// References:
//   https://github.com/LuanRT/YouTube.js/blob/main/src/core/clients/Web.ts
//   https://github.com/TeamNewPipe/NewPipeExtractor

public actor InnerTubeAPI {

    // MARK: - Configuration

    let session: URLSession
    var visitorData: String?
    var authToken: String?
    /// SAPISID cookie value from YouTube.com web session (set via OAuthLogin/MergeSession).
    /// Used by postWebCreator to compute SAPISIDHASH for WEB_CREATOR requests on www.youtube.com.
    var sapisid: String?

    // MARK: - signatureTimestamp (STS) cache
    //
    // The TV authenticated player request requires `signatureTimestamp` inside
    // `playbackContext.contentPlaybackContext` to validate the current player JS
    // version. Without it, YouTube returns "The page needs to be reloaded" for
    // sign-in-required or age-restricted content even with a valid Bearer token.
    // The value is fetched lazily from YouTube's homepage and cached for 1 hour.
    var signatureTimestamp: Int?
    var signatureTimestampFetchedAt: Date?

    // MARK: - poToken storage (Step 1)
    //
    // Populated either by a PoTokenProvider (BotGuardClient) or by storeExternalPoToken()
    // (Option B: token extracted from a running WKWebView YouTube player session).
    // All injection points are gated on `poToken != nil` (zero behaviour change when nil).
    var poToken: String?
    var poTokenVideoId: String?
    var poTokenExpiry: Date?

    // MARK: - External PoToken API (Option B)

    /// Stores a PO token that was extracted from the YouTube player running inside a
    /// hidden WKWebView (see `YouTubeWebViewHLSExtractor.extractedPoToken`).
    /// The token is applied to all subsequent `fetchPlayerInfo` calls for `videoId`
    /// via `applyingPoToken`, allowing rqh=1 adaptive streams to be retried with CDN auth.
    public func storeExternalPoToken(_ token: String, for videoId: String) {
        poToken = token
        poTokenVideoId = videoId
    }

    /// Returns the current visitor data identifier (from the most recent InnerTube response).
    /// Used by BotGuardWebViewRunner to mint a PoToken for the correct session identifier.
    public func currentVisitorData() -> String? { visitorData }

    /// Returns the cached PO token for `videoId`, or nil if none is available.
    /// Phase -1a uses this to recover the BotGuard-minted token when
    /// `VideoPreloadCache.wkHLSPoTokenCache` is empty (e.g. for videos that have no
    /// `serviceIntegrityDimensions.poToken` in their player API response — the WKWebView
    /// extractor stores nil in the cache, but BotGuard may have minted a token separately
    /// during the 2 s prefetchPoToken window in loadAsync).
    public func currentPoToken(for videoId: String) -> String? {
        guard poTokenVideoId == videoId else { return nil }
        return poToken
    }

    /// Returns true when a PO token is cached for the given video ID.
    /// Used by `tryAllStreams` to decide whether to attempt rqh=1 adaptive composition.
    public func hasPoToken(for videoId: String) -> Bool {
        return poToken != nil && poTokenVideoId == videoId
    }

    /// Fetches a PO token from the configured provider in the background and caches it
    /// in `poToken`/`poTokenVideoId`. Call this fire-and-forget when starting a video load
    /// so the token is available for subsequent retry attempts without blocking the
    /// primary fetch path. BotGuardClient caches within its TTL (~1h), so this is fast
    /// after the first successful pipeline run.
    public func prefetchPoToken(for videoId: String) async {
        guard let provider = poTokenProvider, poToken == nil || poTokenVideoId != videoId else { return }
        if let pot = try? await provider.token(for: videoId) {
            poToken = pot
            poTokenVideoId = videoId
            tubeLog.notice("[InnerTube] prefetchPoToken ✅ (len=\(pot.count)) for \(videoId, privacy: .public)")
        }
    }

    // MARK: - PoTokenProvider
    let poTokenProvider: (any PoTokenProvider)?

    // MARK: - Network path monitoring
    //
    // Resets `visitorData` when the network path changes (VPN connect/disconnect,
    // WiFi switch, cellular handover). A fresh visitorData is issued on the next
    // browse request and is tied to the new IP context, avoiding UNPLAYABLE responses
    // caused by session/IP mismatch after a network transition.
    nonisolated private let pathMonitor = NWPathMonitor()
    private var lastPathStatus: NWPath.Status? = nil

    /// The web client context used to fetch home/search/channel feeds.
    let webClientContext: [String: Any] = [
        "client": [
            "hl": "en",
            "gl": "US",
            "clientName": InnerTubeClients.Web.name,
            "clientVersion": InnerTubeClients.Web.version,
        ]
    ]

    /// The iOS client context used for stream URL retrieval.
    /// Returns c=iOS URLs and an HLS manifest, both playable natively by AVPlayer.
    /// `osVersion` is derived at runtime from ProcessInfo so requests reflect the
    /// actual device OS and are not rejected by YouTube's version validation.
    var iosClientContext: [String: Any] {
        let osVer = InnerTubeClients.iOS.currentOSVersionString.replacingOccurrences(of: "_", with: ".")
        return [
            "client": [
                "hl": "en",
                "gl": "US",
                "clientName": InnerTubeClients.iOS.name,
                "clientVersion": InnerTubeClients.iOS.version,
                "deviceMake": "Apple",
                "deviceModel": "iPhone16,2",
                "osName": "iPhone",
                "osVersion": osVer,
                "clientScreen": "WATCH",
            ]
        ]
    }
    let iosUserAgent = InnerTubeClients.iOS.userAgent

    /// The Android client context used for download URL retrieval.
    /// Exact params match yt-dlp's android client to avoid HTTP 400.
    let androidClientContext: [String: Any] = [
        "client": [
            "hl": "en",
            "gl": "US",
            "clientName": InnerTubeClients.Android.name,
            "clientVersion": InnerTubeClients.Android.version,
            "androidSdkVersion": InnerTubeClients.Android.androidSdkVersion,
            "osName": "Android",
            "osVersion": "11",
        ]
    ]

    /// The TVHTML5 client context required for all authenticated InnerTube requests
    /// (subscriptions, history, playlists, personalised home).
    /// The OAuth token issued by the TV device-code flow is bound to this client.
    /// The WEB client on www.youtube.com rejects Bearer tokens and returns 400.
    let tvClientContext: [String: Any] = [
        "client": [
            "hl": "en",
            "gl": "US",
            "clientName": InnerTubeClients.TV.name,
            "clientVersion": InnerTubeClients.TV.version,
        ]
    ]

    /// The Android VR (Oculus Quest) client context used for audio-only fallback.
    /// Per yt-dlp research (May 2026), this client does not require a PO token for
    /// adaptive audio streams. Used exclusively by `fetchPlayerInfoAndroidVR`.
    ///
    /// IMPORTANT: must match yt-dlp's `android_vr` INNERTUBE_CONTEXT exactly:
    ///  - `userAgent` belongs INSIDE the client body (not just as a request header)
    ///  - NO hl, gl, utcOffsetMinutes, userInterfaceTheme — yt-dlp omits all of these
    ///  - Using clientVersion > 1.65 returns SABR-only streams (yt-dlp comment)
    let androidVRClientContext: [String: Any] = [
        "client": [
            "clientName": InnerTubeClients.AndroidVR.name,
            "clientVersion": InnerTubeClients.AndroidVR.version,
            "deviceMake": "Oculus",
            "deviceModel": "Quest 3",
            "androidSdkVersion": 32,
            "userAgent": InnerTubeClients.AndroidVR.userAgent,
            "osName": "Android",
            "osVersion": "12L",
        ]
    ]

    /// The WEB_EMBEDDED_PLAYER client context for embedded iframe player requests.
    /// Replaces the deprecated TVHTML5_SIMPLY_EMBEDDED_PLAYER (nameID=85). YouTube blocked
    /// nameID=85 in 2026; yt-dlp removed `tv_embedded` and now uses `web_embedded` (nameID=56).
    /// IMPORTANT: requests must include `thirdParty.embedUrl` — without it YouTube returns
    /// "no longer supported in this application or device" (the same error nameID=85 gave).
    let tvEmbeddedClientContext: [String: Any] = [
        "client": [
            "hl": "en",
            "gl": "US",
            "clientName": InnerTubeClients.TVEmbedded.name,
            "clientVersion": InnerTubeClients.TVEmbedded.version,
            "clientScreen": "EMBED",
        ]
    ]

    /// The WEB_CREATOR (YouTube Studio) client context used as a fallback player source.
    /// Per yt-dlp documentation, this client is exempt from rqh=1 CDN enforcement on
    /// adaptive streams — URLs returned by WEB_CREATOR do not require a pot= token.
    let webCreatorClientContext: [String: Any] = [
        "client": [
            "hl": "en",
            "gl": "US",
            "clientName": InnerTubeClients.WebCreator.name,
            "clientVersion": InnerTubeClients.WebCreator.version,
            "clientScreen": "WATCH",
        ]
    ]

    /// MWEB (m.youtube.com / iPad Safari) client context.
    /// Per yt-dlp, MWEB does not require a PO Token for HLS — returns `hlsManifestUrl`
    /// for a wider range of videos than the embed-restricted WEB_EMBEDDED_PLAYER client.
    let mwebClientContext: [String: Any] = [
        "client": [
            "hl": "en",
            "gl": "US",
            "clientName": InnerTubeClients.MWEB.name,
            "clientVersion": InnerTubeClients.MWEB.version,
            "clientScreen": "WATCH",
        ]
    ]

    /// WEB client with macOS Safari UA — mirrors yt-dlp's `web_safari` client (nameID=1).
    /// Unlike the Chrome-UA WEB client, this configuration returns `hlsManifestUrl` for
    /// non-embeddable videos (per yt-dlp empirical testing, May 2026). Includes
    /// `timeZone` and `utcOffsetMinutes` to match yt-dlp's _extract_context output exactly.
    let webSafariClientContext: [String: Any] = [
        "client": [
            "hl": "en",
            "timeZone": "UTC",
            "utcOffsetMinutes": 0,
            "clientName": InnerTubeClients.WebSafari.name,
            "clientVersion": InnerTubeClients.WebSafari.version,
            "userAgent": InnerTubeClients.WebSafari.userAgent,
        ]
    ]

    let baseURL = URL(string: "https://www.youtube.com/youtubei/v1")!
    let playerBaseURL = URL(string: "https://youtubei.googleapis.com/youtubei/v1")!
    // Public InnerTube API key embedded in YouTube's own web client JS — not a developer secret.
    // nosec: false positive — this key is published by Google in youtube.com/s/player JS.
    // Used only for unauthenticated requests (aligned to Android RetrofitOkHttpHelper pattern).
    let apiKey = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8" // gitleaks:allow
    // Note: TV key (AIzaSyDCU8...) is defined in Android as API_KEY_OLD and never used.

    /// Request timeout for all InnerTube API calls (NW-4-FIX).
    /// Set to 30 s to fail fast on slow/throttled youtubei.googleapis.com requests.
    /// Firebase issue 709b3e91 showed a 2m48s hang when this was left at the OS default.
    static let requestTimeoutInterval: TimeInterval = 30

    public init(authToken: String? = nil, poTokenProvider: (any PoTokenProvider)? = nil) {
        let config = URLSessionConfiguration.default
        // NW-4-FIX: 30 s request timeout. Slow/throttled youtubei.googleapis.com requests
        // previously hung for over 2 minutes (Firebase issue 709b3e91) because the OS default
        // (60 s) was too permissive. 30 s is a good balance between fast failure on truly
        // stuck requests and tolerance for temporarily slow cellular connections.
        config.timeoutIntervalForRequest = Self.requestTimeoutInterval
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
        self.authToken = authToken
        self.poTokenProvider = poTokenProvider
        // Start observing network path changes so visitorData is cleared on network transitions.
        // Callbacks arrive on pathMonitor's private queue; actor re-entry via Task is safe.
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { await self?.handlePathUpdate(path) }
        }
        pathMonitor.start(queue: .global(qos: .background))
    }

    /// Package-internal initializer for testing only.
    /// Accepts a custom `URLSession` so tests can inject a mock via `URLProtocol`.
    init(authToken: String?, session: URLSession) {
        self.session = session
        self.authToken = authToken
        self.poTokenProvider = nil
    }

    // MARK: - Private: Network path handler

    private func handlePathUpdate(_ path: NWPath) {
        // Only reset visitorData when transitioning between satisfied states
        // (e.g. VPN connect, WiFi switch). Ignore transient unsatisfied -> satisfied
        // on first start by comparing to the previously recorded status.
        let prev = lastPathStatus
        lastPathStatus = path.status
        guard path.status == .satisfied, prev == .satisfied else { return }
        visitorData = nil
        tubeLog.notice("visitorData cleared — network path changed (VPN/WiFi transition)")
    }

    // MARK: - Auth

    public func setAuthToken(_ token: String?) {
        let msg = token != nil ? "token(\(token!.prefix(8))…)" : "nil"
        tubeLog.notice("setAuthToken: \(msg, privacy: .public)")
        self.authToken = token
    }

    /// Sets the YouTube.com SAPISID cookie value extracted via the OAuthLogin/MergeSession
    /// flow. Used by postWebCreator to compute the SAPISIDHASH Authorization header.
    public func setSAPISID(_ value: String?) {
        let msg = value != nil ? "present" : "nil"
        tubeLog.notice("setSAPISID: \(msg, privacy: .public)")
        self.sapisid = value
    }

    /// Returns whether the SAPISID cookie is currently set.
    /// Used by callers in other modules to avoid redundant recovery attempts.
    public var hasSAPISID: Bool { sapisid != nil }

    // MARK: - Visitor data

    /// Clears the stored per-device `visitorData` token.
    /// Called when the user disables "Per-Device Recommendations" in Settings so
    /// the next home-feed request uses YouTube's default shared recommendation algorithm.
    public func resetVisitorData() {
        visitorData = nil
        tubeLog.notice("visitorData cleared (per-device recommendations disabled)")
    }
}
