//
//  YoutubeLoginWebView.swift
//  Unwatched
//

import SwiftUI
import WebKit
import UnwatchedShared

struct YoutubeLoginWebView: PlatformViewRepresentable {
    let onLoggedIn: () -> Void

    func makeView(_ coordinator: Coordinator) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        config.websiteDataStore.httpCookieStore.add(coordinator)
        coordinator.webView = webView
        webView.load(URLRequest(url: UrlService.youtubeLoginUrl))
        return webView
    }

    static func dismantleView(_ view: WKWebView, coordinator: Coordinator) {
        view.stopLoading()
        view.navigationDelegate = nil
        view.uiDelegate = nil
        view.configuration.websiteDataStore.httpCookieStore.remove(coordinator)
    }

    #if os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        makeView(context.coordinator)
    }

    func updateNSView(_ view: WKWebView, context: Context) { }

    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        dismantleView(view, coordinator: coordinator)
    }
    #else
    func makeUIView(context: Context) -> WKWebView {
        makeView(context.coordinator)
    }

    func updateUIView(_ view: WKWebView, context: Context) { }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        dismantleView(view, coordinator: coordinator)
    }
    #endif

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoggedIn: onLoggedIn)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKHTTPCookieStoreObserver {
        let onLoggedIn: () -> Void
        weak var webView: WKWebView?
        /// A stale LOGIN_INFO can predate the sign-in, so it only counts once Google's pages were shown
        private var passedGoogleSignIn = false
        private var isChecking = false
        private var needsRecheck = false
        private var reported = false

        init(onLoggedIn: @escaping () -> Void) {
            self.onLoggedIn = onLoggedIn
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            check()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            check()
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            webView.load(navigationAction.request)
            return nil
        }

        nonisolated func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            Task { @MainActor in self.check() }
        }

        private func check() {
            guard let host = webView?.url?.host() else { return }
            if host.hasPrefix("accounts.google.") {
                passedGoogleSignIn = true
                return
            }
            guard passedGoogleSignIn, !reported,
                  host == "youtube.com" || host.hasSuffix(".youtube.com") else {
                return
            }
            guard !isChecking else {
                needsRecheck = true
                return
            }
            isChecking = true
            Task {
                let isLoggedIn = await BrowserManager.shared.isLoggedIntoYoutube()
                isChecking = false
                if isLoggedIn, !reported {
                    reported = true
                    onLoggedIn()
                } else if needsRecheck {
                    needsRecheck = false
                    check()
                }
            }
        }
    }
}
