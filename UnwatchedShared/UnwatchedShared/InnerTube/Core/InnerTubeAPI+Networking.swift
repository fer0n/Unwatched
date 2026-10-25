import Foundation
import CryptoKit
import os
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Extracts the visitor identifier embedded in a YouTube watch page.
/// YouTube currently emits either the uppercase ytcfg key or lower-camel JSON key.
func extractYouTubeVisitorData(from html: String) -> String? {
    let patterns = [
        #"\"VISITOR_DATA\"\s*:\s*\"([^\"]+)\""#,
        #"\"visitorData\"\s*:\s*\"([^\"]+)\""#,
    ]
    for pattern in patterns {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: html, range: NSRange(html.startIndex..., in: html)
              ),
              let range = Range(match.range(at: 1), in: html) else { continue }
        let encodedValue = String(html[range])
        let quotedJSON = Data("\"\(encodedValue)\"".utf8)
        let value = (try? JSONDecoder().decode(String.self, from: quotedJSON))
            ?? encodedValue.replacingOccurrences(of: #"\u003d"#, with: "=")
        if !value.isEmpty { return value }
    }
    return nil
}

// MARK: - Networking

extension InnerTubeAPI {

    // MARK: - YouTube webpage session seeding

    /// Establishes the same anonymous YouTube session that current yt-dlp creates
    /// before its JS-less VisionOS player request. The watch-page response seeds
    /// youtube.com cookies and exposes visitorData required to avoid false
    /// `LOGIN_REQUIRED` bot-detection responses on otherwise public videos.
    func seedVisionOSSession(videoId: String) async {
        var components = URLComponents(string: "https://www.youtube.com/watch")!
        components.queryItems = [
            URLQueryItem(name: "v", value: videoId),
            URLQueryItem(name: "bpctr", value: "9999999999"),
            URLQueryItem(name: "has_verified", value: "1"),
        ]
        guard let url = components.url else { return }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: 15)
        // Unwatched: the session has no cookie store
        request.setValue("SOCS=CAI", forHTTPHeaderField: "Cookie")
        request.setValue(InnerTubeClients.WebSafari.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else { return }

        if let value = extractYouTubeVisitorData(from: html) {
            visitorData = value
            Log.innerTube.notice("VisionOS session seeded (visitorData len=\(value.count))")
            return
        }
        Log.innerTube.notice("VisionOS session watch page loaded without visitorData")
    }

    // MARK: - signatureTimestamp fetch

    /// Returns the current YouTube player `signatureTimestamp` (STS), fetching and
    /// caching it from YouTube's homepage if not already stored or if the cache has
    /// expired (TTL = 1 hour). The STS is required by the TV authenticated player
    /// request to validate the player JS version — YouTube returns
    /// "The page needs to be reloaded" when it is absent or stale.
    /// Returns `nil` silently on network failure so callers can proceed without it.
    func fetchSignatureTimestampIfNeeded() async -> Int? {
        if let sts = signatureTimestamp,
           let fetchedAt = signatureTimestampFetchedAt,
           Date().timeIntervalSince(fetchedAt) < 3600 {
            return sts
        }
        guard let url = URL(string: "https://www.youtube.com/") else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            let pattern = #""STS"\s*:\s*(\d+)"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  let range = Range(match.range(at: 1), in: html),
                  let sts = Int(html[range]) else {
                Log.innerTube.error("⚠️ signatureTimestamp: pattern not found in homepage response")
                return nil
            }
            signatureTimestamp = sts
            signatureTimestampFetchedAt = Date()
            Log.innerTube.notice("Fetched signatureTimestamp (STS): \(sts)")
            return sts
        } catch {
            Log.innerTube.error("⚠️ signatureTimestamp fetch failed: \(error)")
            return nil
        }
    }

    // MARK: - Attestation

    /// Fetches a proof-of-origin attestation token via YouTube's att/get endpoint.
    /// The returned `attestationToken` is included as `serviceIntegrityDimensions.poToken`
    /// in TV auth player requests. Returns nil silently on any failure.
    func fetchAttestationToken(videoId: String) async -> String? {
        guard let token = authToken else { return nil }
        guard let url = playerBaseURL.appendingPathComponent("att/get") as URL? else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(InnerTubeClients.TV.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(InnerTubeClients.TV.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8
        var clientFields = (tvClientContext["client"] as? [String: Any]) ?? [:]
        if let vd = visitorData { clientFields["visitorData"] = vd }
        var body: [String: Any] = ["context": ["client": clientFields]]
        body["contentBindingContext"] = ["videoId": videoId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                Log.innerTube.notice("att/get: statusCode=\(statusCode) — no JSON")
                return nil
            }
            let topKeys = Array(json.keys.prefix(8))
            Log.innerTube.notice("att/get: HTTP \(statusCode) keys: \(topKeys)")
            guard let attToken = json["attestationToken"] as? String, !attToken.isEmpty else {
                Log.innerTube.notice("att/get: no attestationToken in response keys=\(topKeys)")
                return nil
            }
            Log.innerTube.notice("att/get: ✅ attestationToken obtained (prefix=\(attToken.prefix(20))…)")
            return attToken
        } catch {
            Log.innerTube.notice("att/get: failed — \(error)")
            return nil
        }
    }

    // MARK: - Body builders

    public func makeBody(client: [String: Any], continuationToken: String? = nil, includeVisitorData: Bool = false, includePoToken: Bool = false) -> [String: Any] {
        var body: [String: Any] = ["context": client]
        if let token = continuationToken {
            body["continuation"] = token
        }
        if includeVisitorData, let visitor = visitorData {
            body["visitorData"] = visitor
        }
        if includePoToken, let pot = poToken {
            body["serviceIntegrityDimensions"] = ["poToken": pot]
        }
        return body
    }

    public func postPlayer(body: [String: Any]) async throws -> [String: Any] {
        guard var comps = URLComponents(url: playerBaseURL.appendingPathComponent("player"), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL("player")
        }
        comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = comps.url else { throw APIError.invalidURL("player") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(iosUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(InnerTubeClients.iOS.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(InnerTubeClients.iOS.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let playerVideoId = body["videoId"] as? String ?? ""
        Log.innerTube.notice("POST /player (iOS) videoId=\(playerVideoId)")
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            Log.innerTube.error("❌ HTTP \(statusCode) for /player")
            throw APIError.httpError(statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Log.innerTube.error("❌ Non-dictionary JSON root for /player")
            throw APIError.decodingError("Root JSON is not a dictionary")
        }
        if let error = json["error"] as? [String: Any] {
            Log.innerTube.error("❌ API error in /player: \(String(describing: error["message"] ?? error))")
        } else {
            let topKeys = Array(json.keys.prefix(6))
            Log.innerTube.notice("✅ /player HTTP \(statusCode) keys: \(topKeys)")
        }
        return json
    }

    /// Authenticated iOS client player request on youtubei.googleapis.com.
    /// Like `postPlayer` but adds a Bearer auth header when an auth token is available.
    /// Falls back to `postPlayer` (unauthenticated) if no token is stored.
    func postPlayerAuthenticated(body: [String: Any]) async throws -> [String: Any] {
        guard let token = authToken else {
            return try await postPlayer(body: body)
        }
        guard let comps = URLComponents(url: playerBaseURL.appendingPathComponent("player"),
                                        resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL("player")
        }
        guard let url = comps.url else { throw APIError.invalidURL("player") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(iosUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(InnerTubeClients.iOS.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(InnerTubeClients.iOS.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let playerVideoId = body["videoId"] as? String ?? ""
        Log.innerTube.notice("POST /player (iOS, auth) videoId=\(playerVideoId)")
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            Log.innerTube.error("❌ HTTP \(statusCode) for /player (iOS, auth)")
            throw APIError.httpError(statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Log.innerTube.error("❌ Non-dictionary JSON root for /player (iOS, auth)")
            throw APIError.decodingError("Root JSON is not a dictionary")
        }
        if let error = json["error"] as? [String: Any] {
            Log.innerTube.error("❌ API error in /player (iOS, auth): \(String(describing: error["message"] ?? error))")
        } else {
            let topKeys = Array(json.keys.prefix(6))
            Log.innerTube.notice("✅ /player (iOS, auth) HTTP \(statusCode) keys: \(topKeys)")
        }
        return json
    }

    /// visionOS player transport mirrored from current yt-dlp: www.youtube.com,
    /// public web API key, client 101 headers, and no OAuth/PO token.
    func postVisionOS(body: [String: Any]) async throws -> [String: Any] {
        guard var comps = URLComponents(url: baseURL.appendingPathComponent("player"),
                                        resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL("player")
        }
        comps.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "prettyPrint", value: "false"),
        ]
        guard let url = comps.url else { throw APIError.invalidURL("player") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue(InnerTubeClients.VisionOS.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(InnerTubeClients.VisionOS.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(InnerTubeClients.VisionOS.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        if let vd = visitorData {
            request.setValue(vd, forHTTPHeaderField: "X-Goog-Visitor-Id")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.httpError(statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodingError("Root JSON is not a dictionary")
        }
        return json
    }

    func postAndroid(endpoint: String, body: [String: Any]) async throws -> [String: Any] {
        guard var comps = URLComponents(url: playerBaseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL(endpoint)
        }
        comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = comps.url else { throw APIError.invalidURL(endpoint) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(InnerTubeClients.Android.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(InnerTubeClients.Android.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(InnerTubeClients.Android.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let videoId = body["videoId"] as? String ?? ""
        Log.innerTube.notice("POST /\(endpoint) [Android] videoId=\(videoId)")
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            Log.innerTube.error("❌ HTTP \(statusCode) for /\(endpoint) [Android]")
            throw APIError.httpError(statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Log.innerTube.error("❌ Non-dictionary JSON root for /\(endpoint) [Android]")
            throw APIError.decodingError("Root JSON is not a dictionary")
        }
        if let error = json["error"] as? [String: Any] {
            Log.innerTube.error("❌ API error in /\(endpoint) [Android]: \(String(describing: error["message"] ?? error))")
        } else {
            let topKeys = Array(json.keys.prefix(6))
            Log.innerTube.notice("✅ /\(endpoint) [Android] HTTP \(statusCode) keys: \(topKeys)")
        }
        return json
    }

    func post(endpoint: String, body: [String: Any], useAuth: Bool = false) async throws -> [String: Any] {
        guard var comps = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL(endpoint)
        }
        let resolvedToken = useAuth ? authToken : nil
        if resolvedToken == nil {
            comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        }
        guard let url = comps.url else { throw APIError.invalidURL(endpoint) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue(InnerTubeClients.Web.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(InnerTubeClients.Web.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        if let token = resolvedToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let authLabel = resolvedToken != nil ? "yes" : "no"
        Log.innerTube.notice("POST /\(endpoint) [WEB] auth=\(authLabel)")
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            Log.innerTube.error("❌ HTTP \(statusCode) for /\(endpoint)")
            throw APIError.httpError(statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Log.innerTube.error("❌ Non-dictionary JSON root for /\(endpoint)")
            throw APIError.decodingError("Root JSON is not a dictionary")
        }
        if let error = json["error"] as? [String: Any] {
            Log.innerTube.error("❌ API error in /\(endpoint): \(String(describing: error["message"] ?? error))")
        } else {
            let topKeys = Array(json.keys.prefix(6))
            Log.innerTube.notice("✅ /\(endpoint) HTTP \(statusCode) keys: \(topKeys)")
        }
        return json
    }

    /// Android VR (Oculus Quest) client player request on www.youtube.com.
    /// Uses the correct client headers (nameID=28) so YouTube identifies the request
    /// as an Oculus VR client. Per yt-dlp research, this client is exempt from rqh=1
    /// PO-token enforcement that affects standard Android and iOS adaptive streams.
    func postAndroidVR(body: [String: Any]) async throws -> [String: Any] {
        // yt-dlp android_vr uses the TV/Android API key (same value). nosec: published in yt-dlp.
        let vrApiKey = "AIzaSyDCU8mBbAkSfXX4txZFpEpPEBoAOUMCxkU" // gitleaks:allow
        guard var comps = URLComponents(url: baseURL.appendingPathComponent("player"),
                                        resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL("player")
        }
        comps.queryItems = [
            URLQueryItem(name: "key", value: vrApiKey),
            URLQueryItem(name: "prettyPrint", value: "false"),
        ]
        guard let url = comps.url else { throw APIError.invalidURL("player") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // yt-dlp sends Origin: https://www.youtube.com for android_vr — required to avoid
        // YouTube returning a bot-detection LOGIN_REQUIRED response.
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue(InnerTubeClients.AndroidVR.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(InnerTubeClients.AndroidVR.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(InnerTubeClients.AndroidVR.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        // Pass visitorData from previous iOS/TV responses to avoid bot-detection.
        if let vd = visitorData {
            request.setValue(vd, forHTTPHeaderField: "X-Goog-Visitor-Id")
            Log.innerTube.notice("POST /player [AndroidVR] using visitorData (len=\(vd.count))")
        } else {
            Log.innerTube.notice("POST /player [AndroidVR] — no visitorData available (may bot-detect)")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let videoId = body["videoId"] as? String ?? ""
        Log.innerTube.notice("POST /player [AndroidVR] videoId=\(videoId)")
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            Log.innerTube.error("❌ HTTP \(statusCode) for /player [AndroidVR]")
            throw APIError.httpError(statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Log.innerTube.error("❌ Non-dictionary JSON root for /player [AndroidVR]")
            throw APIError.decodingError("Root JSON is not a dictionary")
        }
        if let error = json["error"] as? [String: Any] {
            Log.innerTube.error("❌ API error in /player [AndroidVR]: \(String(describing: error["message"] ?? error))")
        } else {
            let topKeys = Array(json.keys.prefix(6))
            Log.innerTube.notice("✅ /player [AndroidVR] HTTP \(statusCode) keys: \(topKeys)")
        }
        return json
    }

    /// WEB_CREATOR (YouTube Studio) player request on www.youtube.com.
    /// Per yt-dlp documentation, this client is exempt from rqh=1 CDN enforcement —
    /// adaptive stream URLs returned do NOT require a pot= proof-of-origin token.
    /// Auth: SAPISIDHASH when available; falls back to Bearer+X-Goog-AuthUser.
    func postWebCreator(body: [String: Any]) async throws -> [String: Any] {
        guard var comps = URLComponents(url: baseURL.appendingPathComponent("player"),
                                        resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL("player")
        }
        comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = comps.url else { throw APIError.invalidURL("player") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36,gzip(gfe)", forHTTPHeaderField: "User-Agent")
        request.setValue(InnerTubeClients.WebCreator.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(InnerTubeClients.WebCreator.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        if let sid = sapisid {
            request.setValue(InnerTubeAPI.sapisidhash(sapisid: sid), forHTTPHeaderField: "Authorization")
            request.setValue("1", forHTTPHeaderField: "X-Origin")
        } else if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("0", forHTTPHeaderField: "X-Goog-AuthUser")
        }
        let authStatus: String
        if sapisid != nil { authStatus = "SAPISIDHASH" }
        else if authToken != nil { authStatus = "Bearer+AuthUser" }
        else { authStatus = "unauthenticated" }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let videoId = body["videoId"] as? String ?? ""
        Log.innerTube.notice("POST /player [WebCreator] videoId=\(videoId) auth=\(authStatus)")
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            var errSummary = ""
            if let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = j["error"] as? [String: Any] {
                let code = err["code"] ?? ""
                let msg = (err["message"] as? String ?? "").prefix(120)
                let status = err["status"] ?? ""
                errSummary = "code=\(code) status=\(status) msg=\(msg)"
            } else {
                errSummary = String(data: data.prefix(120), encoding: .utf8) ?? "(non-utf8)"
            }
            Log.innerTube.error("❌ HTTP \(statusCode) for /player [WebCreator] err=\(errSummary)")
            throw APIError.httpError(statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Log.innerTube.error("❌ Non-dictionary JSON root for /player [WebCreator]")
            throw APIError.decodingError("Root JSON is not a dictionary")
        }
        if let error = json["error"] as? [String: Any] {
            Log.innerTube.error("❌ API error in /player [WebCreator]: \(String(describing: error["message"] ?? error))")
        } else {
            let topKeys = Array(json.keys.prefix(6))
            Log.innerTube.notice("✅ /player [WebCreator] HTTP \(statusCode) keys: \(topKeys)")
        }
        return json
    }

    /// WEB_EMBEDDED_PLAYER (nameID=56) player request on www.youtube.com.
    /// Replaced the deprecated TVHTML5_SIMPLY_EMBEDDED_PLAYER (nameID=85) which YouTube
    /// blocked in 2026. Uses client headers matching nameID=56 / version from InnerTubeClients.
    func postTVEmbedded(body: [String: Any]) async throws -> [String: Any] {
        guard var comps = URLComponents(url: baseURL.appendingPathComponent("player"),
                                        resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL("player")
        }
        comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = comps.url else { throw APIError.invalidURL("player") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        // WEB_EMBEDDED_PLAYER is a web client — use a browser UA so YouTube treats the
        // request as a legitimate iframe embed and returns hlsManifestUrl in streamingData.
        request.setValue(InnerTubeClients.Web.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(InnerTubeClients.TVEmbedded.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(InnerTubeClients.TVEmbedded.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let videoId = body["videoId"] as? String ?? ""
        Log.innerTube.notice("POST /player [TVEmbedded] videoId=\(videoId)")
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            Log.innerTube.error("❌ HTTP \(statusCode) for /player [TVEmbedded]")
            throw APIError.httpError(statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Log.innerTube.error("❌ Non-dictionary JSON root for /player [TVEmbedded]")
            throw APIError.decodingError("Root JSON is not a dictionary")
        }
        if let error = json["error"] as? [String: Any] {
            Log.innerTube.error("❌ API error in /player [TVEmbedded]: \(String(describing: error["message"] ?? error))")
        } else {
            let topKeys = Array(json.keys.prefix(6))
            Log.innerTube.notice("✅ /player [TVEmbedded] HTTP \(statusCode) keys: \(topKeys)")
        }
        return json
    }

    /// MWEB (m.youtube.com, iPad Safari, nameID=2) player request on www.youtube.com.
    /// Per yt-dlp does not require a PO Token for HLS and has no embed restriction.
    func postMWEB(body: [String: Any]) async throws -> [String: Any] {
        guard var comps = URLComponents(url: baseURL.appendingPathComponent("player"),
                                        resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL("player")
        }
        comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = comps.url else { throw APIError.invalidURL("player") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue(InnerTubeClients.MWEB.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(InnerTubeClients.MWEB.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(InnerTubeClients.MWEB.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let videoId = body["videoId"] as? String ?? ""
        Log.innerTube.notice("POST /player [MWEB] videoId=\(videoId)")
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            Log.innerTube.error("❌ HTTP \(statusCode) for /player [MWEB]")
            throw APIError.httpError(statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Log.innerTube.error("❌ Non-dictionary JSON root for /player [MWEB]")
            throw APIError.decodingError("Root JSON is not a dictionary")
        }
        if let error = json["error"] as? [String: Any] {
            Log.innerTube.error("❌ API error in /player [MWEB]: \(String(describing: error["message"] ?? error))")
        } else {
            let topKeys = Array(json.keys.prefix(6))
            Log.innerTube.notice("✅ /player [MWEB] HTTP \(statusCode) keys: \(topKeys)")
        }
        return json
    }

    /// WEB client with macOS Safari UA — mirrors yt-dlp's `web_safari` client (nameID=1).
    /// Unlike the Chrome-UA WEB client, this returns `hlsManifestUrl` for non-embeddable videos.
    func postWebSafari(
        body: [String: Any], visitorIdOverride: String? = nil, allowBearerFallback: Bool = false
    ) async throws -> [String: Any] {
        guard var comps = URLComponents(url: baseURL.appendingPathComponent("player"),
                                        resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL("player")
        }
        comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = comps.url else { throw APIError.invalidURL("player") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue(InnerTubeClients.WebSafari.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(InnerTubeClients.WebSafari.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(InnerTubeClients.WebSafari.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        // fix9: SAPISID auth for postWebSafari.
        // When SAPISID is available (recovered from WKWebView propagated cookies), use
        // SAPISIDHASH auth so YouTube treats the request as authenticated — returning rqh=0
        // adaptive stream URLs that the CDN serves without pot= enforcement.
        // Without auth, YouTube returns rqh=1 URLs that require pot= and still 403 on the
        // CDN probe when match=false (webVD ≠ apiVD). With SAPISID, Path A wins reliably.
        // Bearer is opt-in: for playback, www.youtube.com is documented throughout this file as
        // rejecting the TV device-code Bearer token with HTTP 400, and PR #129 removed an
        // unconditional Bearer fallback here while fixing playback. Only the tracking-URL fetch
        // opts in, where a 400 just means no account-bound URLs rather than broken playback.
        let authStatus: String
        if let sid = sapisid {
            request.setValue(InnerTubeAPI.sapisidhash(sapisid: sid), forHTTPHeaderField: "Authorization")
            request.setValue("1", forHTTPHeaderField: "X-Origin")
            authStatus = "SAPISIDHASH"
        } else if allowBearerFallback, let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("0", forHTTPHeaderField: "X-Goog-AuthUser")
            authStatus = "Bearer"
        } else {
            authStatus = "unauthenticated"
        }
        // Use the override visitor ID (from WKWebView guide call) when provided, so the
        // X-Goog-Visitor-Id header matches the context.client.visitorData in the body and
        // the minted BotGuard pot= token identifier — required for CDN URL validation.
        let effectiveVD = visitorIdOverride ?? visitorData
        if let vd = effectiveVD {
            request.setValue(vd, forHTTPHeaderField: "X-Goog-Visitor-Id")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let videoId = body["videoId"] as? String ?? ""
        Log.innerTube.notice("POST /player [WebSafari] videoId=\(videoId) auth=\(authStatus)")
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            Log.innerTube.error("❌ HTTP \(statusCode) for /player [WebSafari]")
            throw APIError.httpError(statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Log.innerTube.error("❌ Non-dictionary JSON root for /player [WebSafari]")
            throw APIError.decodingError("Root JSON is not a dictionary")
        }
        if let error = json["error"] as? [String: Any] {
            Log.innerTube.error("❌ API error in /player [WebSafari]: \(String(describing: error["message"] ?? error))")
        } else {
            let topKeys = Array(json.keys.prefix(6))
            Log.innerTube.notice("✅ /player [WebSafari] HTTP \(statusCode) keys: \(topKeys)")
        }
        return json
    }

    /// WEB client (nameID=1) on www.youtube.com authenticated with Bearer + X-Goog-AuthUser:0.
    /// Mirrors yt-dlp's `web` OAuth client pattern — for signed-in users YouTube returns
    /// adaptive stream URLs without `rqh=1`, so no PO token is needed.
    /// Throws `APIError.notAuthenticated` when no `authToken` is present.
    func postWebAuthenticated(body: [String: Any]) async throws -> [String: Any] {
        guard let token = authToken else { throw APIError.notAuthenticated }
        guard var comps = URLComponents(url: baseURL.appendingPathComponent("player"),
                                        resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL("player")
        }
        comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = comps.url else { throw APIError.invalidURL("player") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue(InnerTubeClients.Web.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(InnerTubeClients.Web.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(InnerTubeClients.Web.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("0", forHTTPHeaderField: "X-Goog-AuthUser")
        if let vd = visitorData {
            request.setValue(vd, forHTTPHeaderField: "X-Goog-Visitor-Id")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let videoId = body["videoId"] as? String ?? ""
        Log.innerTube.notice("POST /player [WebAuth] videoId=\(videoId)")
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            var errSummary = ""
            if let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = j["error"] as? [String: Any] {
                let code = err["code"] ?? ""
                let msg = (err["message"] as? String ?? "").prefix(120)
                let status = err["status"] ?? ""
                errSummary = "code=\(code) status=\(status) msg=\(msg)"
            } else {
                errSummary = String(data: data.prefix(120), encoding: .utf8) ?? "(non-utf8)"
            }
            Log.innerTube.error("❌ HTTP \(statusCode) for /player [WebAuth] err=\(errSummary)")
            throw APIError.httpError(statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Log.innerTube.error("❌ Non-dictionary JSON root for /player [WebAuth]")
            throw APIError.decodingError("Root JSON is not a dictionary")
        }
        if let error = json["error"] as? [String: Any] {
            Log.innerTube.error("❌ API error in /player [WebAuth]: \(String(describing: error["message"] ?? error))")
        } else {
            let topKeys = Array(json.keys.prefix(6))
            Log.innerTube.notice("✅ /player [WebAuth] HTTP \(statusCode) keys: \(topKeys)")
        }
        return json
    }

    /// Unauthenticated TVHTML5 browse on www.youtube.com.
    /// FE* category browse IDs (FEgaming, FEshorts, FEmusic, …) require the TVHTML5
    /// client format but return 400 on youtubei.googleapis.com without a valid auth token.
    /// Posting to www.youtube.com with TV client headers resolves this.
    func postTVCategory(endpoint: String, body: [String: Any]) async throws -> [String: Any] {
        guard var comps = URLComponents(url: baseURL.appendingPathComponent(endpoint),
                                        resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL(endpoint)
        }
        comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = comps.url else { throw APIError.invalidURL(endpoint) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue(InnerTubeClients.TV.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(InnerTubeClients.TV.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        Log.innerTube.notice("POST /\(endpoint) [TV-category]")
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            Log.innerTube.error("❌ HTTP \(statusCode) for /\(endpoint) [TV-category]")
            throw APIError.httpError(statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Log.innerTube.error("❌ Non-dictionary JSON root for /\(endpoint) [TV-category]")
            throw APIError.decodingError("Root JSON is not a dictionary")
        }
        if let error = json["error"] as? [String: Any] {
            Log.innerTube.error("❌ API error in /\(endpoint) [TV-category]: \(String(describing: error["message"] ?? error))")
        } else {
            let topKeys = Array(json.keys.prefix(6))
            Log.innerTube.notice("✅ /\(endpoint) [TV-category] HTTP \(statusCode) keys: \(topKeys)")
        }
        return json
    }

    func postTV(
        endpoint: String,
        body: [String: Any],
        useAuth: Bool = true,
        explicitBearerToken: String? = nil
    ) async throws -> [String: Any] {
        guard var comps = URLComponents(url: playerBaseURL.appendingPathComponent(endpoint),
                                        resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL(endpoint)
        }
        let resolvedToken = explicitBearerToken ?? (useAuth ? authToken : nil)
        let shouldAuthenticate = resolvedToken != nil
        if !shouldAuthenticate {
            comps.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        }
        guard let url = comps.url else { throw APIError.invalidURL(endpoint) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(InnerTubeClients.TV.nameID, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(InnerTubeClients.TV.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        if let token = resolvedToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let authLabel = shouldAuthenticate ? "yes" : "no"
        Log.innerTube.notice("POST /\(endpoint) [TV] auth=\(authLabel)")
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            Log.innerTube.error("❌ HTTP \(statusCode) for /\(endpoint) [TV]")
            throw APIError.httpError(statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Log.innerTube.error("❌ Non-dictionary JSON root for /\(endpoint) [TV]")
            throw APIError.decodingError("Root JSON is not a dictionary")
        }
        if let error = json["error"] as? [String: Any] {
            Log.innerTube.error("❌ API error in /\(endpoint) [TV]: \(String(describing: error["message"] ?? error))")
        } else {
            let topKeys = Array(json.keys.prefix(6))
            Log.innerTube.notice("✅ /\(endpoint) [TV] HTTP \(statusCode) keys: \(topKeys)")
        }
        return json
    }

}

// MARK: - SAPISIDHASH helper

extension InnerTubeAPI {

    /// Computes the SAPISIDHASH Authorization header value for www.youtube.com web-client requests.
    ///
    /// Format: `SAPISIDHASH {timestamp}_{sha1("{timestamp} {SAPISID} {origin}")}`
    static func sapisidhash(
        sapisid: String,
        origin: String = "https://www.youtube.com"
    ) -> String {
        let ts = Int(Date().timeIntervalSince1970)
        let payload = "\(ts) \(sapisid) \(origin)"
        let digest = Insecure.SHA1.hash(data: Data(payload.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "SAPISIDHASH \(ts)_\(hex)"
    }
}
