import Foundation
import NaturalLanguage
import os
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Player endpoints and playback tracking

extension InnerTubeAPI {

    // MARK: - Player stream URLs

    public func fetchPlayerInfo(videoId: String) async throws -> PlayerInfo {
        // Include serviceIntegrityDimensions.poToken in the request body when a token
        // is stored — this tells YouTube's backend the request is pot-authenticated so
        // the returned stream URLs can be accessed by the CDN with &pot= validation.
        let hasPot = poToken != nil && poTokenVideoId == videoId
        var body = makeBody(client: iosClientContext, includePoToken: hasPot)
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        let data = try await postPlayer(body: body)
        var info = try parsePlayerInfo(from: data, videoId: videoId)
        // Apply a WKWebView-extracted pot= token (Option B) when available.
        // The token is stored by storeExternalPoToken() after the hidden WKWebView
        // extracts it from the YouTube player's /player API request body.
        if hasPot, let pot = poToken {
            Log.innerTube.notice("[InnerTube] ✅ poToken applied to \(videoId) via iOS client (len=\(pot.count))")
            info = info.applyingPoToken(pot)
        }
        return info
    }

    /// Fetches player info using the Web client, which returns muxed (video+audio)
    /// MP4 streams suitable for direct file download and saving to Photos.
    /// The iOS client only returns adaptive-only streams; the Web client includes
    /// itag 18 (360p muxed) and itag 22 (720p muxed) in the `formats` array.
    public func fetchPlayerInfoForDownload(videoId: String) async throws -> PlayerInfo {
        var body = makeBody(client: webClientContext)
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        let data = try await post(endpoint: "player", body: body)
        return try parsePlayerInfo(from: data, videoId: videoId)
    }

    /// Fetches player info using the Android client.
    /// Used as the primary download fallback: Android CDN URLs are signed with
    /// `c=ANDROID` and are reliably downloadable with a standard Android UA.
    /// Unlike TVHTML5-signed URLs, these do not require session cookies.
    public func fetchPlayerInfoAndroid(videoId: String) async throws -> PlayerInfo {
        var body = makeBody(client: androidClientContext)
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        let data = try await postAndroid(endpoint: "player", body: body)
        return try parsePlayerInfo(from: data, videoId: videoId)
    }

    /// Fetches player info using the Android VR (Oculus) client.
    /// Uses the correct Android VR transport (nameID=28, Oculus UA on googleapis.com)
    /// so YouTube identifies the request as an Oculus Quest client — not a Web client.
    /// Per yt-dlp (May 2026): android_vr returns `hlsManifestUrl` (no rqh=1 required)
    /// when the request includes `html5Preference: HTML5_PREF_WANTS` — yt-dlp injects
    /// this via `_generate_player_context` for ALL clients. Without it, YouTube returns
    /// `serverAbrStreamingUrl` (SABR only, not AVPlayer-compatible).
    public func fetchPlayerInfoAndroidVR(videoId: String) async throws -> PlayerInfo {
        // Mirror yt-dlp's _generate_player_context: send html5Preference for all clients.
        // Also inject visitorData so YouTube session resolution works (matches yt-dlp's
        // X-Goog-Visitor-Id header → client visitorData field).
        var clientFields = (androidVRClientContext["client"] as? [String: Any]) ?? [:]
        if let vd = visitorData { clientFields["visitorData"] = vd }

        // android_vr has REQUIRE_JS_PLAYER=False → sts may be nil; that is fine.
        // yt-dlp still passes sts when available, so we do the same.
        let sts = await fetchSignatureTimestampIfNeeded()
        var cpbc: [String: Any] = ["html5Preference": "HTML5_PREF_WANTS"]
        if let sts { cpbc["signatureTimestamp"] = sts }

        var body = makeBody(client: ["client": clientFields])
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        body["playbackContext"] = ["contentPlaybackContext": cpbc]
        let data = try await postAndroidVR(body: body)
        return try parsePlayerInfo(from: data, videoId: videoId)
    }

    /// Fetches player info using the WebSafari client with `serviceIntegrityDimensions.poToken`
    /// and the WKWebView's WEB session `visitorData` in the client context.
    ///
    /// Uses `postWebSafari` (not the generic `post()`) because the WebSafari POST method
    /// sends a proper Safari browser User-Agent and `X-Goog-Visitor-Id` header — without
    /// these, YouTube returns `playabilityStatus: "ERROR"` ("Video unavailable") with no
    /// `streamingData` for all videos, regardless of content type.
    ///
    /// This mirrors yt-dlp's `web_safari` client approach for BotGuard token delivery:
    /// pot= token in `serviceIntegrityDimensions`, visitorData in `context.client`,
    /// html5Preference + signatureTimestamp in `playbackContext`.
    ///
    /// Returns a `PlayerInfo` with `&pot=<token>` appended to all format URLs.
    public func fetchPlayerInfoWebWithPoToken(videoId: String, visitorData webVD: String?) async throws -> PlayerInfo {
        let hasPot = poToken != nil && poTokenVideoId == videoId

        // Inject the WKWebView's WEB session visitorData into context.client so
        // YouTube can validate the minted pot= token against the correct session.
        // Fall back to the API's own visitorData when webVD is not available.
        var clientFields = (webSafariClientContext["client"] as? [String: Any]) ?? [:]
        let apiVD = visitorData ?? ""
        Log.innerTube.notice("[InnerTube] fetchPlayerInfoWebWithPoToken: apiVD.len=\(apiVD.count) webVD.len=\(webVD?.count ?? 0) match=\(apiVD == (webVD ?? ""))")
        if let vd = webVD, !vd.isEmpty {
            clientFields["visitorData"] = vd
        } else if let vd = visitorData {
            clientFields["visitorData"] = vd
        }

        let sts = await fetchSignatureTimestampIfNeeded()
        var cpbc: [String: Any] = ["html5Preference": "HTML5_PREF_WANTS"]
        if let sts { cpbc["signatureTimestamp"] = sts }

        var body = makeBody(client: ["client": clientFields], includePoToken: hasPot)
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        body["playbackContext"] = ["contentPlaybackContext": cpbc]

        // Pass webVD as X-Goog-Visitor-Id override: ensures the visitor ID in the header
        // matches context.client.visitorData in the body and the minted pot= token identifier.
        // Without this, postWebSafari sends api.visitorData (iOS session) in the header
        // while the body has webVD (WEB session) — YouTube would tie CDN URLs to the iOS
        // session but our token is minted for the WEB session → CDN validation fails (403).
        let data = try await postWebSafari(body: body, visitorIdOverride: webVD)
        var info = try parsePlayerInfo(from: data, videoId: videoId)
        if hasPot, let pot = poToken {
            Log.innerTube.notice("[InnerTube] ✅ poToken applied to \(videoId) via WebSafari+pot client (len=\(pot.count))")
            info = info.applyingPoToken(pot)
        }
        return info
    }

    /// Fetches player data using current yt-dlp's primary JS-less visionOS client.
    public func fetchPlayerInfoVisionOS(videoId: String) async throws -> PlayerInfo {
        await seedVisionOSSession(videoId: videoId)
        var clientFields = (visionOSClientContext["client"] as? [String: Any]) ?? [:]
        if let vd = visitorData { clientFields["visitorData"] = vd }
        var body = makeBody(client: ["client": clientFields])
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        body["playbackContext"] = [
            "contentPlaybackContext": ["html5Preference": "HTML5_PREF_WANTS"]
        ]
        let data = try await postVisionOS(body: body)
        return try parsePlayerInfo(from: data, videoId: videoId)
    }

    /// Fetches player info using the WEB_EMBEDDED_PLAYER client (nameID=56).
    /// Replaced the deprecated TVHTML5_SIMPLY_EMBEDDED_PLAYER (nameID=85) which YouTube
    /// blocked in 2026 with "no longer supported in this application or device".
    /// Returns an HLS manifest for most embeddable videos without requiring a PO token.
    /// `thirdParty.embedUrl` is required — without it YouTube returns the same rejection.
    public func fetchPlayerInfoTVEmbedded(videoId: String) async throws -> PlayerInfo {
        var body = makeBody(client: tvEmbeddedClientContext)
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        // thirdParty.embedUrl: required by WEB_EMBEDDED_PLAYER to prove legitimate embed.
        // yt-dlp's _fix_embedded_ytcfg() injects this for any *_embedded client variant.
        // Without it, YouTube returns "no longer supported in this application or device".
        // Current yt-dlp intentionally uses a non-YouTube origin here; a youtube.com
        // URL is not treated as a third-party embed and now returns UNPLAYABLE.
        body["thirdParty"] = [
            "embedUrl": "https://www.reddit.com/"
        ]
        var comps = URLComponents(string: "https://www.youtube.com/watch")!
        comps.queryItems = [URLQueryItem(name: "v", value: videoId)]
        let referer = comps.url?.absoluteString ?? "https://www.youtube.com"
        body["playbackContext"] = [
            "contentPlaybackContext": [
                "referer": referer,
                "html5Preference": "HTML5_PREF_WANTS",
            ]
        ]
        let data = try await postTVEmbedded(body: body)
        return try parsePlayerInfo(from: data, videoId: videoId)
    }

    /// Fetches player info using the WEB_CREATOR (YouTube Studio) client.
    /// Per yt-dlp documentation, this client is exempt from rqh=1 CDN enforcement on
    /// adaptive streams — the returned video/audio URLs do NOT require a pot= token.
    /// Requires a signed-in session (Bearer auth injected by postWebCreator). Without
    /// auth, YouTube returns signInRequired and omits streamingData entirely.
    public func fetchPlayerInfoWebCreator(videoId: String) async throws -> PlayerInfo {
        // Inject visitorData so YouTube's session resolution works correctly.
        var clientFields = (webCreatorClientContext["client"] as? [String: Any]) ?? [:]
        if let vd = visitorData { clientFields["visitorData"] = vd }

        // html5Preference + signatureTimestamp: same as fetchPlayerInfoAuthenticated.
        // Without STS, YouTube may return "The page needs to be reloaded".
        let sts = await fetchSignatureTimestampIfNeeded()
        var cpbc: [String: Any] = ["html5Preference": "HTML5_PREF_WANTS"]
        if let sts { cpbc["signatureTimestamp"] = sts }

        var body = makeBody(client: ["client": clientFields])
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        body["playbackContext"] = ["contentPlaybackContext": cpbc]
        let data = try await postWebCreator(body: body)
        return try parsePlayerInfo(from: data, videoId: videoId)
    }

    /// Fetches player info using the WEB client with macOS Safari UA (yt-dlp `web_safari`).
    /// Per yt-dlp empirical testing (May 2026), this client returns `hlsManifestUrl` for
    /// non-embeddable videos where all other clients return only `serverAbrStreamingUrl`.
    /// The Safari UA is the key differentiator — nameID=1 with Chrome UA does not return
    /// HLS manifest. HLS segments from manifest.googlevideo.com do not require pot= tokens.
    public func fetchPlayerInfoWebSafari(videoId: String) async throws -> PlayerInfo {
        let sts = await fetchSignatureTimestampIfNeeded()
        var cpbc: [String: Any] = ["html5Preference": "HTML5_PREF_WANTS"]
        if let sts { cpbc["signatureTimestamp"] = sts }

        var body = makeBody(client: webSafariClientContext)
        body["videoId"] = videoId
        body["playbackContext"] = ["contentPlaybackContext": cpbc]
        let data = try await postWebSafari(body: body)
        return try parsePlayerInfo(from: data, videoId: videoId)
    }

    /// Fetches player info using the MWEB (m.youtube.com, iPad Safari) client.    /// Per yt-dlp, MWEB does not require a PO Token for HLS (`required=False`) and has
    /// no embedding restriction — it may return `hlsManifestUrl` for videos that
    /// WEB_EMBEDDED_PLAYER cannot serve (e.g. embedding-disabled content).
    /// Mirrors the TVAuth request pattern: injects html5Preference + signatureTimestamp +
    /// visitorData + Bearer auth so YouTube returns `streamingData` rather than
    /// "The page needs to be reloaded" (the same fix that unlocked the TV auth client).
    public func fetchPlayerInfoMWEB(videoId: String) async throws -> PlayerInfo {
        var clientFields = (mwebClientContext["client"] as? [String: Any]) ?? [:]
        if let vd = visitorData { clientFields["visitorData"] = vd }

        let sts = await fetchSignatureTimestampIfNeeded()
        var cpbc: [String: Any] = ["html5Preference": "HTML5_PREF_WANTS"]
        if let sts { cpbc["signatureTimestamp"] = sts }

        var body = makeBody(client: ["client": clientFields])
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        body["playbackContext"] = ["contentPlaybackContext": cpbc]

        let data = try await postMWEB(body: body)
        return try parsePlayerInfo(from: data, videoId: videoId)
    }

    /// Fetches player info using the authenticated WEB client (nameID=1, www.youtube.com).
    /// Mirrors yt-dlp's `web` OAuth client: `Bearer {token}` + `X-Goog-AuthUser: 0`.
    /// For authenticated users, adaptive stream URLs from the WEB client do not carry
    /// `rqh=1` CDN enforcement, making this the primary authenticated adaptive path.
    /// Throws `APIError.notAuthenticated` when no auth token is present.
    public func fetchPlayerInfoWebAuthenticated(videoId: String) async throws -> PlayerInfo {
        let sts = await fetchSignatureTimestampIfNeeded()
        var cpbc: [String: Any] = ["html5Preference": "HTML5_PREF_WANTS"]
        if let sts { cpbc["signatureTimestamp"] = sts }
        var clientFields = (webClientContext["client"] as? [String: Any]) ?? [:]
        if let vd = visitorData { clientFields["visitorData"] = vd }
        var body = makeBody(client: ["client": clientFields])
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        body["playbackContext"] = ["contentPlaybackContext": cpbc]
        let data = try await postWebAuthenticated(body: body)
        return try parsePlayerInfo(from: data, videoId: videoId)
    }

    /// Fetches player info using the authenticated iOS client.
    /// Adding a Bearer auth token may cause YouTube to return an HLS manifest and adaptive
    /// streams without `rqh=1` for embed-disabled or account-restricted content.
    /// Falls back to `fetchPlayerInfo` (unauthenticated) when no auth token is stored.
    public func fetchPlayerInfoiOSAuthenticated(videoId: String) async throws -> PlayerInfo {
        var body = makeBody(client: iosClientContext, includePoToken: true)
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        let data = try await postPlayerAuthenticated(body: body)
        var info = try parsePlayerInfo(from: data, videoId: videoId)
        if let pot = poToken, poTokenVideoId == videoId {
            Log.innerTube.notice("[InnerTube] ✅ poToken applied to \(videoId) via iOS-auth client (len=\(pot.count))")
            info = info.applyingPoToken(pot)
        }
        return info
    }

    /// Resolves watch-history tracking data through the authenticated player clients.
    /// Device-code accounts reject the authenticated iOS client with HTTP 400, while
    /// the TV or WEB client may still return playbackTracking for the same account.
    public func fetchHistoryTrackingURLs(videoId: String) async -> PlaybackTrackingURLs? {
        let clients: [(String, () async throws -> PlayerInfo)] = [
            ("tv-auth", { try await self.fetchPlayerInfoAuthenticated(videoId: videoId) }),
            ("web-auth", { try await self.fetchPlayerInfoWebAuthenticated(videoId: videoId) }),
            ("ios-auth", { try await self.fetchPlayerInfoiOSAuthenticated(videoId: videoId) }),
        ]
        for (client, fetch) in clients {
            do {
                let info = try await fetch()
                if let urls = info.trackingURLs,
                    Self.trackingSession(from: urls) != nil
                {
                    return urls
                }
            } catch {
            }
        }
        return nil
    }

    public func fetchPlayerInfoAuthenticated(videoId: String) async throws -> PlayerInfo {
        // Build a TV client context that includes visitorData when available.
        // YouTube's TV auth endpoint needs visitorData inside context.client to correctly
        // identify the session; without it, sign-in-required or region-gated videos return
        // UNPLAYABLE even when the Bearer token is valid.
        var clientFields = (tvClientContext["client"] as? [String: Any]) ?? [:]
        let hadVisitorData = visitorData != nil
        if let vd = visitorData { clientFields["visitorData"] = vd }

        // signatureTimestamp (STS) validates the player JS version on YouTube's backend.
        // Without it, TV auth player requests return "The page needs to be reloaded" for
        // sign-in-required or age-restricted content even with a valid Bearer token.
        let sts = await fetchSignatureTimestampIfNeeded()
        var cpbc: [String: Any] = ["html5Preference": "HTML5_PREF_WANTS"]
        if let sts { cpbc["signatureTimestamp"] = sts }

        let attToken = await fetchAttestationToken(videoId: videoId)

        func buildBody(fields: [String: Any]) -> [String: Any] {
            var body = makeBody(client: ["client": fields])
            body["videoId"] = videoId
            body["racyCheckOk"] = true
            body["contentCheckOk"] = true
            body["playbackContext"] = ["contentPlaybackContext": cpbc]
            if let token = attToken {
                body["serviceIntegrityDimensions"] = ["poToken": token]
            }
            return body
        }

        let firstData = try await postTV(endpoint: "player", body: buildBody(fields: clientFields))

        // D-16 SABR probe: test if serverAbrStreamingUrl accepts a simple GET with Bearer.
        // This is the endpoint the official YouTube TV app uses for all playback.
        // If Bearer auth satisfies it and it returns video data or a redirect to a CDN URL
        // without rqh=1, it could provide a playback path we can use via AVURLAsset or
        // AVAssetResourceLoader without BotGuard/pot= tokens.
        if let sabrStr = (firstData["streamingData"] as? [String: Any])?["serverAbrStreamingUrl"] as? String,
           let sabrURL = URL(string: sabrStr),
           let bearerToken = authToken {
            Log.innerTube.notice("D-16 SABR URL (first 200): \(sabrStr.prefix(200))")
            let capturedToken = bearerToken
            Task.detached {
                var req = URLRequest(url: sabrURL)
                req.setValue("Bearer \(capturedToken)", forHTTPHeaderField: "Authorization")
                req.setValue(InnerTubeClients.TV.userAgent, forHTTPHeaderField: "User-Agent")
                req.timeoutInterval = 8
                if let (data, resp) = try? await URLSession(configuration: .ephemeral).data(for: req),
                   let http = resp as? HTTPURLResponse {
                    let ct = http.value(forHTTPHeaderField: "Content-Type") ?? "?"
                    let preview = String(data: data.prefix(300), encoding: .utf8) ?? "(binary \(data.count) bytes)"
                    Log.innerTube.notice("D-16 SABR GET Bearer: HTTP \(http.statusCode) ct=\(ct) body_preview=\(preview.prefix(200))")
                } else {
                    Log.innerTube.notice("D-16 SABR GET Bearer: fail/timeout")
                }
            }
        }

        // TV auth responses always contain responseContext.visitorData, even when unplayable.
        // On the very first call visitorData is nil, which causes YouTube to return no
        // streamingData. Extract and cache it here, then immediately retry so the quality
        // switch succeeds without waiting 60+ s for background browse calls to populate it.
        if !hadVisitorData,
           let rc = firstData["responseContext"] as? [String: Any],
           let newVD = rc["visitorData"] as? String, !newVD.isEmpty {
            Log.innerTube.notice("TVAuth: seeded visitorData from player response — retrying")
            visitorData = newVD
            var retryFields = (tvClientContext["client"] as? [String: Any]) ?? [:]
            retryFields["visitorData"] = newVD
            let retryData = try await postTV(endpoint: "player", body: buildBody(fields: retryFields))
            return try parsePlayerInfo(from: retryData, videoId: videoId)
        }

        return try parsePlayerInfo(from: firstData, videoId: videoId)
    }

    /// Fetches end-screen cards for a video using the Web client.
    /// The iOS player client typically omits `endscreen` data; the Web client reliably includes it.
    /// Returns an empty array if no end cards are available or the request fails.
    public func fetchEndCards(videoId: String) async throws -> [EndCard] {
        var body = makeBody(client: webClientContext)
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        let data = try await post(endpoint: "player", body: body)
        let cards = parseEndCards(from: data)
        Log.innerTube.notice("fetchEndCards id=\(videoId) → \(cards.count) cards")
        return cards
    }

    // MARK: - Playback Tracking (Watch History)

    /// Generates a Client Playback Nonce (CPN) — a random 16-character base64url string.
    /// YouTube uses this to attribute a view to an account and record it in watch history.
    /// Must be generated once per playback session and used in every tracking ping.
    public static func generateCPN() -> String {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        let chars = Array(alphabet)
        return String((0..<16).map { _ in chars[Int.random(in: 0..<chars.count)] })
    }

    /// Fires `videostatsPlaybackUrl` to record the video start in the user's YouTube watch history.
    /// Must be called once when AVPlayerItem becomes `readyToPlay`.
    /// Mirrors Android's `TrackingApi.createWatchRecord` in MediaServiceCore.
    /// - Parameters:
    ///   - videoId: The YouTube video ID being watched.
    ///   - cpn: The Client Playback Nonce for this session (see `generateCPN()`).
    ///   - trackingURLs: Tracking URLs from the player response; the `ei`/`vm`/`of` session
    ///     params are extracted from them. Without those params the ping cannot be credited.
    ///   - lengthSeconds: Total video duration in seconds (`len`).
    ///   - startPosition: Playhead position (seconds) the watch record starts at (`cmt`).
    ///   - final: Marks the video as fully watched (`final=1`).
    public func reportPlaybackStarted(
        videoId: String,
        cpn: String,
        trackingURLs: PlaybackTrackingURLs?,
        lengthSeconds: TimeInterval,
        startPosition: TimeInterval,
        final: Bool = false
    ) async {
        guard let session = Self.trackingSession(from: trackingURLs) else {
            Log.innerTube.notice(
                "reportPlaybackStarted skipped — no ei/vm/of for \(videoId) (ping would not be credited)"
            )
            return
        }
        var params: [String: String] = [
            "docid": videoId,
            "len": Self.formatSeconds(lengthSeconds),
            "cmt": Self.formatSeconds(startPosition),
            "cpn": cpn,
        ]
        if final { params["final"] = "1" }
        await pingStatsEndpoint("playback", session: session, params: params)
        Log.innerTube.notice(
            "reportPlaybackStarted: videoId=\(videoId) cpn=\(cpn.prefix(4))… cmt=\(Int(startPosition))s final=\(final)"
        )
    }

    /// Fires `videostatsWatchtimeUrl` to record a watched interval in the user's YouTube watch history.
    /// Must be preceded by `reportPlaybackStarted` — YouTube ignores standalone watchtime pings.
    /// Mirrors Android's `TrackingApi.updateWatchTime` in MediaServiceCore.
    /// - Parameters:
    ///   - videoId: The YouTube video ID being watched.
    ///   - cpn: The same Client Playback Nonce used in `reportPlaybackStarted`.
    ///   - trackingURLs: Tracking URLs from the player response (source of `ei`/`vm`/`of`).
    ///   - lengthSeconds: Total video duration in seconds (`len`).
    ///   - segmentStart: Playhead position (seconds) when the current play segment began (`st`).
    ///   - segmentEnd: Playhead position (seconds) when the current play segment ended (`et`/`cmt`).
    ///   - final: Marks the video as fully watched (`final=1`).
    public func reportWatchtime(
        videoId: String,
        cpn: String,
        trackingURLs: PlaybackTrackingURLs?,
        lengthSeconds: TimeInterval,
        segmentStart: TimeInterval,
        segmentEnd: TimeInterval,
        final: Bool = false
    ) async {
        guard let session = Self.trackingSession(from: trackingURLs) else {
            Log.innerTube.notice(
                "reportWatchtime skipped — no ei/vm/of for \(videoId) (ping would not be credited)")
            return
        }
        var params: [String: String] = [
            "docid": videoId,
            "len": Self.formatSeconds(lengthSeconds),
            "st": Self.formatSeconds(segmentStart),
            "et": Self.formatSeconds(segmentEnd),
            "cmt": Self.formatSeconds(segmentEnd),
            "cpn": cpn,
        ]
        if final { params["final"] = "1" }
        await pingStatsEndpoint("watchtime", session: session, params: params)
        Log.innerTube.notice(
            "reportWatchtime: videoId=\(videoId) st=\(Int(segmentStart))s et=\(Int(segmentEnd))s final=\(final)"
        )
    }

    /// Fetches account-bound playback tracking URLs by making an authenticated WEB-client
    /// `/player` request. The iOS-client player request (used for HLS stream URLs) is
    /// unauthenticated, so its `playbackTracking` URLs carry no account context. A WEB-client
    /// request on www.youtube.com (the same endpoint the IFrame player and youtube.com use)
    /// returns URLs that YouTube has pre-bound to the signed-in account server-side — pinging
    /// those URLs records the view in watch history.
    ///
    /// Endpoint: `https://www.youtube.com/youtubei/v1/player` via `postWebSafari`. The web
    /// client uses **SAPISIDHASH** auth when `self.sapisid` is set (obtained from
    /// `AuthService.fetchYouTubeWebCookies()` after every device-code sign-in — see
    /// `AuthService+DeviceFlow.swift:71`), or falls back to Bearer+X-Goog-AuthUser when no
    /// SAPISID is available. Both are legitimate web-session auth schemes from YouTube's
    /// perspective.
    ///
    /// Why not the TV client on googleapis.com (the previous implementation): the
    /// googleapis.com InnerTube surface is a restricted API that exposes
    /// streamingData/playabilityStatus/videoDetails but does NOT include `playbackTracking`
    /// in the response. Confirmed live (user retest after #288's three fixes, 2026-07-08):
    /// the TV endpoint returned videoDetails/playabilityStatus but the `playbackTracking`
    /// key was always absent. The www.youtube.com web endpoint reliably returns it.
    ///
    /// Called in parallel with the primary iOS player fetch; only the tracking URLs are kept.
    public func fetchAuthenticatedTrackingURLs(videoId: String) async -> PlaybackTrackingURLs? {
        guard authToken != nil || sapisid != nil else {
            return nil
        }
        do {
            let body = await buildTrackingURLsBody(videoId: videoId)
            let data = try await postWebSafari(body: body, allowBearerFallback: true)
            guard
                let tracking  = data["playbackTracking"] as? [String: Any],
                let pbStr      = (tracking["videostatsPlaybackUrl"]  as? [String: Any])?["baseUrl"] as? String,
                let wtStr      = (tracking["videostatsWatchtimeUrl"] as? [String: Any])?["baseUrl"] as? String,
                let pbURL      = URL(string: pbStr),
                let wtURL      = URL(string: wtStr)
            else {
                Log.innerTube.notice("fetchAuthenticatedTrackingURLs: no tracking data in WEB player response for \(videoId)")
                return nil
            }
            Log.innerTube.notice("fetchAuthenticatedTrackingURLs: account-bound URLs obtained for \(videoId)")
            return PlaybackTrackingURLs(playbackURL: pbURL, watchtimeURL: wtURL)
        } catch {
            Log.innerTube.error("fetchAuthenticatedTrackingURLs failed for \(videoId): \(error)")
            return nil
        }
    }

    /// Same as `fetchAuthenticatedTrackingURLs(videoId:)` but uses the supplied token directly
    /// instead of reading `self.authToken`. Use this when the caller holds the token but cannot
    /// guarantee that `setAuthToken` has already propagated to the actor (e.g. prefetch tasks
    /// that start before `PlaybackViewModel.updateAuthToken` has had a chance to run).
    public func fetchAuthenticatedTrackingURLs(videoId: String, usingToken token: String) async -> PlaybackTrackingURLs? {
        do {
            let body = await buildTrackingURLsBody(videoId: videoId)
            // Mirror the with-token path: postWebSafari reads authToken / sapisid from the
            // actor for its auth-scheme dispatch. The actor's authToken should already be set
            // by the time prefetch runs (PlaybackViewModel's updateAuthToken is called before
            // prefetch in the standard path). If the caller has a token but the actor doesn't
            // yet, seed it here so postWebSafari can use Bearer+AuthUser as a fallback when
            // SAPISIDHASH is unavailable.
            if authToken == nil { authToken = token }
            let data = try await postWebSafari(body: body, allowBearerFallback: true)
            guard
                let tracking  = data["playbackTracking"] as? [String: Any],
                let pbStr      = (tracking["videostatsPlaybackUrl"]  as? [String: Any])?["baseUrl"] as? String,
                let wtStr      = (tracking["videostatsWatchtimeUrl"] as? [String: Any])?["baseUrl"] as? String,
                let pbURL      = URL(string: pbStr),
                let wtURL      = URL(string: wtStr)
            else {
                Log.innerTube.notice("fetchAuthenticatedTrackingURLs: no tracking data in WEB player response for \(videoId)")
                return nil
            }
            Log.innerTube.notice("fetchAuthenticatedTrackingURLs: account-bound URLs obtained for \(videoId)")
            return PlaybackTrackingURLs(playbackURL: pbURL, watchtimeURL: wtURL)
        } catch {
            Log.innerTube.error("fetchAuthenticatedTrackingURLs failed for \(videoId): \(error)")
            return nil
        }
    }

    /// Builds the WEB-client `/player` body for a tracking-URLs-only request on
    /// www.youtube.com (via postWebSafari). Mirrors `fetchPlayerInfoWebSafari`'s body shape:
    /// the web client + `playbackContext.contentPlaybackContext` (with optional
    /// `signatureTimestamp`). The web endpoint does not use the TV `att/get` attestation
    /// (`fetchAttestationToken` would fail on the web transport), so the previous
    /// `serviceIntegrityDimensions.poToken` line is removed.
    ///
    /// History: an earlier version of this function used the TV client on googleapis.com
    /// (a restricted API that does not return `playbackTracking` at all), then was updated
    /// to use a richer body shape with the TV client — which still didn't return
    /// `playbackTracking`. The actual fix is the endpoint, not the body — confirmed live
    /// (user retest 2026-07-08).
    private func buildTrackingURLsBody(videoId: String) async -> [String: Any] {
        var clientFields = (webSafariClientContext["client"] as? [String: Any]) ?? [:]
        if let vd = visitorData { clientFields["visitorData"] = vd }
        let sts = await fetchSignatureTimestampIfNeeded()
        var cpbc: [String: Any] = ["html5Preference": "HTML5_PREF_WANTS"]
        if let sts { cpbc["signatureTimestamp"] = sts }

        var body = makeBody(client: ["client": clientFields])
        body["videoId"] = videoId
        body["playbackContext"] = ["contentPlaybackContext": cpbc]
        return body
    }

    // MARK: - Private player helpers

    /// The start time of an upcoming premiere / live stream.
    static func parseScheduledStart(from json: [String: Any]) -> Date? {
        if let slate = ((((json["playabilityStatus"] as? [String: Any])?["liveStreamability"]
                            as? [String: Any])?["liveStreamabilityRenderer"]
                            as? [String: Any])?["offlineSlate"]
                            as? [String: Any])?["liveStreamOfflineSlateRenderer"] as? [String: Any],
           let raw = slate["scheduledStartTime"],
           let seconds = (raw as? String).flatMap({ Double($0) }) ?? (raw as? Double) {
            return Date(timeIntervalSince1970: seconds)
        }
        if let timestamp = (((json["microformat"] as? [String: Any])?["playerMicroformatRenderer"]
                            as? [String: Any])?["liveBroadcastDetails"]
                            as? [String: Any])?["startTimestamp"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: timestamp) ?? ISO8601DateFormatter().date(from: timestamp)
        }
        return nil
    }

    private func parsePlayerInfo(from json: [String: Any], videoId: String) throws -> PlayerInfo {
        let videoDetails = json["videoDetails"] as? [String: Any]
        let title = videoDetails?["title"] as? String ?? ""
        let channelTitle = videoDetails?["author"] as? String ?? ""
        let description = videoDetails?["shortDescription"] as? String
        let durationStr = videoDetails?["lengthSeconds"] as? String
        let duration = durationStr.flatMap { Double($0) }
        let isLive = videoDetails?["isLiveContent"] as? Bool ?? false
        let viewCount = (videoDetails?["viewCount"] as? String).flatMap { Int($0) }
        let thumbURL = ((videoDetails?["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]])?
            .last.flatMap { $0["url"] as? String }.flatMap { URL(string: $0) }

        let streamingData = json["streamingData"] as? [String: Any]
        let playabilityDict  = json["playabilityStatus"] as? [String: Any]
        let playabilityStatus = playabilityDict?["status"] as? String ?? "unknown"
        let playabilityReason = playabilityDict?["reason"] as? String
            ?? (playabilityDict?["errorScreen"] as? [String: Any])
                .flatMap { ($0["playerErrorMessageRenderer"] as? [String: Any])?["subreason"] as? [String: Any] }
                .flatMap { extractText($0) }
        Log.innerTube.notice("parsePlayerInfo id=\(videoId) playability=\(playabilityStatus) reason=\(playabilityReason ?? "nil") hasStreamingData=\(streamingData != nil)")

        // Fail early for definitely-unplayable videos so callers don't waste work on
        // related/SponsorBlock fetches. Mirrors Android playabilityStatus check.
        if streamingData == nil, playabilityStatus != "OK" {
            let reason = playabilityReason ?? "This video is unavailable (\(playabilityStatus))"
            Log.innerTube.error("❌ parsePlayerInfo: unplayable — \(reason)")
            // A premiere / live stream that hasn't started is not a failure to resolve: the caller offers to defer
            // the video to its start time instead of showing an error.
            let isUpcoming = videoDetails?["isUpcoming"] as? Bool ?? false
            if playabilityStatus == "LIVE_STREAM_OFFLINE" || isUpcoming {
                let start = Self.parseScheduledStart(from: json)
                Log.innerTube.notice("parsePlayerInfo: scheduled — starts \(start.map { ISO8601DateFormatter().string(from: $0) } ?? "unknown")")
                throw APIError.scheduled(start)
            }
            // Age-gate / sign-in: checked before IP-block so the caller shows "Sign In" not "Try Again".
            // An age gate is singled out because it names the reason; "sign in to confirm you're not
            // a bot" is bot detection and stays `signInRequired`.
            let lowerReason = reason.lowercased()
            let ageStatuses: Set<String> = ["AGE_VERIFICATION_REQUIRED", "AGE_CHECK_REQUIRED"]
            let ageKeywords = [
                "confirm your age", "age-restricted", "age restricted",
                "18+", "age verification", "inappropriate for some users"
            ]
            if ageStatuses.contains(playabilityStatus)
                || ageKeywords.contains(where: { lowerReason.contains($0) }) {
                throw APIError.ageRestricted
            }
            if playabilityStatus == "LOGIN_REQUIRED" || lowerReason.contains("sign in") {
                throw APIError.signInRequired
            }
            // Check for IP-block signals before throwing the generic unavailable error.
            let ipBlockKeywords = ["your ip", "ip address", "vpn", "proxy", "bot", "sign in to confirm"]
            if ipBlockKeywords.contains(where: { lowerReason.contains($0) }) {
                throw APIError.ipBlocked(reason)
            }
            throw APIError.unavailable(reason)
        }

        var formats: [VideoFormat] = []

        func parseFormats(_ raw: [[String: Any]]) -> [VideoFormat] {
            raw.compactMap { f -> VideoFormat? in
                guard f["itag"] is Int else { return nil }
                let urlStr = f["url"] as? String
                let url = urlStr.flatMap { URL(string: $0) }
                let quality = f["qualityLabel"] as? String ?? f["quality"] as? String ?? "unknown"
                let mimeType = f["mimeType"] as? String ?? ""
                let width = f["width"] as? Int ?? 0
                // SABR adaptive formats (TV auth) often omit the "height" JSON field even
                // though qualityLabel is present (e.g. "720p60"). Derive height from the
                // label so the quality picker includes them.
                var height = f["height"] as? Int ?? 0
                if height == 0 {
                    let digits = quality.prefix(while: { $0.isNumber })
                    if !digits.isEmpty { height = Int(digits) ?? 0 }
                }
                let fps = f["fps"] as? Int ?? 30
                let bitrate = f["bitrate"] as? Int
                return VideoFormat(label: quality, width: width, height: height, fps: fps, mimeType: mimeType, url: url, bitrate: bitrate)
            }
        }

        if let f = streamingData?["formats"] as? [[String: Any]] {
            formats += parseFormats(f)
            let muxedSummary = f.compactMap { entry -> String? in
                guard let itag = entry["itag"] as? Int else { return nil }
                let q = entry["qualityLabel"] as? String ?? entry["quality"] as? String ?? "?"
                let br = (entry["bitrate"] as? Int).map { "\($0 / 1000)kbps" } ?? "?"
                let hasURL = entry["url"] is String ? "url=yes" : "url=no"
                return "itag=\(itag) \(q) \(br) \(hasURL)"
            }.joined(separator: "; ")
            let muxedDisplay = muxedSummary.isEmpty ? "none" : muxedSummary
            Log.innerTube.notice("muxedFormats for \(videoId): [\(muxedDisplay)]")
        }
        if let f = streamingData?["adaptiveFormats"] as? [[String: Any]] {
            formats += parseFormats(f)
        }
        // Remove exact-duplicate entries that appear when a video has many audio tracks
        // (e.g. multi-language uploads return the same itag repeated for each language
        // variant, all with distinct URLs). Keep unique by URL string; fall back to
        // index-based dedup for formats without a URL.
        var seen = Set<String>()
        formats = formats.filter { fmt in
            let key = fmt.url?.absoluteString ?? "\(fmt.mimeType)-\(fmt.label)-\(fmt.bitrate ?? 0)"
            return seen.insert(key).inserted
        }

        let hlsURL = (streamingData?["hlsManifestUrl"] as? String).flatMap { URL(string: $0) }
        let dashURL = (streamingData?["dashManifestUrl"] as? String).flatMap { URL(string: $0) }

        // Diagnostics: log adaptive format heights and first URL param snapshot.
        let adaptiveFormatsRaw = streamingData?["adaptiveFormats"] as? [[String: Any]] ?? []
        let adaptiveHeights = adaptiveFormatsRaw.compactMap { $0["height"] as? Int }
        let firstAdaptiveC = adaptiveFormatsRaw.first(where: {
            ($0["mimeType"] as? String)?.hasPrefix("video/") == true && $0["url"] != nil
        }).flatMap { ($0["url"] as? String)?.components(separatedBy: "&").first(where: { $0.hasPrefix("c=") }) } ?? "none"
        let streamingKeys = streamingData.map { Array($0.keys.sorted().prefix(12)) } ?? []
        Log.innerTube.notice("parsePlayerInfo id=\(videoId) hls=\(hlsURL != nil) dash=\(dashURL != nil) totalFormats=\(formats.count) adaptiveHeights=\(adaptiveHeights.prefix(8)) firstAdaptiveC=\(firstAdaptiveC) streamingKeys=\(streamingKeys)")

        // Captions — parse from captions.playerCaptionsTracklistRenderer.captionTracks
        let captionTracks: [CaptionTrack] = {
            guard let trackList = (json["captions"] as? [String: Any])
                .flatMap({ $0["playerCaptionsTracklistRenderer"] as? [String: Any] })
                .flatMap({ $0["captionTracks"] as? [[String: Any]] })
            else { return [] }
            return trackList.compactMap { track -> CaptionTrack? in
                guard let baseUrlStr = track["baseUrl"] as? String,
                      let baseURL = URL(string: baseUrlStr) else { return nil }
                let languageCode = track["languageCode"] as? String ?? ""
                let name = (track["name"] as? [String: Any]).flatMap { extractText($0) }
                    ?? (track["nameTranslated"] as? [String: Any]).flatMap { extractText($0) }
                    ?? languageCode
                let vssId = track["vssId"] as? String ?? ""
                let kind = track["kind"] as? String ?? ""
                let isAuto = vssId.hasPrefix("a.") || kind == "asr"
                let trackId = vssId.isEmpty ? languageCode : vssId
                return CaptionTrack(id: trackId, baseURL: baseURL, name: name, languageCode: languageCode, isAutoGenerated: isAuto)
            }
        }()
        Log.innerTube.notice("parsePlayerInfo: captionTracks=\(captionTracks.count)")

        // Playback tracking — parse the stat URLs that must be pinged to record
        // the view in YouTube's official watch history.
        let trackingURLs: PlaybackTrackingURLs? = {
            guard let tracking = json["playbackTracking"] as? [String: Any],
                  let playbackStr = (tracking["videostatsPlaybackUrl"] as? [String: Any])?["baseUrl"] as? String,
                  let watchtimeStr = (tracking["videostatsWatchtimeUrl"] as? [String: Any])?["baseUrl"] as? String,
                  let playbackURL = URL(string: playbackStr),
                  let watchtimeURL = URL(string: watchtimeStr)
            else {
                Log.innerTube.notice("parsePlayerInfo: no playbackTracking URLs in response")
                return nil
            }
            Log.innerTube.notice("parsePlayerInfo: got playbackTracking URLs")
            return PlaybackTrackingURLs(playbackURL: playbackURL, watchtimeURL: watchtimeURL)
        }()

        let video = ITVideo(
            id: videoId,
            title: title,
            channelTitle: channelTitle,
            description: description,
            thumbnailURL: thumbURL,
            duration: duration,
            viewCount: viewCount,
            isLive: isLive
        )

        guard hlsURL != nil || !formats.isEmpty else {
            throw APIError.unavailable("This video is unavailable")
        }
        // If streamingData is present but every format URL is nil, the server returned
        // cipher-protected URLs that we cannot decode (signatureCipher / cipher fields).
        // Treat this as unavailable so the caller's fallback chain (Android client) fires
        // rather than surfacing a confusing "No stream URL" decoding error.
        let hasAnyURL = hlsURL != nil || formats.contains { $0.url != nil }
        if !hasAnyURL {
            Log.innerTube.error("❌ parsePlayerInfo: streamingData present but all format URLs are nil (cipher-protected?)")
            throw APIError.unavailable("Stream URLs require decryption — not supported by this client")
        }

        let originalAudioLanguage: String = {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(title)
            guard let lang = recognizer.dominantLanguage, lang != .undetermined else { return "en" }
            return lang.rawValue
        }()
        Log.innerTube.info("parsePlayerInfo title=\(title) detectedLanguage=\(originalAudioLanguage)")

        let endCards = parseEndCards(from: json)
        Log.innerTube.notice("parsePlayerInfo: endCards=\(endCards.count)")
        return PlayerInfo(video: video, formats: formats, hlsURL: hlsURL, dashURL: dashURL, captionTracks: captionTracks, trackingURLs: trackingURLs, endCards: endCards, originalAudioLanguage: originalAudioLanguage)
    }

    // MARK: - End cards parser

    private func parseEndCards(from json: [String: Any]) -> [EndCard] {
        guard let endscreen = (json["endscreen"] as? [String: Any])?["endscreenRenderer"] as? [String: Any],
              let elements = endscreen["elements"] as? [[String: Any]]
        else {
            Log.innerTube.notice("parseEndCards: no endscreen key in response (normal for iOS client)")
            return []
        }

        return elements.compactMap { element -> EndCard? in
            guard let renderer = element["endscreenElementRenderer"] as? [String: Any] else { return nil }

            let styleRaw = renderer["style"] as? String ?? ""
            let style = EndCard.Style(rawValue: styleRaw) ?? .unknown

            let endpoint = renderer["endpoint"] as? [String: Any]
            let videoId = (endpoint?["watchEndpoint"] as? [String: Any])?["videoId"] as? String

            let title = (renderer["title"] as? [String: Any]).flatMap { extractText($0) } ?? ""

            let thumbnailURL = ((renderer["image"] as? [String: Any])?["thumbnails"] as? [[String: Any]])?
                .last.flatMap { $0["url"] as? String }.flatMap { URL(string: $0) }

            // NSNumber bridges all JSON numbers (int or float). Use .intValue so both
            // integer JSON numbers (e.g. 257357) and float ones (257357.0) are handled.
            // Some API versions return startMs/endMs as quoted strings; fall back to that.
            func parseInt(_ key: String) -> Int {
                if let n = renderer[key] as? NSNumber { return n.intValue }
                if let s = renderer[key] as? String   { return Int(s) ?? 0 }
                return 0
            }

            // Position fields are always floats from the API (0–100 range).
            func parseDouble(_ key: String, default def: Double) -> Double {
                if let n = renderer[key] as? NSNumber { return n.doubleValue }
                return def
            }

            let left        = parseDouble("left",        default: 0)
            let top         = parseDouble("top",         default: 0)
            let width       = parseDouble("width",       default: 20)
            let aspectRatio = parseDouble("aspectRatio", default: 1.7778)
            let startMs     = parseInt("startMs")
            let endMs       = parseInt("endMs")
            let id          = renderer["id"] as? String ?? UUID().uuidString

            Log.innerTube.notice("endCard id=\(id) style=\(styleRaw) videoId=\(videoId ?? "nil") startMs=\(startMs) endMs=\(endMs)")

            return EndCard(
                id: id,
                style: style,
                videoId: videoId,
                title: title,
                thumbnailURL: thumbnailURL,
                left: left,
                top: top,
                width: width,
                aspectRatio: aspectRatio,
                startMs: startMs,
                endMs: endMs
            )
        }
    }

    // MARK: - Tracking URL helpers

    /// Account-bound session params YouTube mints into the `playbackTracking` URLs.
    /// Without all three the stats server silently drops the ping (Android bails out too).
    struct TrackingSession: Sendable {
        let eventId: String
        let visitorMonitoring: String
        let ofParam: String
        let playlistId: String?
    }

    /// Extracts `ei`/`vm`/`of`/`plid` from the watchtime tracking URL.
    /// Mirrors Android's `VideoInfo.parseTrackingParams`.
    static func trackingSession(from urls: PlaybackTrackingURLs?) -> TrackingSession? {
        guard let urls,
            let items = URLComponents(url: urls.watchtimeURL, resolvingAgainstBaseURL: false)?.queryItems
        else { return nil }
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value.flatMap { $0.isEmpty ? nil : $0 }
        }
        guard let ei = value("ei"), let vm = value("vm"), let of = value("of") else { return nil }
        return TrackingSession(eventId: ei, visitorMonitoring: vm, ofParam: of, playlistId: value("plid"))
    }

    static func formatSeconds(_ seconds: TimeInterval) -> String {
        String(format: "%.3f", max(0, seconds))
    }

    /// Builds and fires a YouTube stats ping, always against `www.youtube.com`.
    ///
    /// The `baseUrl` in `playbackTracking` frequently points at `s.youtube.com`, which is
    /// widely blocked and — more importantly — is not the host Android authenticates against.
    /// Android's OkHttp interceptor only attaches the Bearer token and `X-Goog-Visitor-Id`
    /// to URLs prefixed `https://www.youtube.com/api/stats/`, so rebuilding the URL is what
    /// makes the ping account-attributable in the first place.
    private func pingStatsEndpoint(
        _ endpoint: String,
        session: TrackingSession,
        params: [String: String]
    ) async {
        var comps = URLComponents(string: "https://www.youtube.com/api/stats/\(endpoint)")!
        var items = [
            URLQueryItem(name: "ns", value: "yt"),
            URLQueryItem(name: "ver", value: "2"),
        ]
        items += params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        items += [
            URLQueryItem(name: "ei", value: session.eventId),
            URLQueryItem(name: "vm", value: session.visitorMonitoring),
            URLQueryItem(name: "of", value: session.ofParam),
        ]
        if let plid = session.playlistId {
            items.append(URLQueryItem(name: "plid", value: plid))
        }
        comps.queryItems = items
        guard let url = comps.url else {
            Log.innerTube.error("pingStatsEndpoint: failed to build URL for \(endpoint)")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(iosUserAgent, forHTTPHeaderField: "User-Agent")
        // Use the same web-session authentication as the tracking-URL request.
        // SAPISIDHASH is required for youtube.com stats endpoints to associate the
        // ping with the signed-in account; Bearer is only the fallback when no web
        // cookie is available.
        if let sid = sapisid {
            request.setValue(Self.sapisidhash(sapisid: sid), forHTTPHeaderField: "Authorization")
        } else if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let vd = visitorData {
            request.setValue(vd, forHTTPHeaderField: "X-Goog-Visitor-Id")
        }
        await sendTrackingRequest(request, url: url)
    }

    /// Fires the prepared stats request, logging the response body and retrying once
    /// on transient failures. The stats server answers 200 for both credited and
    /// silently-dropped pings, so the body is the only attribution signal available.
    private func sendTrackingRequest(_ request: URLRequest, url: URL) async {
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                Log.innerTube.warning(
                    "trackingPing: HTTP \(http.statusCode) for \(url.absoluteString.prefix(120))")
            } else {
                let bodyPreview =
                    String(data: data.prefix(200), encoding: .utf8)?
                    .replacingOccurrences(of: "\n", with: " ")
                    ?? "(non-utf8 \(data.count) bytes)"
                Log.innerTube.notice(
                    "trackingPing: ok — body=\(bodyPreview) for \(url.absoluteString.prefix(120))"
                )
            }
        } catch is CancellationError {
            // Task was cancelled (user navigated away) — expected, do not retry.
        } catch {
            Log.innerTube.warning(
                "trackingPing: transient error (\(error.localizedDescription)) — retrying once")
            do {
                let (data, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    Log.innerTube.error(
                        "trackingPing: retry HTTP \(http.statusCode) for \(url.absoluteString.prefix(120))"
                    )
                } else {
                    let bodyPreview =
                        String(data: data.prefix(200), encoding: .utf8)?
                        .replacingOccurrences(of: "\n", with: " ")
                        ?? "(non-utf8 \(data.count) bytes)"
                    Log.innerTube.notice(
                        "trackingPing: retry ok — body=\(bodyPreview) for \(url.absoluteString.prefix(120))"
                    )
                }
            } catch {
                Log.innerTube.error("trackingPing: retry also failed — \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Test helpers (for AuthenticatedTrackingURLsTests)

    static func statsURLForTesting(
        _ endpoint: String, session: TrackingSession, params: [String: String]
    ) -> URL? {
        var comps = URLComponents(string: "https://www.youtube.com/api/stats/\(endpoint)")!
        var items = [
            URLQueryItem(name: "ns", value: "yt"),
            URLQueryItem(name: "ver", value: "2"),
        ]
        items += params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        items += [
            URLQueryItem(name: "ei", value: session.eventId),
            URLQueryItem(name: "vm", value: session.visitorMonitoring),
            URLQueryItem(name: "of", value: session.ofParam),
        ]
        if let plid = session.playlistId {
            items.append(URLQueryItem(name: "plid", value: plid))
        }
        comps.queryItems = items
        return comps.url
    }
}
