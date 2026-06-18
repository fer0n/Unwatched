/// YTHLSProxyLoader.swift
/// Proxies HLS playlist and segment requests through URLSession so the correct
/// User-Agent (desktop Safari) is sent to manifest.googlevideo.com.
/// AVURLAssetHTTPHeaderFieldsKey does not reliably propagate User-Agent through
/// CoreMedia's internal HLS stack — this resource loader fills that gap.

#if canImport(WebKit)
import AVFoundation
import Foundation
import os.log

private let proxyScheme = "ytwebhls"
private let proxyLog = Logger(subsystem: appSubsystem, category: "HLSProxy")

// MARK: - URL scheme helpers

extension URL {
    /// Converts an https:// URL to ytwebhls:// for routing through the proxy.
    var proxyURL: URL? {
        guard var c = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
        c.scheme = proxyScheme
        return c.url
    }
    /// Converts a ytwebhls:// URL back to https:// for the actual network request.
    var realURL: URL? {
        guard scheme == proxyScheme,
              var c = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
        c.scheme = "https"
        return c.url
    }
}

// MARK: - YTHLSProxyLoader

/// `AVAssetResourceLoaderDelegate` that forwards every HLS request through
/// `URLSession.shared` with a desktop-Safari User-Agent header.
/// Holds a strong reference to itself via the asset to keep it alive.
final class YTHLSProxyLoader: NSObject, AVAssetResourceLoaderDelegate, @unchecked Sendable {
    let ua: String
    /// When non-nil, the proxy rewrites all `/n/{unsolved}/` occurrences to `/n/{solved}/`
    /// in HLS playlist text before serving it to AVPlayer. This makes segment URLs carry
    /// the solved n-challenge so the video CDN accepts them (HTTP 200 instead of 403).
    let nSolver: (unsolved: String, solved: String)?
    /// All cookies extracted from WKWebView's httpCookieStore at proxy creation time.
    /// Includes both youtube.com and googlevideo.com cookies. For rqh=1-enforced content,
    /// googlevideo.com cookies are required to authenticate CDN segment requests.
    let webViewCookies: [HTTPCookie]
    /// When non-nil, the proxy filters the master manifest to only serve #EXT-X-STREAM-INF
    /// variants whose YT-EXT-AUDIO-CONTENT-ID matches this value (dubbed language selection).
    /// When nil, only variants WITHOUT YT-EXT-AUDIO-CONTENT-ID are served (original audio).
    let selectedLanguageContentID: String?
    /// When non-nil, the proxy:
    ///  - Rewrites #EXT-X-STREAM-INF variant URIs in the master manifest to the proxy scheme
    ///    so that variant quality playlists are intercepted and their segment URLs patched.
    ///  - Appends `?pot=<token>` to every segment URL in variant playlists so that
    ///    AVFoundation's native CDN fetch includes the BotGuard proof-of-origin token.
    ///    Segments remain https:// (not proxied); only the URL query params are enriched.
    /// This unlocks rqh=1-enforced HLS segments served via the WEB client (web_safari)
    /// when a valid minted BotGuard token is available but spc= is not.
    let poToken: String?
    private let lock = NSLock()
    private var activeTasks: [ObjectIdentifier: URLSessionDataTask] = [:]

    init(ua: String, nSolver: (unsolved: String, solved: String)? = nil,
         webViewCookies: [HTTPCookie] = [], selectedLanguageContentID: String? = nil,
         poToken: String? = nil) {
        self.ua = ua
        self.nSolver = nSolver
        self.webViewCookies = webViewCookies
        self.selectedLanguageContentID = selectedLanguageContentID
        self.poToken = poToken
    }

    // MARK: AVAssetResourceLoaderDelegate

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard let proxyURL = loadingRequest.request.url,
              let realURL   = proxyURL.realURL else {
            proxyLog.error("[HLSProxy] unexpected scheme: \(loadingRequest.request.url?.scheme ?? "nil")")
            return false
        }

        var request = URLRequest(url: realURL, timeoutInterval: 30)
        request.setValue(ua, forHTTPHeaderField: "User-Agent")
        // All googlevideo.com requests (both manifest and segment CDN) need Origin/Referer
        // matching youtube.com so the CDN accepts the cross-origin request.
        if let host = realURL.host, host.contains("googlevideo.com") {
            request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
            request.setValue("https://www.youtube.com/", forHTTPHeaderField: "Referer")
        }
        // For googlevideo.com segment CDN requests, attach all cookies extracted from the
        // WKWebView at proxy creation time (webViewCookies). This includes both youtube.com
        // and googlevideo.com cookies needed for rqh=1-enforced content.
        // Falls back to HTTPCookieStorage.shared when webViewCookies was not provided.
        if let host = realURL.host, host.contains("googlevideo.com") {
            let cookies: [HTTPCookie] = webViewCookies.isEmpty
                ? (HTTPCookieStorage.shared.cookies(for: URL(string: "https://www.youtube.com")!) ?? [])
                : webViewCookies
            if !cookies.isEmpty {
                let cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
                let gvCount = cookies.filter { $0.domain.contains("googlevideo") }.count
                proxyLog.notice("[HLSProxy] attaching \(cookies.count) cookies (\(gvCount) googlevideo) to segment request")
            }
        }
        proxyLog.notice("[HLSProxy] GET \(realURL.absoluteString.prefix(200))")

        let key = ObjectIdentifier(loadingRequest)
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            defer {
                self.lock.lock()
                self.activeTasks.removeValue(forKey: key)
                self.lock.unlock()
            }

            if let error {
                proxyLog.error("[HLSProxy] URLSession error: \(error.localizedDescription)")
                loadingRequest.finishLoading(with: error)
                return
            }

            guard let httpResp = response as? HTTPURLResponse, let data else {
                loadingRequest.finishLoading(with: NSError(domain: "YTHLSProxy", code: -1))
                return
            }

            proxyLog.notice("[HLSProxy] \(realURL.lastPathComponent) HTTP=\(httpResp.statusCode) bytes=\(data.count)")
            // Log response body for 4xx/5xx to diagnose CDN rejections (n-challenge, auth, etc.)
            if httpResp.statusCode >= 400 {
                let errBody = String(data: data.prefix(300), encoding: .utf8) ?? "<binary>"
                proxyLog.error("[HLSProxy] ERROR body: \(errBody as NSString)")
            }

            // Determine whether this resource is an HLS playlist.
            // IMPORTANT: YouTube segment URLs embed "/playlist/index.m3u8/" in their path
            // (e.g. ".../playlist/index.m3u8/govp/.../file/seg.ts"), so a simple path.contains
            // check erroneously treats segments as playlists — corrupting binary TS data.
            // We use the MIME type first, then fall back to whether the path *ends* with m3u8
            // (last path component), which correctly excludes segment URLs.
            let mimeTypeLower = (httpResp.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
            let isPlaylist = mimeTypeLower.contains("mpegurl")
                          || realURL.pathExtension.lowercased() == "m3u8"
                          || realURL.lastPathComponent.lowercased() == "index.m3u8"
            proxyLog.notice("[HLSProxy] Content-Type=\(httpResp.value(forHTTPHeaderField: "Content-Type") ?? "nil") isPlaylist=\(isPlaylist)")

            // For HLS playlists, rewrite segment/sub-playlist URIs to our proxy scheme.
            var responseData = data
            if isPlaylist {
                if let text = String(data: data, encoding: .utf8) {
                    let rewritten = self.rewritePlaylist(text, baseURL: realURL)
                    responseData = rewritten.data(using: .utf8) ?? data
                }
            }

            // Populate content information AFTER computing responseData so contentLength is accurate.
            // AVAssetResourceLoadingContentInformationRequest.contentType requires a UTI string
            // (Uniform Type Identifier), NOT a raw MIME type. Supplying a MIME type causes
            // AVFoundation to misidentify the resource and fail with CoreMediaErrorDomain -12881.
            if let infoReq = loadingRequest.contentInformationRequest {
                let uti: String
                if isPlaylist {
                    uti = "public.m3u-playlist"
                } else if mimeTypeLower.contains("mp4") || mimeTypeLower.contains("mpeg-4") {
                    // fMP4 segments (YouTube uses video/mp4 for fragmented MP4 HLS)
                    uti = "public.mpeg-4"
                } else {
                    // Default: MPEG-2 TS (video/MP2T)
                    uti = "public.mpeg-2-transport-stream"
                }
                infoReq.contentType = uti
                infoReq.contentLength = Int64(responseData.count)
                infoReq.isByteRangeAccessSupported = false
                proxyLog.notice("[HLSProxy] contentInfo: UTI=\(uti) length=\(responseData.count)")
            }

            loadingRequest.dataRequest?.respond(with: responseData)
            loadingRequest.finishLoading()
        }

        lock.lock()
        activeTasks[key] = task
        lock.unlock()
        task.resume()
        return true
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        didCancel loadingRequest: AVAssetResourceLoadingRequest
    ) {
        let key = ObjectIdentifier(loadingRequest)
        lock.lock()
        let task = activeTasks.removeValue(forKey: key)
        lock.unlock()
        task?.cancel()
    }

    // MARK: Playlist rewriting

    /// Rewrites all URI lines in an HLS M3U8 to use our proxy scheme so that
    /// AVPlayer routes segment/sub-playlist requests through this delegate.
    /// Also rewrites the n-challenge in all segment/playlist URLs if `nSolver` is set.
    private func rewritePlaylist(_ m3u8: String, baseURL: URL) -> String {
        // Step 1: Replace unsolved n-challenge across the entire playlist text.
        // The n-value is identical in all URLs for a given session, so a global
        // string replacement is safe and avoids per-URL regex overhead.
        var text = m3u8
        if let (unsolved, solved) = nSolver, !unsolved.isEmpty, unsolved != solved {
            let oldN = "/n/\(unsolved)/"
            let newN = "/n/\(solved)/"
            let before = text
            text = text.replacingOccurrences(of: oldN, with: newN)
            if text != before {
                proxyLog.notice("[HLSProxy] n-challenge rewritten: \(unsolved as NSString) -> \(solved as NSString)")
            } else {
                proxyLog.notice("[HLSProxy] n-challenge NOT found in playlist (unsolved=\(unsolved as NSString))")
            }
        }

        // Step 1.5: Synthesize missing #EXTINF tags for YouTube's non-standard per-quality
        // playlists. YouTube sometimes returns a playlist that starts with #EXTM3U followed
        // directly by segment URLs (no #EXTINF duration tags). AVPlayer rejects such playlists
        // with CoreMediaErrorDomain -12881. We reconstruct a conformant HLS playlist by
        // extracting the segment duration from the /len/{ms}/ path component of each URL.
        //
        // Guard: master manifests also lack #EXTINF — they use #EXT-X-STREAM-INF instead.
        // Applying this synthesis to a master manifest converts variant/audio-group URLs into
        // fake segments → CoreMediaErrorDomain -12642. Skip synthesis for any master manifest.
        let isMasterManifest = text.contains("#EXT-X-STREAM-INF") || text.contains("#EXT-X-MEDIA:")
        if !text.contains("#EXTINF") && !isMasterManifest {
            let rawLines = text.components(separatedBy: "\n")
            var fixedLines: [String] = []
            var maxDurationSecs: Double = 4.0
            var segmentCount = 0
            var hasEndlist = false

            for rawLine in rawLines {
                let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
                if trimmed == "#EXTM3U" {
                    fixedLines.append(rawLine)
                    // Inject required header tags immediately after #EXTM3U.
                    // We'll fill in EXT-X-TARGETDURATION after the first pass.
                    fixedLines.append("__TARGETDURATION_PLACEHOLDER__")
                    fixedLines.append("#EXT-X-VERSION:3")
                    fixedLines.append("#EXT-X-MEDIA-SEQUENCE:0")
                    fixedLines.append("#EXT-X-ALLOW-CACHE:NO")
                } else if trimmed.isEmpty || trimmed.hasPrefix("#") {
                    if trimmed == "#EXT-X-ENDLIST" { hasEndlist = true }
                    fixedLines.append(rawLine)
                } else {
                    // URL line — extract segment duration from /len/{ms}/ path component.
                    var durationSecs: Double = 4.0
                    if let lenStart = trimmed.range(of: "/len/") {
                        let after = trimmed[lenStart.upperBound...]
                        if let lenEnd = after.firstIndex(of: "/") {
                            let msString = String(after[after.startIndex..<lenEnd])
                            if let ms = Double(msString), ms > 0 {
                                durationSecs = ms / 1000.0
                            }
                        }
                    }
                    maxDurationSecs = max(maxDurationSecs, durationSecs)
                    fixedLines.append("#EXTINF:\(String(format: "%.6f", durationSecs)),")
                    fixedLines.append(rawLine)
                    segmentCount += 1
                }
            }

            if !hasEndlist {
                fixedLines.append("#EXT-X-ENDLIST")
            }

            let targetDurationTag = "#EXT-X-TARGETDURATION:\(Int(ceil(maxDurationSecs)))"
            let result = fixedLines
                .map { $0 == "__TARGETDURATION_PLACEHOLDER__" ? targetDurationTag : $0 }
                .joined(separator: "\n")
            text = result
            proxyLog.notice("[HLSProxy] synthesized #EXTINF for \(segmentCount) segments; targetDuration=\(Int(ceil(maxDurationSecs)))s")
        }

        // Step 2: For master manifests, rewrite #EXT-X-MEDIA URI attributes so that audio
        // rendition playlists are fetched through this proxy with the correct desktop-Safari
        // User-Agent. Without proxying, AVPlayer fetches them natively with an iOS UA, which
        // manifest.googlevideo.com rejects → loadMediaSelectionGroup returns nil/empty →
        // availableAudioTracks stays empty → audio language selector never appears.
        //
        // When poToken is set (BotGuard WEB client HLS path), also rewrite #EXT-X-STREAM-INF
        // variant URIs to the proxy scheme. This lets the proxy intercept the per-quality variant
        // playlists and append ?pot=<token> to every segment URL within them (Step 4). Segment
        // binary data remains https:// (never proxied) to avoid CoreMediaErrorDomain -12881.
        // Without this, AVPlayer fetches variant playlists natively and then fetches segments
        // without pot=, which YouTube CDN rejects with 403 (rqh=1 enforcement).
        //
        // Only #EXT-X-MEDIA playlist URIs are rewritten normally. Segment URLs inside rendition
        // playlists remain https:// and are served natively by AVPlayer (binary media data
        // cannot be routed through AVAssetResourceLoaderDelegate without -12881).
        // fix22: #EXT-X-STREAM-INF variant URIs are now ALWAYS rewritten to the proxy scheme
        // so that AVFoundation fetches variant playlists via the proxy with desktop-Safari UA
        // regardless of whether a poToken is available. When poToken is also set, Step 4
        // additionally injects pot= into every segment URL within those variant playlists.
        if isMasterManifest {
            let lines = text.components(separatedBy: "\n")
            // Diagnostic: log first #EXT-X-MEDIA:TYPE=AUDIO line to verify URI quote format.
            if let sample = lines.first(where: { $0.hasPrefix("#EXT-X-MEDIA:") && $0.contains("TYPE=AUDIO") }) {
                proxyLog.notice("[HLSProxy] first AUDIO EXT-X-MEDIA sample: \(sample.prefix(300))")
            }
            var audioGroupCount = 0
            var variantCount = 0
            let rewrittenLines: [String] = lines.map { line in
                guard line.hasPrefix("#EXT-X-MEDIA:") || !line.hasPrefix("#") else { return line }
                // Rewrite #EXT-X-MEDIA playlist URIs to proxy scheme (audio renditions).
                if line.hasPrefix("#EXT-X-MEDIA:") {
                    if line.contains("URI=\"https://") {
                        audioGroupCount += 1
                        return line.replacingOccurrences(of: "URI=\"https://", with: "URI=\"\(proxyScheme)://")
                    } else if line.contains("URI=https://") {
                        audioGroupCount += 1
                        return line.replacingOccurrences(of: "URI=https://", with: "URI=\(proxyScheme)://")
                    }
                    return line
                }
                // fix22: Always rewrite #EXT-X-STREAM-INF variant URLs to proxy scheme so that
                // AVFoundation fetches variant playlists via the proxy with desktop-Safari UA.
                // Without this, AVFoundation uses iOS UA and manifest.googlevideo.com rejects
                // the request with 403 when no poToken is available. When poToken is set,
                // Step 4 additionally injects pot= into segment URLs within the variant playlist.
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty && trimmed.hasPrefix("https://") {
                    variantCount += 1
                    return trimmed.replacingOccurrences(of: "https://", with: "\(proxyScheme)://")
                }
                return line
            }
            if audioGroupCount > 0 || variantCount > 0 {
                proxyLog.notice("[HLSProxy] rewrote \(audioGroupCount) #EXT-X-MEDIA + \(variantCount) variant URIs to \(proxyScheme)://")
                text = rewrittenLines.joined(separator: "\n")
            } else {
                let extMediaCount = lines.filter { $0.hasPrefix("#EXT-X-MEDIA:") }.count
                proxyLog.notice("[HLSProxy] 0 #EXT-X-MEDIA URIs rewritten; total EXT-X-MEDIA lines=\(extMediaCount); checking YT-EXT-AUDIO-CONTENT-ID variants")
            }

            // Step 3: Filter #EXT-X-STREAM-INF variants by selected dubbed-audio language.
            // IMPORTANT: use the CURRENT `text` (after Step 2 URL rewrites), not the original
            // `lines` variable. If we iterated `lines` here, Step 2's ytwebhls:// rewrites would
            // be overwritten with the original https:// URLs — AVFoundation would bypass the proxy.
            let currentLines = text.components(separatedBy: "\n")
            let hasVariants = currentLines.contains { $0.trimmingCharacters(in: .whitespaces).hasPrefix("#EXT-X-STREAM-INF:") }
            if hasVariants {
                let selectedLang = selectedLanguageContentID
                var filteredLines: [String] = []
                var pendingKeep: Bool? = nil
                var keptVariantCount = 0

                for line in currentLines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("#EXT-X-STREAM-INF:") {
                        let hasContentID = trimmed.contains("YT-EXT-AUDIO-CONTENT-ID=")
                        if let lang = selectedLang {
                            // Keep only the variant matching the selected language
                            pendingKeep = trimmed.contains("YT-EXT-AUDIO-CONTENT-ID=\"\(lang)\"")
                                       || trimmed.contains("YT-EXT-AUDIO-CONTENT-ID=\(lang)")
                        } else {
                            // No language selected → original (no content ID)
                            pendingKeep = !hasContentID
                        }
                        if pendingKeep == true { filteredLines.append(line) }
                    } else if let keep = pendingKeep, !trimmed.isEmpty, !trimmed.hasPrefix("#") {
                        // URL line immediately following a #EXT-X-STREAM-INF
                        if keep {
                            filteredLines.append(line)
                            keptVariantCount += 1
                        }
                        pendingKeep = nil
                    } else {
                        filteredLines.append(line)
                    }
                }

                let langDisplay = selectedLang ?? "original"
                if keptVariantCount > 0 {
                    proxyLog.notice("[HLSProxy] language filter: lang=\(langDisplay) kept \(keptVariantCount) variant(s)")
                    text = filteredLines.joined(separator: "\n")
                } else {
                    // No variants matched — serve unfiltered manifest so AVPlayer can always load.
                    proxyLog.notice("[HLSProxy] language filter: lang=\(langDisplay) matched 0 variants — serving unfiltered manifest")
                }
            }
        }

        // Step 4: For variant quality playlists (non-master), inject pot= into segment URLs.
        // When poToken is set, AVFoundation routes variant playlist requests through this proxy
        // (because the master manifest rewriting in Step 2 converted variant URLs to proxy scheme).
        // Here, we append ?pot=<token> to every segment URL in the variant playlist.
        // NOTE: segments must remain https:// — AVAssetResourceLoaderDelegate cannot serve binary
        // segment data (causes -12881 / -12753 / -12860 errors). AVPlayer fetches https:// segments
        // natively; the pot= token in the URL query string authenticates the CDN request directly.
        // When pot=nil, segments remain https:// unchanged — the CDN either accepts them with a warm
        // session or falls back to another path. fix22a already proxies variant playlists regardless
        // of pot=, so the UA-rejection issue is limited to individual segment fetches.
        if !isMasterManifest, let pot = poToken {
            let lines = text.components(separatedBy: "\n")
            var injectedCount = 0
            let patchedLines: [String] = lines.map { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return line }
                // Segment URL: append pot= and keep as https:// for native AVPlayer fetch.
                // CDN validates rqh=1 segment auth via pot= query param (no proxy needed).
                let sep = trimmed.contains("?") ? "&" : "?"
                injectedCount += 1
                return trimmed + "\(sep)pot=\(pot)"
            }
            if injectedCount > 0 {
                proxyLog.notice("[HLSProxy] pot= injected into \(injectedCount) segment URL(s) in variant playlist (https:// native)")
                text = patchedLines.joined(separator: "\n")
            }
        }

        return text
    }
}
#endif
