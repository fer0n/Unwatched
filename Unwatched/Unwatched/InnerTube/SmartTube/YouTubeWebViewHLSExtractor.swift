#if canImport(WebKit)
import WebKit
import JavaScriptCore
import os

private let extractLog = Logger(subsystem: appSubsystem, category: "WebViewHLS")

/// Extracts a YouTube HLS manifest URL by loading the YouTube watch page in a hidden
/// WKWebView and intercepting the YouTube JavaScript player's internal `youtubei/v1/player`
/// network call.
///
/// **Why this works:**
/// YouTube generates HLS manifest URLs with `spc=` (proof-of-context) tokens only when the
/// request originates from a real browser JavaScript execution context. The `spc=` token is
/// computed by the YouTube player JS and makes HLS segment URLs work without `rqh=1` CDN
/// restrictions. Raw InnerTube API calls (even with Bearer auth) cannot generate `spc=` because
/// they lack the JavaScript execution context that YouTube's server verifies.
///
/// By running YouTube's JS player in WKWebView, the player computes `spc=` and includes it in
/// its internal `youtubei/v1/player` call. We intercept that response using JavaScript
/// XHR/fetch hooks and forward the `hlsManifestUrl` to Swift via `WKScriptMessageHandler`.
///
/// This approach works on both iOS Simulator and real device without any external tools.
@MainActor
final class YouTubeWebViewHLSExtractor: NSObject {

    static let shared = YouTubeWebViewHLSExtractor()

    private var webView: WKWebView?
    private var continuation: CheckedContinuation<URL?, Never>?
    private var timeoutTask: Task<Void, Never>?
    /// Incremented each time `extractHLSURL` starts a new extraction. Timeout tasks
    /// capture their generation at creation time and bail out if it has changed,
    /// preventing a cancelled previous-extraction timeout from firing on the current
    /// extraction's continuation (ABA problem with the `continuation != nil` guard).
    private var extractionGeneration: Int = 0
    /// The video ID currently being extracted, set at the start of `extractHLSURL` and
    /// cleared in `finish`. Allows callers to detect a same-video in-flight extraction
    /// and await it via `awaitCurrentExtraction()` instead of cancelling it.
    private(set) var currentExtractionVideoId: String? = nil
    /// After `extractHLSURL` completes, holds the n-challenge mapping solved in-JS.
    /// `nil` when the URL had no `/n/` or the solver wasn't available.
    private(set) var extractedNSolver: (unsolved: String, solved: String)?
    /// The pot= token extracted from the YouTube player's /player API request body,
    /// set alongside `extractedNSolver` when the JS interceptor finds one in
    /// `serviceIntegrityDimensions.poToken`. Nil when the player made no BotGuard call.
    private(set) var extractedPoToken: String?
    /// Additional continuations registered via `awaitCurrentExtraction()`. When `finish()`
    /// fires, all extra continuations receive the same URL result as the primary continuation.
    private var extraContinuations: [CheckedContinuation<URL?, Never>] = []
    /// The last task created by `serialExtract()`. Each new serialExtract call chains onto
    /// this task, ensuring strict sequential execution of serial extractions.
    private var pendingSerialTask: Task<URL?, Never>? = nil
    /// Epoch counter incremented by `priorityExtract` on every user-initiated load.
    /// A `serialExtract` task that wakes up after waiting for its predecessor will
    /// compare its captured epoch with the current epoch: if they differ, a priority
    /// extract has taken over and the serial task must await `pendingSerialTask`
    /// (the priority task) rather than call `extractHLSURL` and cancel it.
    private var serialTaskEpoch: Int = 0
    /// The videoId passed to the most recent `priorityExtract` call.
    /// Used by `serialExtract`'s stale-epoch branch to decide whether the priority
    /// task's URL is safe to return: if the priority task was for a *different* video,
    /// returning its URL would poison the caller's cache entry with the wrong stream.
    private var pendingSerialTaskVideoId: String? = nil

    // MARK: - Public API

    /// Cancels any in-progress extraction and cleans up the hidden WKWebView.
    func cancel() {
        finish(url: Optional<URL>.none)
    }

    /// Loads the YouTube watch page for `videoId` in a hidden WKWebView, waits for the
    /// YouTube JS player to make its internal `youtubei/v1/player` call, and returns
    /// the `hlsManifestUrl` from that response.
    ///
    /// - Parameter videoId: The YouTube video ID.
    /// - Parameter timeoutSeconds: How long to wait before giving up. Default 20 s.
    /// - Returns: The HLS master manifest URL (may include `spc=`), or `nil` on failure/timeout.
    func extractHLSURL(videoId: String, timeoutSeconds: Double = 40) async -> URL? {
        // Cancel any pending extraction before starting a new one.
        finish(url: nil)
        extractedNSolver = nil
        extractedPoToken = nil
        extractionGeneration &+= 1
        currentExtractionVideoId = videoId

        extractLog.notice("⚠️ [webView] starting HLS extraction for \(videoId as NSString)")

        return await withCheckedContinuation { (cont: CheckedContinuation<URL?, Never>) in
            self.continuation = cont
            let myGeneration = self.extractionGeneration

            // fix17: Reuse the persistent WKWebView if one already exists.
            // Keeping the WKWebView alive preserves the WebContent process (JIT cache)
            // and the IndexedDB/localStorage state (YouTube's BotGuard token cache)
            // across sequential extractions:
            //   1st extraction (cold): ~40 s — BotGuard WAA pipeline runs + JIT compiles
            //   2nd extraction (reuse): ~2–5 s — IndexedDB token cached, JIT warm
            //   3rd+ extraction: ~1.8 s — fully cached
            // Without reuse, each call created a fresh WKWebView / WebContent process
            // → every extraction paid the full 40 s cold cost.
            let wv: WKWebView
            if let existing = self.webView {
                wv = existing
            } else {
                let contentController = WKUserContentController()
                contentController.add(self, name: "hlsExtractor")

                // Inject the EJS AST-based n-challenge solver (lib + core) BEFORE
                // our interceptor so that `jsc` is available when solveNFromPlayerJS runs.
                if let solverScripts = Self.ejsSolverUserScripts() {
                    for script in solverScripts {
                        contentController.addUserScript(script)
                    }
                }

                // Inject the interceptor BEFORE the document loads so it can hook into
                // XMLHttpRequest and fetch before YouTube's player JS initialises.
                contentController.addUserScript(WKUserScript(
                    source: Self.interceptorJS,
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: true
                ))

                let config = WKWebViewConfiguration()
                config.userContentController = contentController
                // Allow programmatic video playback (no user gesture required) so that
                // after we get the hlsManifestUrl we can call video.play() to let the YouTube
                // player seed googlevideo.com session cookies into the WKWebView cookie store.
                config.mediaTypesRequiringUserActionForPlayback = []
                // Use .default() so existing WKWebView cookies from earlier loads are reused.
                config.websiteDataStore = .default()

                // Pre-seed the SOCS consent cookie once — it persists in the .default() store
                // across navigations so subsequent extractions don't need to re-seed it.
                let socsCookieProps: [HTTPCookiePropertyKey: Any] = [
                    .name: "SOCS",
                    .value: "CAI",
                    .domain: ".youtube.com",
                    .path: "/",
                    .secure: true,
                    .sameSitePolicy: "None",
                    .expires: Date(timeIntervalSinceNow: 365 * 24 * 3600)
                ]
                if let socsCookie = HTTPCookie(properties: socsCookieProps) {
                    config.websiteDataStore.httpCookieStore.setCookie(socsCookie)
                    extractLog.notice("[webView/HLS] SOCS consent cookie pre-seeded for .youtube.com")
                }

                // Non-zero off-screen frame so the compositor renders the video element,
                // which is required for programmatic playback on iOS.
                let newWv = WKWebView(frame: CGRect(x: -1, y: -1, width: 1, height: 1), configuration: config)
                newWv.navigationDelegate = self
                // Desktop Safari UA so YouTube serves its full player (hlsManifestUrl).
                newWv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
                    "AppleWebKit/605.1.15 (KHTML, like Gecko) " +
                    "Version/17.5 Safari/605.1.15"
                self.webView = newWv
                wv = newWv
            }

            guard let url = URL(string: "https://www.youtube.com/watch?v=\(videoId)") else {
                extractLog.error("❌ [webView] invalid videoId: \(videoId as NSString)")
                cont.resume(returning: Optional<URL>.none)
                self.continuation = nil
                return
            }

            var request = URLRequest(url: url)
            // Accept-Language: YouTube uses this to pick the page language; using en-US
            // avoids consent-wall redirects seen in some locales.
            request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
            wv.load(request)

            // Timeout safety net. Captures `myGeneration` so that if `extractHLSURL`
            // is called again (cancelling this extraction), the woken-up cancelled task
            // sees a stale generation and bails — preventing it from firing on the
            // new extraction's continuation (ABA problem).
            self.timeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                guard let self, self.extractionGeneration == myGeneration else { return }
                extractLog.notice("⚠️ [webView] timed out for \(videoId as NSString)")
                self.finish(url: Optional<URL>.none)
            }
        }
    }

    /// Awaits the result of the currently in-flight extraction without cancelling it.
    /// Multiple callers (e.g. two concurrent `race failed` handlers for the same video)
    /// each append their continuation to `extraContinuations`. When `finish()` fires,
    /// all waiters receive the same URL result.
    /// Returns `nil` if no extraction is in progress.
    func awaitCurrentExtraction() async -> URL? {
        guard continuation != nil else { return nil }
        return await withCheckedContinuation { (cont: CheckedContinuation<URL?, Never>) in
            self.extraContinuations.append(cont)
        }
    }

    /// Priority entry point for user-initiated load (earlyTask). Unlike `serialExtract`,
    /// this method does NOT wait for any in-flight background extraction. Instead it
    /// starts immediately — `extractHLSURL`'s `finish(url:nil)` cancels any active
    /// continuation, ending the background task cleanly. The new task is still registered
    /// in `pendingSerialTask` so subsequent `serialExtract` calls (from race-failed
    /// handlers) chain onto it correctly.
    ///
    /// Incrementing `serialTaskEpoch` signals every queued-but-not-yet-awoken
    /// `serialExtract` task to yield to this priority task instead of calling
    /// `extractHLSURL` and inadvertently cancelling the ongoing extraction (R14 regression:
    /// multiple VideoCardView timeout-driven tasks for `_CjIX66a9ts` woke up sequentially
    /// and each called `extractHLSURL`, cancelling `priorityExtract`'s active continuation).
    func priorityExtract(videoId: String) async -> URL? {
        serialTaskEpoch &+= 1
        pendingSerialTaskVideoId = videoId
        let newTask = Task { @MainActor [weak self] in
            guard let self else { return Optional<URL>.none }
            extractLog.notice("[webView] priorityExtract(\(videoId as NSString)): starting immediately (user tap, bypasses chain)")
            return await self.extractHLSURL(videoId: videoId)
        }
        pendingSerialTask = newTask
        return await newTask.value
    }

    /// Serial-safe entry point for the fallback path. Unlike `extractHLSURL`, this method
    /// uses a task-chain to guarantee strict sequential execution: each call awaits the
    /// previous `serialExtract` task before starting a new extraction. This prevents N
    /// concurrent `race failed` handlers (across any mix of video IDs) from all waking
    /// simultaneously and cancelling each other via `finish(url: nil)`.
    ///
    /// Pattern: each call captures the previous pending task, creates a new task that
    /// awaits the previous one, then calls `extractHLSURL`. Since all callers are on
    /// the `@MainActor`, the `pendingSerialTask` assignment is safe.
    ///
    /// Epoch check: before calling `extractHLSURL`, the task compares its captured
    /// `serialTaskEpoch` with the current value. If they differ, `priorityExtract` has
    /// advanced the epoch — this task is stale and should await `pendingSerialTask`
    /// (the priority task) instead of calling `extractHLSURL` and cancelling it.
    func serialExtract(videoId: String) async -> URL? {
        let previousTask = pendingSerialTask
        let capturedEpoch = serialTaskEpoch
        let newTask = Task { @MainActor [weak self] in
            // Wait for the previous serial extraction to complete before starting ours.
            // This prevents the cancel-chain: finish(url:nil) at the top of extractHLSURL
            // cancels any pending continuation, so we must not call extractHLSURL until
            // the previous extraction has already resolved and cleared its continuation.
            _ = await previousTask?.value
            guard let self else { return Optional<URL>.none }
            // Epoch check: if priorityExtract advanced the epoch while we were waiting,
            // we are stale. Only yield to the priority task's URL if the priority task is
            // for the *same* videoId — yielding a different video's URL would poison the
            // caller's cache entry (fix10/preWarm) with the wrong stream.
            guard self.serialTaskEpoch == capturedEpoch else {
                if self.pendingSerialTaskVideoId == videoId {
                    extractLog.notice("[webView] serialExtract(\(videoId as NSString)): stale epoch, same video — yielding to priority task")
                    return await self.pendingSerialTask?.value
                } else {
                    let priorityId = self.pendingSerialTaskVideoId ?? "nil"
                    extractLog.notice("[webView] serialExtract(\(videoId as NSString)): stale epoch, priority is for different video (\(priorityId as NSString)) — returning nil to prevent cache poisoning")
                    return nil
                }
            }
            extractLog.notice("[webView] serialExtract(\(videoId as NSString)): starting (previous task done)")
            return await self.extractHLSURL(videoId: videoId)
        }
        pendingSerialTask = newTask
        return await newTask.value
    }

    // MARK: - EJS Solver Scripts

    /// Loads the yt-dlp EJS AST-based n-challenge solver scripts from the app bundle
    /// and returns them as ordered WKUserScript instances ready for injection.
    ///
    /// Injection order matters:
    ///   1. lib.min.js  — defines `var lib = {meriyah, astring}` (JS AST parser + code-gen)
    ///   2. bridge       — exposes `meriyah` and `astring` as top-level globals
    ///   3. core.min.js — defines `var jsc = (function(e,n){...})(meriyah, astring)` (solver)
    private static func ejsSolverUserScripts() -> [WKUserScript]? {
        guard let libURL  = Bundle.main.url(forResource: "yt.solver.lib.min",  withExtension: "js"),
              let coreURL = Bundle.main.url(forResource: "yt.solver.core.min", withExtension: "js"),
              let libCode  = try? String(contentsOf: libURL,  encoding: .utf8),
              let coreCode = try? String(contentsOf: coreURL, encoding: .utf8) else {
            extractLog.warning("⚠️ [webView] EJS solver scripts not found in bundle")
            return nil
        }
        let bridgeCode = "var meriyah = (typeof lib !== 'undefined' && lib.meriyah) || undefined; " +
                         "var astring = (typeof lib !== 'undefined' && lib.astring) || undefined;"
        return [
            WKUserScript(source: libCode,    injectionTime: .atDocumentStart, forMainFrameOnly: true),
            WKUserScript(source: bridgeCode, injectionTime: .atDocumentStart, forMainFrameOnly: true),
            WKUserScript(source: coreCode,   injectionTime: .atDocumentStart, forMainFrameOnly: true),
        ]
    }

    // MARK: - JavaScript Interceptor

    /// Injected at document-start. Intercepts the YouTube player's internal API call,
    /// extracts `hlsManifestUrl`, and solves the HLS-specific n-challenge before sending to Swift.
    ///
    /// N-challenge strategy:
    ///   1. `tryExtractHLS` fires when the YouTube player API response arrives (~2.5 s).
    ///   2. An async IIFE immediately fetches the HLS master manifest (same URL, same origin,
    ///      usually CORS-allowed from youtube.com → manifest.googlevideo.com) to find the
    ///      per-quality variant URL which contains `/n/{HLS_unsolved}/` in its path.
    ///   3. It then fetches the player JS (loaded in the page; usually a cache hit in WKWebView)
    ///      and uses yt-dlp-style regex patterns to locate the n-solver function stored in an
    ///      array inside the minified player code.
    ///   4. The solver is extracted via bracket-balanced parsing (handles commas in fn bodies),
    ///      evaluated, and called with the HLS unsolved n-value to produce the solved n.
    ///   5. The mapping (unsolvedHLS → solvedHLS) is sent to Swift so `YTHLSProxyLoader` can
    ///      rewrite all `/n/unsolved/` occurrences in the M3U8 playlist text before AVPlayer
    ///      reads it — making CDN segment requests return HTTP 200 instead of 403.
    ///   6. A 9-second fallback timer fires if the async chain fails or times out, sending
    ///      whatever state is available (nil if player JS extraction failed).
    private static let interceptorJS: String = #"""
    (function() {
        'use strict';

        // Detect consent wall at document-start and report to native.
        // If the SOCS=CAI cookie pre-seeding failed (e.g. the cookie was not accepted
        // by WKWebView before the first request), YouTube redirects EU users to
        // consent.youtube.com or shows a GDPR bump on the page itself.
        // Native Swift logs a warning so EU timeout failures can be diagnosed.
        (function checkConsentWall() {
            try {
                var h = document.location.hostname;
                if (h === 'consent.youtube.com' ||
                    document.querySelector('[data-view-name="VIEW_NAME_CONSENT_BUMP"]') ||
                    document.querySelector('.HEBJsc')) {
                    window.webkit.messageHandlers.hlsExtractor.postMessage(
                        JSON.stringify({ consentWallDetected: true, timestamp: Date.now() })
                    );
                }
            } catch(e) {}
        })();

        var sentFinalURL = false;
        // Set to true as soon as tryExtractHLS starts its async resolution,
        // to suppress xhrManifest/fetchManifest fallbacks from firing.
        var hlsExtractionStarted = false;

        function sendHLSURL(hlsUrl, poToken, source, unsolvedN, solvedN, playerID, capturedPageVideoId) {
            if (sentFinalURL) return;
            sentFinalURL = true;
            // fix29: Include the page's own videoId so Swift can reject stale JS
            // callbacks that fire after wv.load() switches to a new video. Without
            // this check, a pending XHR or fetch .then() from the PREVIOUS page can
            // deliver the wrong video's HLS URL into the current extraction.
            // fix29b: Prefer capturedPageVideoId (read at request setup time) over
            // window.location.href. Stale async callbacks fire AFTER wv navigates to
            // the new page, so window.location.href already shows the NEW video's ID —
            // breaking fix29's guard. Capturing at open()/fetch() call time preserves
            // the correct ID regardless of subsequent page navigation.
            var vid = capturedPageVideoId;
            if (!vid) {
                try {
                    var m = window.location.href.match(/[?&]v=([^&]+)/);
                    vid = m ? m[1] : null;
                } catch(e) {}
            }
            window.webkit.messageHandlers.hlsExtractor.postMessage(
                JSON.stringify({
                    hlsManifestUrl: hlsUrl,
                    videoId:        vid,
                    poToken:        poToken   || null,
                    source:         source    || 'unknown',
                    unsolvedN:      unsolvedN || null,
                    solvedN:        solvedN   || null,
                    playerID:       playerID  || null
                })
            );
        }

        function isManifestVariantURL(url) {
            var s = url ? url.toString() : '';
            return s.indexOf('manifest.googlevideo.com') !== -1 &&
                   (s.indexOf('hls_variant') !== -1 || s.indexOf('hls_manifest') !== -1);
        }

        function isPlayerURL(url) {
            return url && url.toString().indexOf('youtubei/v1/player') !== -1;
        }

        // ── N-solver extraction from player JS ────────────────────────────────────────
        // Extracts the function at `arrIdx` from the array `arrName` in `jsText`.
        // Uses bracket-balanced parsing so commas inside function bodies don't split incorrectly.
        function extractFnFromJSArray(jsText, arrName, arrIdx) {
            var safe = arrName.replace(/[$]/g, '\\$');
            var decl = new RegExp('var\\s+' + safe + '\\s*=\\s*\\[');
            var di   = jsText.search(decl);
            if (di < 0) return null;

            var ob = jsText.indexOf('[', di);
            if (ob < 0) return null;

            var depth = 1, i = ob + 1, eStart = ob + 1, eIdx = 0;
            while (i < jsText.length && depth > 0) {
                var ch = jsText[i];
                if (ch === '[' || ch === '{' || ch === '(') {
                    depth++;
                } else if (ch === ']' || ch === '}' || ch === ')') {
                    depth--;
                    if (depth === 0) {
                        if (eIdx === arrIdx) return jsText.slice(eStart, i).trim();
                        break;
                    }
                } else if ((ch === '"' || ch === "'" || ch === '`') && depth === 1) {
                    var q = ch; i++;
                    while (i < jsText.length && jsText[i] !== q) {
                        if (jsText[i] === '\\') i++;
                        i++;
                    }
                } else if (ch === ',' && depth === 1) {
                    if (eIdx === arrIdx) return jsText.slice(eStart, i).trim();
                    eIdx++;
                    eStart = i + 1;
                }
                i++;
            }
            return null;
        }

        // Downloads the main player JS and uses the bundled EJS AST-based solver (jsc)
        // to solve `unsolvedN`. Returns the solved string, or null on failure.
        // `jsc` is defined by the solver WKUserScripts injected before this script.
        async function solveNFromPlayerJS(unsolvedN) {
            try {
                // jsc must be available from the EJS solver scripts injected at document-start
                if (typeof jsc !== 'function') return null;

                // Locate the IAS player script to extract the player ID
                var playerSrc = null;
                var scripts = document.querySelectorAll('script[src]');
                for (var si = 0; si < scripts.length; si++) {
                    if (scripts[si].src && scripts[si].src.indexOf('player_ias') > -1) {
                        playerSrc = scripts[si].src;
                        break;
                    }
                }
                if (!playerSrc) return null;

                // Build the main-variant URL (player_es6) from the player ID.
                // yt-dlp forces the 'main' variant (player_es6.vflset/en_US/base.js)
                // because only that variant contains the n-solver function.
                var pidMatch = playerSrc.match(/\/player\/([a-f0-9]+)\//);
                if (!pidMatch) return null;
                var mainUrl = 'https://www.youtube.com/s/player/' + pidMatch[1] +
                              '/player_es6.vflset/en_US/base.js';

                // Fetch with cache:default so WKWebView serves from cache if available,
                // or fetches from network (~2.5 MB) on first call.
                var jsResp = await origFetch.call(window, mainUrl, {cache: 'default'});
                if (!jsResp.ok) return null;
                var jsText = await jsResp.text();

                // Run the EJS AST-based solver. This parses the player JS, locates the
                // n-solver function structurally, calls it, and returns the solved value.
                var solverInput = {
                    type: 'player',
                    player: jsText,
                    requests: [{type: 'n', challenges: [unsolvedN]}]
                };
                var result = jsc(solverInput);
                if (result && result.type === 'result' &&
                    result.responses && result.responses.length > 0) {
                    var resp = result.responses[0];
                    if (resp.type === 'result' && resp.data) {
                        var solved = resp.data[unsolvedN];
                        return (typeof solved === 'string' && solved !== unsolvedN) ? solved : null;
                    }
                }
                return null;
            } catch(e) {
                return null;
            }
        }

        // ── Main extraction ───────────────────────────────────────────────────────────
        function tryExtractHLS(responseData, requestBodyStr, capturedPageVideoId) {
            if (sentFinalURL || hlsExtractionStarted) return false;
            try {
                var obj = (typeof responseData === 'string') ?
                          JSON.parse(responseData) : responseData;
                if (!obj || !obj.streamingData || !obj.streamingData.hlsManifestUrl)
                    return false;

                var hlsUrl  = obj.streamingData.hlsManifestUrl;
                var poToken = null;
                try {
                    if (requestBodyStr) {
                        var rq = JSON.parse(requestBodyStr);
                        if (rq && rq.serviceIntegrityDimensions &&
                            rq.serviceIntegrityDimensions.poToken)
                            poToken = rq.serviceIntegrityDimensions.poToken;
                    }
                } catch(e) {}

                hlsExtractionStarted = true;

                // Extract player ID from multiple sources (in priority order).
                // Sent to Swift so it can run the EJS solver via Node.js as a fallback.
                var playerID = null;
                try {
                    // Method 1: script[src] with any /player/ path segment
                    var piScripts = document.querySelectorAll('script[src]');
                    for (var psi = 0; psi < piScripts.length; psi++) {
                        var pSrc = piScripts[psi].src || piScripts[psi].getAttribute('src') || '';
                        if (pSrc.indexOf('/player/') > -1) {
                            var pidM = pSrc.match(/\/player\/([a-f0-9]+)\//);
                            if (pidM) { playerID = pidM[1]; break; }
                        }
                    }
                    // Method 2: ytcfg.get('PLAYER_JS_URL')
                    if (!playerID && window.ytcfg && typeof window.ytcfg.get === 'function') {
                        var pjsUrl = window.ytcfg.get('PLAYER_JS_URL') ||
                                     window.ytcfg.get('jsUrl') || '';
                        if (pjsUrl) {
                            var pm2 = pjsUrl.match(/\/player\/([a-f0-9]+)\//);
                            if (pm2) playerID = pm2[1];
                        }
                    }
                    // Method 3: Scan page HTML for the IAS player URL pattern (always present)
                    if (!playerID) {
                        var pageHtml = document.documentElement.innerHTML || '';
                        var pm3 = pageHtml.match(/\/s\/player\/([a-f0-9]{8})\/player_ias/);
                        if (pm3) playerID = pm3[1];
                    }
                } catch(e) {}

                // Async phase: fetch master manifest → extract HLS n-value → solve it
                (async function() {
                    var hlsN = null, solvedN = null;

                    // Fallback timer: if async chain takes >20 s, send whatever we have.
                    var fallbackTimer = setTimeout(function() {
                        sendHLSURL(hlsUrl, poToken, 'apiResponse', hlsN, solvedN, playerID, capturedPageVideoId);
                    }, 20000);

                    try {
                        // Step 1: Fetch the HLS master manifest to find a per-quality
                        // playlist URL containing /n/{hlsN}/ in the path.
                        var mResp = await origFetch.call(window, hlsUrl, {credentials: 'include'});
                        var mText = await mResp.text();
                        // Per-quality playlist URLs embed the HLS n-value as a path segment
                        var nm = mText.match(/\/n\/([A-Za-z0-9_-]{10,})\//);
                        if (nm) hlsN = nm[1];
                    } catch(e) {}

                    try {
                        // Step 2: Try in-JS EJS solver (only works if jsc is defined).
                        if (hlsN && typeof jsc === 'function') solvedN = await solveNFromPlayerJS(hlsN);
                    } catch(e) {}

                    clearTimeout(fallbackTimer);
                    // Include playerID so Swift can run the Node.js solver as fallback.
                    sendHLSURL(hlsUrl, poToken, 'apiResponse', hlsN, solvedN, playerID, capturedPageVideoId);
                })();

                return true;
            } catch(e) {}
            return false;
        }

        // ── video.src hook (iOS/native-HLS mode fallback) ────────────────────────────
        var mediaProto  = HTMLMediaElement.prototype;
        var origSrcDesc = Object.getOwnPropertyDescriptor(mediaProto, 'src');
        if (origSrcDesc && origSrcDesc.set) {
            Object.defineProperty(mediaProto, 'src', {
                set: function(url) {
                    if (url && typeof url === 'string' && isManifestVariantURL(url)) {
                        var pageVid = null;
                        try {
                            var m = window.location.href.match(/[?&]v=([^&]+)/);
                            pageVid = m ? m[1] : null;
                        } catch(e) {}
                        sendHLSURL(url, null, 'videoSrc', null, null, null, pageVid);
                    }
                    return origSrcDesc.set.call(this, url);
                },
                get: origSrcDesc.get,
                configurable: true
            });
        }

        // ── XHR hook ──────────────────────────────────────────────────────────────────
        var origOpen = XMLHttpRequest.prototype.open;
        var origSend = XMLHttpRequest.prototype.send;

        XMLHttpRequest.prototype.open = function(method, url) {
            var urlStr = url ? url.toString() : '';
            this.__isPlayerReq   = isPlayerURL(urlStr);
            this.__isManifestReq = isManifestVariantURL(urlStr);
            if (this.__isManifestReq) this.__manifestUrl = urlStr;
            // fix29b: Capture page videoId at open() time, before any async page
            // navigation. Stale .then() callbacks read window.location.href AFTER
            // wv navigates — by then it shows the new video's ID, bypassing fix29.
            if (this.__isPlayerReq || this.__isManifestReq) {
                try {
                    var m = window.location.href.match(/[?&]v=([^&]+)/);
                    this.__pageVideoId = m ? m[1] : null;
                } catch(e) { this.__pageVideoId = null; }
            }
            return origOpen.apply(this, arguments);
        };

        XMLHttpRequest.prototype.send = function(body) {
            // xhrManifest fallback — only fires if player API never responded
            if (this.__isManifestReq && this.__manifestUrl && !hlsExtractionStarted)
                sendHLSURL(this.__manifestUrl, null, 'xhrManifest', null, null, null, this.__pageVideoId);
            if (this.__isPlayerReq) {
                var capturedBody = (typeof body === 'string') ? body : null;
                var capturedPageVideoId = this.__pageVideoId;  // fix29b: captured at open() time
                this.addEventListener('load', function() {
                    tryExtractHLS(this.responseText, capturedBody, capturedPageVideoId);
                });
            }
            return origSend.apply(this, arguments);
        };

        // ── fetch hook ────────────────────────────────────────────────────────────────
        var origFetch = window.fetch;
        window.fetch = function(input, init) {
            var url = (typeof input === 'string') ? input :
                      (input && (input.url || input.href)) || '';
            var bodyStr = null;
            // fix29b: Capture page videoId at fetch() call time, before any async
            // navigation. The .then() callback fires asynchronously and may read
            // a different window.location.href if wv has navigated by then.
            var capturedPageVideoId = null;
            try {
                var m = window.location.href.match(/[?&]v=([^&]+)/);
                capturedPageVideoId = m ? m[1] : null;
            } catch(e) {}
            try {
                if (isPlayerURL(url) && init && init.body)
                    bodyStr = (typeof init.body === 'string') ? init.body : null;
            } catch(e) {}

            var promise = origFetch.apply(this, arguments);
            if (isManifestVariantURL(url)) {
                // fetchManifest fallback — only fires if player API never responded
                if (!hlsExtractionStarted)
                    sendHLSURL(url, null, 'fetchManifest', null, null, null, capturedPageVideoId);
            } else if (isPlayerURL(url)) {
                var capturedBody = bodyStr;
                promise.then(function(response) {
                    return response.clone().text().then(function(text) {
                        tryExtractHLS(text, capturedBody, capturedPageVideoId);
                    });
                }).catch(function() {});
            }
            return promise;
        };

        // ── DOMContentLoaded fallback ─────────────────────────────────────────────────
        document.addEventListener('DOMContentLoaded', function() {
            try {
                if (window.ytInitialPlayerResponse) {
                    var vid = null;
                    try {
                        var m = window.location.href.match(/[?&]v=([^&]+)/);
                        vid = m ? m[1] : null;
                    } catch(e) {}
                    tryExtractHLS(window.ytInitialPlayerResponse, null, vid);
                }
            } catch(e) {}
        });
    })();
    """#

    // MARK: - Private helpers

    private func finishWithURL(_ url: URL, poToken: String?) {
        // Store the pot= token as a separate property so callers can read it from
        // `extractedPoToken` after `extractHLSURL` returns. Previously the pot was
        // baked into the manifest URL path (/pot/<token>), which is not a valid CDN
        // path and would cause a 404 on manifest fetch. The URL is passed unchanged.
        extractedPoToken = (poToken?.isEmpty == false) ? poToken : nil
        if let pot = poToken, !pot.isEmpty {
            extractLog.notice("[webView] pot= token extracted (\(pot.count) chars) — stored in extractedPoToken")
        }
        finish(url: url)
    }

    /// Solves an HLS n-challenge using the bundled EJS solver evaluated in JavaScriptCore.
    /// Downloads and caches the main player JS variant from YouTube's CDN, then runs the
    /// yt-dlp EJS solver (lib + core) inside a JSContext — works on both simulator and
    /// real iOS/tvOS devices (no Node.js required).
    private static func solveNChallengeViaJSC(playerID: String, unsolvedN: String) async -> String? {
        guard let libURL  = Bundle.main.url(forResource: "yt.solver.lib.min",  withExtension: "js"),
              let coreURL = Bundle.main.url(forResource: "yt.solver.core.min", withExtension: "js"),
              let libCode  = try? String(contentsOf: libURL,  encoding: .utf8),
              let coreCode = try? String(contentsOf: coreURL, encoding: .utf8) else {
            extractLog.warning("⚠️ [solver] EJS scripts not found in bundle")
            return nil
        }

        // Download or use cached copy of the main player JS variant.
        // yt-dlp uses the `player_es6.vflset/en_US/base.js` variant because it is the
        // only variant that contains the n-solver function.
        // NSTemporaryDirectory() works correctly on both simulator and real device.
        let tmpPlayerPath = NSTemporaryDirectory() + "yt_player_\(playerID).js"
        let playerJS: String
        if let cached = try? String(contentsOfFile: tmpPlayerPath, encoding: .utf8), !cached.isEmpty {
            playerJS = cached
        } else {
            guard let playerURL = URL(string:
                "https://www.youtube.com/s/player/\(playerID)/player_es6.vflset/en_US/base.js"
            ) else { return nil }
            extractLog.notice("⚠️ [solver] downloading player JS for \(playerID as NSString)")
            guard let (data, _) = try? await URLSession.shared.data(from: playerURL),
                  !data.isEmpty,
                  let js = String(data: data, encoding: .utf8) else {
                extractLog.warning("⚠️ [solver] player JS download failed")
                return nil
            }
            try? js.write(toFile: tmpPlayerPath, atomically: true, encoding: .utf8)
            playerJS = js
        }
        extractLog.notice("⚠️ [solver] running JSC EJS solver, n=\(unsolvedN as NSString)")

        // Run the JSContext solver on a detached background task — JSContext is not
        // Sendable and must be created and consumed on the same thread.
        return await Task.detached(priority: .userInitiated) {
            let context = JSContext()!
            var jsError: String?
            context.exceptionHandler = { _, e in jsError = e?.toString() }

            // lib.min.js defines `var lib = {meriyah, astring}` (JS AST parser).
            context.evaluateScript(libCode)
            context.evaluateScript("var meriyah = lib.meriyah; var astring = lib.astring;")
            // core.min.js defines `var jsc = function(e,n){...}(meriyah,astring)` (EJS solver).
            context.evaluateScript(coreCode)

            // Inject playerJS and unsolvedN as JS objects to avoid any escaping issues.
            context.setObject(playerJS,   forKeyedSubscript: "playerJSContent" as NSString)
            context.setObject(unsolvedN,  forKeyedSubscript: "unsolvedNValue"  as NSString)

            let result = context.evaluateScript("""
            (function() {
                try {
                    var r = jsc({type:'player', player:playerJSContent,
                                 requests:[{type:'n', challenges:[unsolvedNValue]}]});
                    return (r && r.responses && r.responses[0] && r.responses[0].data)
                        ? r.responses[0].data[unsolvedNValue] : null;
                } catch(e) { return null; }
            })()
            """)

            if let err = jsError {
                extractLog.error("❌ [solver/JSC] exception: \(err as NSString)")
            }
            let solved = result?.toString()
            guard let s = solved, !s.isEmpty, s != "null", s != "undefined", s != unsolvedN else {
                return nil
            }
            return s
        }.value
    }

    private func finish(url: URL?) {
        timeoutTask?.cancel()
        timeoutTask = nil
        currentExtractionVideoId = nil
        // Capture and immediately nil the continuation so the cancelled timeout
        // task (which wakes after CancellationError swallowed by try?) cannot
        // double-resume it when it calls finish(url: nil).
        let pendingContinuation = continuation
        continuation = nil
        // Fan out to all extra waiters registered via awaitCurrentExtraction().
        let extras = extraContinuations
        extraContinuations.removeAll()
        for c in extras { c.resume(returning: url) }

        guard let url, let pendingContinuation else {
            // Either nil URL (timeout/error) or already resumed — just clean up.
            pendingContinuation?.resume(returning: Optional<URL>.none)
            // fix17: Keep WKWebView alive for the next extraction. stopLoading() stops the
            // current page load; the next extractHLSURL call will navigate via wv.load(request).
            // The WebContent process (JIT cache) and IndexedDB (BotGuard token) persist.
            webView?.stopLoading()
            return
        }

        extractLog.notice("✅ [webView] hlsManifestUrl extracted url=\(String(url.absoluteString.prefix(200)) as NSString)")

        // Sync youtube.com session cookies from WKWebView's httpCookieStore into
        // HTTPCookieStorage.shared NOW (page-load cookies are already set by the time
        // the player makes its /player call — no need to wait for video playback).
        // The proxy loader will attach these cookies to googlevideo.com segment requests
        // so the CDN can validate the /bui/ token against VISITOR_INFO1_LIVE.
        let capturedURL = url
        // fixNSolver: Capture extractedNSolver at the moment finishWithURL is called.
        // A concurrent serialExtract call (e.g. VideoCardView prewarming) can call
        // extractHLSURL between now and when the cookie-sync Task runs, which resets
        // extractedNSolver = nil. Restoring the snapshot just before resuming the
        // continuation guarantees that racePathB / exhaustiveRetry reads the correct
        // value when they wake up on the main actor right after the resume.
        let capturedNSolver = extractedNSolver
        Task { @MainActor [weak self] in
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                    let gvCount = cookies.filter { $0.domain.contains("googlevideo") }.count
                    let names = cookies.map { "\($0.name)@\($0.domain)" }.joined(separator: " ")
                    extractLog.notice("⚠️ [webView] syncing \(cookies.count) cookies (\(gvCount) googlevideo): \(names as NSString)")
                    for cookie in cookies {
                        HTTPCookieStorage.shared.setCookie(cookie)
                    }
                    cont.resume()
                }
            }
            guard let self else { return }
            // Restore the nSolver snapshot so callers reading extractedNSolver immediately
            // after the continuation resumes always see the value that was valid for this URL.
            // Only restore if a newer extraction hasn't already set a different solver.
            if self.extractedNSolver == nil, let capturedNSolver {
                self.extractedNSolver = capturedNSolver
                extractLog.notice("[webView/fixNSolver] nSolver snapshot restored before resume: \(capturedNSolver.unsolved as NSString) → \(capturedNSolver.solved as NSString)")
            }
            // fix17: Keep WKWebView alive — don't nil it out on success.
            // The persistent WKWebView is immediately ready for the next extraction.
            self.webView?.stopLoading()
            pendingContinuation.resume(returning: capturedURL)
        }
    }
}

// MARK: - WKScriptMessageHandler

extension YouTubeWebViewHLSExtractor: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                                didReceive message: WKScriptMessage) {
        guard message.name == "hlsExtractor" else { return }

        // Message is now a JSON object: { hlsManifestUrl, poToken, source, unsolvedN, solvedN }
        var hlsURLString: String?
        var poToken: String?
        var urlSource = "unknown"
        var unsolvedNValue: String? = nil
        var solvedNValue: String? = nil
        var playerIDValue: String? = nil

        if let body = message.body as? String {
            // Try to parse as JSON first (new format)
            if let data = body.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Consent-wall detection message: SOCS cookie pre-seeding did not work.
                if let consentWall = json["consentWallDetected"] as? Bool, consentWall {
                    extractLog.warning("⚠️ [webView/HLS] consent wall detected — SOCS cookie bypass did not prevent EU GDPR dialog; hlsManifestUrl will not arrive")
                    return
                }
                hlsURLString = json["hlsManifestUrl"] as? String
                poToken = json["poToken"] as? String
                urlSource = (json["source"] as? String) ?? "unknown"
                unsolvedNValue = json["unsolvedN"] as? String
                solvedNValue = json["solvedN"] as? String
                playerIDValue = json["playerID"] as? String
                // fix29: Reject stale JS callbacks from a previous page. When wv.load()
                // switches to a new video, any in-flight XHR/fetch callbacks from the
                // old page may fire after `currentExtractionVideoId` has changed. The
                // JS embeds the page's own v= parameter in every message so we can
                // verify the callback belongs to the current extraction.
                if let msgVid = json["videoId"] as? String,
                   let curVid = currentExtractionVideoId,
                   msgVid != curVid {
                    extractLog.warning("⚠️ [webView/fix29] stale JS callback: videoId=\(msgVid as NSString) != current=\(curVid as NSString) — ignoring")
                    return
                }
            } else {
                // Fallback: raw URL string (old format)
                hlsURLString = body
            }
        }

        guard let urlString = hlsURLString,
              let url = URL(string: urlString),
              urlString.contains("googlevideo.com") || urlString.contains("manifest") else {
            return
        }

        extractLog.notice("⚠️ [webView] URL captured source=\(urlSource as NSString)")

        // If the JS interceptor already solved the n-challenge, use it directly.
        if let u = unsolvedNValue, let s = solvedNValue, u != s {
            extractedNSolver = (unsolved: u, solved: s)
            extractLog.notice("✅ [webView] n-challenge solved in JS: \(u as NSString) → \(s as NSString)")
            finishWithURL(url, poToken: poToken)
            return
        }

        // JS solver was not available — try solving on the Swift side via Node.js.
        if let playerID = playerIDValue, let unsolvedN = unsolvedNValue, !unsolvedN.isEmpty {
                extractLog.notice("⚠️ [webView] JS solver unavailable; launching JSC solver for playerID=\(playerID as NSString) n=\(unsolvedN as NSString)")
            let capturedURL    = url
            let capturedPoToken = poToken
            // fix239: capture generation so we can detect if a new extraction started
            // while the JSC solver was running (~0.3 s). Without this guard, the stale
            // Task resumes the NEW video's continuation with the OLD video's HLS URL.
            let myGeneration = extractionGeneration
            Task { @MainActor [weak self] in
                guard let self else { return }
                let solved = await Task.detached(priority: .userInitiated) {
                    await Self.solveNChallengeViaJSC(playerID: playerID, unsolvedN: unsolvedN)
                }.value
                // fix239: reject if a new extraction started while we were solving
                guard self.extractionGeneration == myGeneration else {
                    extractLog.warning("⚠️ [webView/fix239] stale JSC solver result discarded — generation was \(myGeneration) now \(self.extractionGeneration) n=\(unsolvedN as NSString)")
                    return
                }
                if let s = solved, !s.isEmpty, s != unsolvedN {
                    self.extractedNSolver = (unsolved: unsolvedN, solved: s)
                    extractLog.notice("✅ [webView] n solved via JSC: \(unsolvedN as NSString) → \(s as NSString)")
                } else {
                    self.extractedNSolver = nil
                    extractLog.notice("⚠️ [webView] JSC solver returned nil/same for n=\(unsolvedN as NSString)")
                }
                self.finishWithURL(capturedURL, poToken: capturedPoToken)
            }
            return
        }

        // No n-challenge found or no player ID available.
        if let u = unsolvedNValue {
            extractedNSolver = nil
            extractLog.notice("⚠️ [webView] n NOT solved (no playerID available): unsolvedN=\(u as NSString)")
        } else {
            extractedNSolver = nil
            extractLog.notice("⚠️ [webView] no n-challenge found in HLS manifest")
        }
        finishWithURL(url, poToken: poToken)
    }
}

// MARK: - WKNavigationDelegate

extension YouTubeWebViewHLSExtractor: WKNavigationDelegate {

    func webView(_ webView: WKWebView,
                 didFail navigation: WKNavigation!,
                 withError error: Error) {
        // fix17: Ignore NSURLErrorCancelled (-999) — these fire when stopLoading() is called
        // between sequential extractions on the reused WKWebView.
        let nsError = error as NSError
        guard nsError.code != NSURLErrorCancelled else { return }
        extractLog.error("❌ [webView] navigation failed: \(error.localizedDescription as NSString)")
        finish(url: Optional<URL>.none)
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        // fix17: Ignore NSURLErrorCancelled (-999) — these fire when stopLoading() is called
        // between sequential extractions on the reused WKWebView.
        let nsError = error as NSError
        guard nsError.code != NSURLErrorCancelled else { return }
        extractLog.error("❌ [webView] provisional navigation failed: \(error.localizedDescription as NSString)")
        finish(url: Optional<URL>.none)
    }
}

#endif // canImport(WebKit)
