//
//  HomeFeedService.swift
//  UnwatchedShared
//

#if canImport(WebKit)
import Foundation
import WebKit

/// Recommendations fetched inside a hidden youtube.com page, so the session cookies never leave WebKit.
@MainActor @Observable
public final class HomeFeedService: NSObject, WKNavigationDelegate {
    public static let shared = HomeFeedService()

    public struct Page: Sendable {
        public var videos: [ITVideo]
        public var nextPageToken: String?
    }

    public enum HomeFeedError: Error, Equatable {
        case pageUnavailable
        case requestFailed(Int)
        case signedOut
    }

    private static let pageLifetime: TimeInterval = 30 * 60
    private static let idleRelease: Duration = .seconds(180)
    private static let seedLimit = 3
    private static let pageTimeout: Duration = .seconds(15)
    private static let requestTimeout: Duration = .seconds(15)

    @ObservationIgnored private let api = InnerTubeAPI()
    @ObservationIgnored private var webView: WKWebView?
    @ObservationIgnored private var pageLoadedAt: Date?
    @ObservationIgnored private var pageLoad: Task<Void, Error>?
    @ObservationIgnored private var navigationError: Error?
    @ObservationIgnored private var idleTask: Task<Void, Never>?

    public private(set) var accountVersion = 0

    // ytcfg is per channel
    public func accountChanged() {
        Log.innerTube.info("home feed: account changed")
        accountVersion += 1
        pageLoad?.cancel()
        pageLoad = nil
        discardPage()
    }

    public func fetch(seedIds: [String]) async throws -> Page {
        defer { scheduleRelease() }
        try await ensurePage()
        if (try? await isLoggedIn()) == true {
            let page = try await request("browse", ["browseId": "FEwhat_to_watch"])
            let videos = page.videos.filter(Self.isRecommendable)
            if !videos.isEmpty {
                Log.innerTube.info("home feed: \(videos.count) videos")
                return Page(videos: videos, nextPageToken: page.nextPageToken)
            }
            // history turned off
            Log.innerTube.info("home feed empty while signed in, using related videos")
        }
        return try await related(to: seedIds)
    }

    public func fetchMore(token: String) async throws -> Page {
        defer { scheduleRelease() }
        try await ensurePage()
        let page = try await request("browse", ["continuation": token])
        let videos = page.videos.filter(Self.isRecommendable)
        Log.innerTube.info("home feed next page: \(videos.count) videos")
        return Page(videos: videos, nextPageToken: page.nextPageToken)
    }

    /// A playlist as the signed-in account sees it, e.g. Watch Later.
    public func fetchPlaylist(
        _ playlistId: String,
        continuationToken: String? = nil
    ) async throws -> InnerTubeAPI.SearchPage {
        defer { scheduleRelease() }
        try await ensurePage()
        let payload: [String: Any]
        if let continuationToken {
            payload = ["continuation": continuationToken]
        } else {
            guard try await isLoggedIn() else { throw HomeFeedError.signedOut }
            payload = ["browseId": "VL\(playlistId)"]
        }
        return try await request("browse", payload) { api, body in
            await api.parsePlaylistPage(json: body, playlistId: playlistId)
        }
    }

    // round-robin, so the first rows aren't all about one seed
    private func related(to seedIds: [String]) async throws -> Page {
        var lists: [[ITVideo]] = []
        for id in seedIds.prefix(Self.seedLimit) {
            do {
                lists.append(try await request("next", ["videoId": id]).videos)
            } catch {
                Log.innerTube.error("related videos for \(id) failed: \(error)")
            }
        }
        let excluded = Set(seedIds)
        var seen = Set<String>()
        var merged: [ITVideo] = []
        for index in 0..<(lists.map(\.count).max() ?? 0) {
            for list in lists where index < list.count {
                let video = list[index]
                guard Self.isRecommendable(video), !excluded.contains(video.id),
                      seen.insert(video.id).inserted else { continue }
                merged.append(video)
            }
        }
        Log.innerTube.info("related videos: \(merged.count) from \(lists.count) seeds")
        return Page(videos: merged, nextPageToken: nil)
    }

    // an untitled lockup (movie, promotion) would show its id
    private static func isRecommendable(_ video: ITVideo) -> Bool {
        !video.isShort && !video.title.isEmpty
    }

    // MARK: - Page

    private func ensurePage() async throws {
        idleTask?.cancel()
        if webView != nil, let loaded = pageLoadedAt, Date().timeIntervalSince(loaded) < Self.pageLifetime {
            return
        }
        if let pageLoad {
            return try await pageLoad.value
        }
        let task = Task { try await loadPage() }
        pageLoad = task
        defer { if pageLoad == task { pageLoad = nil } }
        try await task.value
    }

    private func loadPage() async throws {
        let webView: WKWebView
        if let existing = self.webView {
            webView = existing
        } else {
            webView = await makeWebView()
        }
        self.webView = webView
        pageLoadedAt = nil
        navigationError = nil
        var request = URLRequest(url: URL(string: "https://www.youtube.com/")!)
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        webView.load(request)
        Log.innerTube.info("loading home page")

        // polled: `didFinish` can take tens of seconds, long after ytcfg is usable
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: Self.pageTimeout)
        while clock.now < deadline {
            if let navigationError { throw navigationError }
            let ready = await evaluateBool(HomeFeedScript.isReady, in: webView)
            if ready {
                Log.innerTube.info("home page ready")
                pageLoadedAt = Date()
                return
            }
            try await Task.sleep(for: .milliseconds(250))
        }
        // e.g. a consent page, or a network error page
        Log.innerTube.error("home page unavailable at \(webView.url?.absoluteString ?? "-")")
        discardPage()
        throw HomeFeedError.pageUnavailable
    }

    private func makeWebView() async -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        if let rules = await Self.pageOnlyRules() {
            config.userContentController.add(rules)
        }
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: config)
        webView.navigationDelegate = self
        // desktop, for the WEB client responses the search parser reads
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
            "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
        return webView
    }

    private static var cachedRules: WKContentRuleList?

    private static func pageOnlyRules() async -> WKContentRuleList? {
        if let cachedRules { return cachedRules }
        cachedRules = await lookUpOrCompileRules()
        return cachedRules
    }

    private static func lookUpOrCompileRules() async -> WKContentRuleList? {
        let store = WKContentRuleListStore.default()
        let identifier = "HomeFeedPageOnly-1"
        if let rules = try? await store?.contentRuleList(forIdentifier: identifier) {
            return rules
        }
        do {
            return try await store?.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: HomeFeedScript.pageOnlyRules)
        } catch {
            Log.innerTube.error("content rules failed: \(error)")
            return nil
        }
    }

    private func scheduleRelease() {
        idleTask?.cancel()
        idleTask = Task { [weak self] in
            try? await Task.sleep(for: Self.idleRelease)
            guard !Task.isCancelled, let self else { return }
            self.discardPage()
        }
    }

    private func discardPage() {
        webView = nil
        pageLoadedAt = nil
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        navigationError = error
    }

    public func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        navigationError = error
    }

    // MARK: - Requests

    private func isLoggedIn() async throws -> Bool {
        guard let webView else { throw HomeFeedError.pageUnavailable }
        let loggedIn: Bool? = await withDeadline(.seconds(3), fallback: nil) { finish in
            webView.evaluateJavaScript(HomeFeedScript.isLoggedIn) { result, _ in
                finish(result as? Bool)
            }
        }
        guard let loggedIn else { throw HomeFeedError.pageUnavailable }
        return loggedIn
    }

    private func request(
        _ endpoint: String,
        _ payload: [String: Any],
        parse: @Sendable (InnerTubeAPI, String) async -> InnerTubeAPI.SearchPage = { await $0.parseVideoPage(json: $1) }
    ) async throws -> InnerTubeAPI.SearchPage {
        guard let webView else { throw HomeFeedError.pageUnavailable }
        let (status, body) = await withDeadline(Self.requestTimeout, fallback: (0, nil)) { finish in
            webView.callAsyncJavaScript(
                HomeFeedScript.request,
                arguments: ["endpoint": endpoint, "payload": payload],
                in: nil,
                in: .page
            ) { result in
                let response = (try? result.get()) as? [String: Any]
                finish((response?["status"] as? Int ?? 0, response?["body"] as? String))
            }
        }
        guard status == 200, let body else {
            // a timeout or a failed script
            if status == 0 { discardPage() }
            throw HomeFeedError.requestFailed(status)
        }
        return await parse(api, body)
    }

    private func evaluateBool(_ script: String, in webView: WKWebView) async -> Bool {
        await withDeadline(.seconds(3), fallback: false) { finish in
            webView.evaluateJavaScript(script) { result, _ in
                finish(result as? Bool ?? false)
            }
        }
    }

    // a call into the page can stay pending forever (seen right after an install)
    private func withDeadline<T: Sendable>(
        _ timeout: Duration,
        fallback: T,
        _ start: (@escaping @MainActor (T) -> Void) -> Void
    ) async -> T {
        await withCheckedContinuation { continuation in
            var finished = false
            let finish: @MainActor (T) -> Void = { value in
                guard !finished else { return }
                finished = true
                continuation.resume(returning: value)
            }
            start(finish)
            Task { @MainActor in
                try? await Task.sleep(for: timeout)
                finish(fallback)
            }
        }
    }
}
#endif
