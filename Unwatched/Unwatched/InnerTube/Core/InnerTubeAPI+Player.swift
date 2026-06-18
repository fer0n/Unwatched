import Foundation
import NaturalLanguage
import os
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private let tubeLog = Logger(subsystem: appSubsystem, category: "InnerTube")

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
            tubeLog.notice("[InnerTube] ✅ poToken applied to \(videoId, privacy: .public) via iOS client (len=\(pot.count))")
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
        tubeLog.notice("[InnerTube] fetchPlayerInfoWebWithPoToken: apiVD.len=\(apiVD.count) webVD.len=\(webVD?.count ?? 0) match=\(apiVD == (webVD ?? ""))")
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
            tubeLog.notice("[InnerTube] ✅ poToken applied to \(videoId, privacy: .public) via WebSafari+pot client (len=\(pot.count))")
            info = info.applyingPoToken(pot)
        }
        return info
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
        body["thirdParty"] = [
            "embedUrl": "https://www.youtube.com/embed/\(videoId)"
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
            tubeLog.notice("[InnerTube] ✅ poToken applied to \(videoId, privacy: .public) via iOS-auth client (len=\(pot.count))")
            info = info.applyingPoToken(pot)
        }
        return info
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
            tubeLog.notice("D-16 SABR URL (first 200): \(sabrStr.prefix(200), privacy: .public)")
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
                    tubeLog.notice("D-16 SABR GET Bearer: HTTP \(http.statusCode, privacy: .public) ct=\(ct, privacy: .public) body_preview=\(preview.prefix(200), privacy: .public)")
                } else {
                    tubeLog.notice("D-16 SABR GET Bearer: fail/timeout")
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
            tubeLog.notice("TVAuth: seeded visitorData from player response — retrying")
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
        tubeLog.notice("fetchEndCards id=\(videoId, privacy: .public) → \(cards.count, privacy: .public) cards")
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
    /// Mirrors Android's `VideoStateController` stats-ping behaviour in MediaServiceCore.
    /// - Parameters:
    ///   - videoId: The YouTube video ID being watched.
    ///   - cpn: The Client Playback Nonce for this session (see `generateCPN()`).
    ///   - trackingURLs: Tracking URLs from the player response; if nil, falls back to constructed URLs.
    public func reportPlaybackStarted(videoId: String, cpn: String, trackingURLs: PlaybackTrackingURLs?) async {
        let url = trackingURLs?.playbackURL ?? Self.fallbackPlaybackURL(videoId: videoId)
        let extraParams: [String: String] = [
            "ver":   "2",
            "cpn":   cpn,
            "docid": videoId,
            "cmt":   "0",
        ]
        await pingTrackingURL(url, extraParams: extraParams)
        tubeLog.notice("reportPlaybackStarted: videoId=\(videoId, privacy: .public) cpn=\(cpn.prefix(4), privacy: .public)… usedFallback=\(trackingURLs == nil, privacy: .public)")
    }

    /// Fires `videostatsWatchtimeUrl` to record a watched interval in the user's YouTube watch history.
    /// Should be called when playback stops/pauses/ends.
    /// - Parameters:
    ///   - videoId: The YouTube video ID being watched.
    ///   - cpn: The same Client Playback Nonce used in `reportPlaybackStarted`.
    ///   - trackingURLs: Tracking URLs from the player response; if nil, falls back to constructed URLs.
    ///   - segmentStart: Playhead position (seconds) when the current play segment began.
    ///   - segmentEnd: Playhead position (seconds) when the current play segment ended (i.e. now).
    public func reportWatchtime(
        videoId: String,
        cpn: String,
        trackingURLs: PlaybackTrackingURLs?,
        segmentStart: TimeInterval,
        segmentEnd: TimeInterval
    ) async {
        let url = trackingURLs?.watchtimeURL ?? Self.fallbackWatchtimeURL(videoId: videoId)
        let extraParams: [String: String] = [
            "ver":   "2",
            "cpn":   cpn,
            "docid": videoId,
            "cmt":   String(format: "%.3f", segmentEnd),
            "st":    String(format: "%.3f", segmentStart),
            "et":    String(format: "%.3f", segmentEnd),
        ]
        await pingTrackingURL(url, extraParams: extraParams)
        tubeLog.notice("reportWatchtime: videoId=\(videoId, privacy: .public) st=\(Int(segmentStart))s et=\(Int(segmentEnd))s")
    }

    /// Fetches account-bound playback tracking URLs by making an authenticated TV-client
    /// `/player` request. The iOS-client player request (used for HLS stream URLs) is
    /// unauthenticated, so its `playbackTracking` URLs carry no account context. A TV-client
    /// request with the OAuth Bearer token returns URLs that YouTube has pre-bound to the
    /// signed-in account server-side — pinging those URLs records the view in watch history.
    ///
    /// Called in parallel with the primary iOS player fetch; only the tracking URLs are kept.
    public func fetchAuthenticatedTrackingURLs(videoId: String) async -> PlaybackTrackingURLs? {
        guard authToken != nil else { return nil }
        do {
            var body = makeBody(client: tvClientContext)
            body["videoId"] = videoId
            body["racyCheckOk"] = true
            body["contentCheckOk"] = true
            let data = try await postTV(endpoint: "player", body: body)
            guard
                let tracking  = data["playbackTracking"] as? [String: Any],
                let pbStr      = (tracking["videostatsPlaybackUrl"]  as? [String: Any])?["baseUrl"] as? String,
                let wtStr      = (tracking["videostatsWatchtimeUrl"] as? [String: Any])?["baseUrl"] as? String,
                let pbURL      = URL(string: pbStr),
                let wtURL      = URL(string: wtStr)
            else {
                tubeLog.notice("fetchAuthenticatedTrackingURLs: no tracking data in TV player response for \(videoId, privacy: .public)")
                return nil
            }
            tubeLog.notice("fetchAuthenticatedTrackingURLs: account-bound URLs obtained for \(videoId, privacy: .public)")
            return PlaybackTrackingURLs(playbackURL: pbURL, watchtimeURL: wtURL)
        } catch {
            tubeLog.error("fetchAuthenticatedTrackingURLs failed for \(videoId, privacy: .public): \(error, privacy: .public)")
            return nil
        }
    }

    /// Same as `fetchAuthenticatedTrackingURLs(videoId:)` but uses the supplied token directly
    /// instead of reading `self.authToken`. Use this when the caller holds the token but cannot
    /// guarantee that `setAuthToken` has already propagated to the actor (e.g. prefetch tasks
    /// that start before `PlaybackViewModel.updateAuthToken` has had a chance to run).
    public func fetchAuthenticatedTrackingURLs(videoId: String, usingToken token: String) async -> PlaybackTrackingURLs? {
        do {
            var body = makeBody(client: tvClientContext)
            body["videoId"] = videoId
            body["racyCheckOk"] = true
            body["contentCheckOk"] = true
            let data = try await postTV(endpoint: "player", body: body, explicitBearerToken: token)
            guard
                let tracking  = data["playbackTracking"] as? [String: Any],
                let pbStr      = (tracking["videostatsPlaybackUrl"]  as? [String: Any])?["baseUrl"] as? String,
                let wtStr      = (tracking["videostatsWatchtimeUrl"] as? [String: Any])?["baseUrl"] as? String,
                let pbURL      = URL(string: pbStr),
                let wtURL      = URL(string: wtStr)
            else {
                tubeLog.notice("fetchAuthenticatedTrackingURLs: no tracking data in TV player response for \(videoId, privacy: .public)")
                return nil
            }
            tubeLog.notice("fetchAuthenticatedTrackingURLs: account-bound URLs obtained for \(videoId, privacy: .public)")
            return PlaybackTrackingURLs(playbackURL: pbURL, watchtimeURL: wtURL)
        } catch {
            tubeLog.error("fetchAuthenticatedTrackingURLs failed for \(videoId, privacy: .public): \(error, privacy: .public)")
            return nil
        }
    }

    // MARK: - Private player helpers

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
        tubeLog.notice("parsePlayerInfo id=\(videoId, privacy: .public) playability=\(playabilityStatus, privacy: .public) reason=\(playabilityReason ?? "nil", privacy: .public) hasStreamingData=\(streamingData != nil, privacy: .public)")

        // Fail early for definitely-unplayable videos so callers don't waste work on
        // related/SponsorBlock fetches. Mirrors Android playabilityStatus check.
        if streamingData == nil, playabilityStatus != "OK" {
            let reason = playabilityReason ?? "This video is unavailable (\(playabilityStatus))"
            tubeLog.error("❌ parsePlayerInfo: unplayable — \(reason, privacy: .public)")
            // Sign-in / age-gate: checked before IP-block so the caller shows "Sign In" not "Try Again".
            let signInStatuses: Set<String> = ["LOGIN_REQUIRED", "AGE_VERIFICATION_REQUIRED", "AGE_CHECK_REQUIRED"]
            if signInStatuses.contains(playabilityStatus) {
                throw APIError.signInRequired
            }
            let lowerReason = reason.lowercased()
            let signInKeywords = ["sign in", "age-restricted", "age restricted", "18+", "age verification"]
            if signInKeywords.contains(where: { lowerReason.contains($0) }) {
                throw APIError.signInRequired
            }
            // Check for IP-block signals before throwing the generic unavailable error.
            let lower = lowerReason
            let ipBlockKeywords = ["your ip", "ip address", "vpn", "proxy", "bot", "sign in to confirm"]
            if ipBlockKeywords.contains(where: { lower.contains($0) }) {
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
            tubeLog.notice("muxedFormats for \(videoId, privacy: .public): [\(muxedDisplay, privacy: .public)]")
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
        tubeLog.notice("parsePlayerInfo id=\(videoId, privacy: .public) hls=\(hlsURL != nil, privacy: .public) dash=\(dashURL != nil, privacy: .public) totalFormats=\(formats.count, privacy: .public) adaptiveHeights=\(adaptiveHeights.prefix(8), privacy: .public) firstAdaptiveC=\(firstAdaptiveC, privacy: .public) streamingKeys=\(streamingKeys, privacy: .public)")

        // Captions — parse from captions.playerCaptionsTracklistRenderer.captionTracks
        let captionTracks: [CaptionTrack] = {
            guard let trackList = (json["captions"] as? [String: Any])
                .flatMap({ $0["playerCaptionsTracklistRenderer"] as? [String: Any] })
                .flatMap({ $0["captionTracks"] as? [[String: Any]] })
            else { return [] }
            return trackList.compactMap { track -> CaptionTrack? in
                guard let baseUrlStr = track["baseUrl"] as? String,
                      let rawURL = URL(string: baseUrlStr) else { return nil }
                // Force WebVTT format by appending fmt=vtt to the base URL
                var comps = URLComponents(url: rawURL, resolvingAgainstBaseURL: false)
                var items = comps?.queryItems ?? []
                items.removeAll { $0.name == "fmt" }
                items.append(URLQueryItem(name: "fmt", value: "vtt"))
                comps?.queryItems = items
                guard let baseURL = comps?.url else { return nil }
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
        tubeLog.notice("parsePlayerInfo: captionTracks=\(captionTracks.count, privacy: .public)")

        // Playback tracking — parse the stat URLs that must be pinged to record
        // the view in YouTube's official watch history.
        let trackingURLs: PlaybackTrackingURLs? = {
            guard let tracking = json["playbackTracking"] as? [String: Any],
                  let playbackStr = (tracking["videostatsPlaybackUrl"] as? [String: Any])?["baseUrl"] as? String,
                  let watchtimeStr = (tracking["videostatsWatchtimeUrl"] as? [String: Any])?["baseUrl"] as? String,
                  let playbackURL = URL(string: playbackStr),
                  let watchtimeURL = URL(string: watchtimeStr)
            else {
                tubeLog.notice("parsePlayerInfo: no playbackTracking URLs in response")
                return nil
            }
            tubeLog.notice("parsePlayerInfo: got playbackTracking URLs")
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
            tubeLog.error("❌ parsePlayerInfo: streamingData present but all format URLs are nil (cipher-protected?)")
            throw APIError.unavailable("Stream URLs require decryption — not supported by this client")
        }

        let originalAudioLanguage: String = {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(title)
            guard let lang = recognizer.dominantLanguage, lang != .undetermined else { return "en" }
            return lang.rawValue
        }()
        tubeLog.info("parsePlayerInfo title=\(title, privacy: .public) detectedLanguage=\(originalAudioLanguage, privacy: .public)")

        let endCards = parseEndCards(from: json)
        tubeLog.notice("parsePlayerInfo: endCards=\(endCards.count, privacy: .public)")
        return PlayerInfo(video: video, formats: formats, hlsURL: hlsURL, dashURL: dashURL, captionTracks: captionTracks, trackingURLs: trackingURLs, endCards: endCards, originalAudioLanguage: originalAudioLanguage)
    }

    // MARK: - End cards parser

    private func parseEndCards(from json: [String: Any]) -> [EndCard] {
        guard let endscreen = (json["endscreen"] as? [String: Any])?["endscreenRenderer"] as? [String: Any],
              let elements = endscreen["elements"] as? [[String: Any]]
        else {
            tubeLog.notice("parseEndCards: no endscreen key in response (normal for iOS client)")
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

            tubeLog.notice("endCard id=\(id, privacy: .public) style=\(styleRaw, privacy: .public) videoId=\(videoId ?? "nil", privacy: .public) startMs=\(startMs, privacy: .public) endMs=\(endMs, privacy: .public)")

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

    /// Appends extra query parameters to a YouTube stats URL and fires a fire-and-forget GET.
    /// Only adds parameters that are not already present in the base URL — preserving
    /// the `cpn`, `docid`, and other session params YouTube embedded in the tracking URL.
    private func pingTrackingURL(_ baseURL: URL, extraParams: [String: String]) async {
        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        var items = comps?.queryItems ?? []
        for (key, value) in extraParams {
            if !items.contains(where: { $0.name == key }) {
                items.append(URLQueryItem(name: key, value: value))
            }
        }
        comps?.queryItems = items
        guard let url = comps?.url else {
            tubeLog.error("pingTrackingURL: failed to build URL from \(baseURL, privacy: .public)")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(iosUserAgent, forHTTPHeaderField: "User-Agent")
        // Auth header is required — without it YouTube treats the ping as anonymous
        // and does not record the view in the account's watch history.
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        // BUG-006 fix: log errors and retry once for transient failures instead of silently discarding.
        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                tubeLog.warning("pingTrackingURL: HTTP \(http.statusCode) for \(url.absoluteString.prefix(120), privacy: .public)")
            }
        } catch is CancellationError {
            // Task was cancelled (user navigated away) — expected, do not retry.
        } catch {
            tubeLog.warning("pingTrackingURL: transient error (\(error.localizedDescription, privacy: .public)) — retrying once")
            do {
                let (_, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    tubeLog.error("pingTrackingURL: retry HTTP \(http.statusCode) for \(url.absoluteString.prefix(120), privacy: .public)")
                }
            } catch {
                tubeLog.error("pingTrackingURL: retry also failed — \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Constructs a fallback playback stats URL for when the player response omits `playbackTracking`.
    /// Matches the pattern used by YouTube.js and Android MediaServiceCore.
    private static func fallbackPlaybackURL(videoId: String) -> URL {
        var comps = URLComponents(string: "https://www.youtube.com/api/stats/playback")!
        comps.queryItems = [
            URLQueryItem(name: "ns",    value: "yt"),
            URLQueryItem(name: "el",    value: "detailpage"),
            URLQueryItem(name: "docid", value: videoId),
        ]
        return comps.url!
    }

    /// Constructs a fallback watchtime stats URL for when the player response omits `playbackTracking`.
    private static func fallbackWatchtimeURL(videoId: String) -> URL {
        var comps = URLComponents(string: "https://www.youtube.com/api/stats/watchtime")!
        comps.queryItems = [
            URLQueryItem(name: "ns",    value: "yt"),
            URLQueryItem(name: "el",    value: "detailpage"),
            URLQueryItem(name: "docid", value: videoId),
        ]
        return comps.url!
    }
}
