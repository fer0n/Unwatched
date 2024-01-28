//
//  FixSubscriptionsView.swift
//  Unwatched
//

import SwiftUI
import WebKit

struct YtBrowserWebView: UIViewRepresentable {
    var browserManager: BrowserManager

    func makeUIView(context: Context) -> WKWebView {
        let webViewConfig = WKWebViewConfiguration()
        webViewConfig.mediaTypesRequiringUserActionForPlayback = [.all]
        webViewConfig.allowsPictureInPictureMediaPlayback = true
        webViewConfig.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: webViewConfig)
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = UIColor.systemBackground
        webView.isOpaque = false
        context.coordinator.startObserving(webView: webView)
        if let url = UrlService.youtubeStartPage {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: YtBrowserWebView
        var observation: NSKeyValueObservation?
        var isFirstLoad = true

        init(_ parent: YtBrowserWebView) {
            self.parent = parent
        }

        deinit {
            stopObserving()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("--- new page loaded")
            if isFirstLoad {
                isFirstLoad = false
                parent.browserManager.firstPageLoaded = true
            }
            let previousUsername = parent.browserManager.desktopUserName
            Task {
                await MainActor.run {
                    guard let url = webView.url else {
                        print("no url found")
                        return
                    }

                    if let userName = UrlService.getChannelUserNameFromUrl(
                        url: url,
                        previousUserName: previousUsername
                    ) {
                        // is username page, reload the page
                        extractSubscriptionInfo(webView, userName: userName)
                    }
                }
            }
        }

        @MainActor func extractSubscriptionInfo(_ webView: WKWebView, userName: String) {
            let url = webView.url
            webView.evaluateJavaScript(getSubscriptionInfoScript) { (result, error) in
                if let error = error {
                    print("JavaScript evaluation error: \(error)")
                } else if let array = result as? [String] {
                    let channelId = array[0]
                    let description = array[1]
                    let rssFeed = array[2]
                    let title = array[3]
                    let image = array[4]
                    print("Channel ID: \(channelId)")
                    print("Description: \(description)")
                    print("RSS Feed: \(rssFeed)")
                    print("Title: \(title)")
                    print("Image: \(image)")

                    self.parent.browserManager.setFoundInfo(url, channelId, description, rssFeed, title, userName)
                }
            }
        }

        @MainActor
        func handleUrlChange(_ webView: WKWebView) {
            guard let url = webView.url else {
                print("no url found")
                return
            }
            print("URL changed: \(url)")
            handleIsMobilePage(url)
            guard let userName = UrlService.getChannelUserNameFromUrl(
                url: url,
                previousUserName: parent.browserManager.desktopUserName
            ) else {
                parent.browserManager.clearInfo()
                print("no user name found")
                return
            }
            if [parent.browserManager.userName, parent.browserManager.desktopUserName].contains(userName) {
                print("same username as before")
                return
            }
            parent.browserManager.desktopUserName = userName

            print("--- forceReloadUrl")
            let request = URLRequest(url: url)
            webView.load(request)

        }

        func handleIsMobilePage(_ url: URL) {
            parent.browserManager.isMobileVersion = UrlService.isMobileYoutubePage(url)
        }

        @MainActor
        func startObserving(webView: WKWebView) {
            observation = webView.observe(\.url, options: .new) { (webView, _) in
                self.handleUrlChange(webView)
            }
        }

        var getSubscriptionInfoScript = """
                var channelId = document.querySelector('meta[itemprop="identifier"]').getAttribute('content');
                var description = document.querySelector('meta[name="description"]').getAttribute('content');
                var rssFeed = document.querySelector('link[rel="alternate"][type="application/rss+xml"]').getAttribute('href');
                var title = document.querySelector('meta[property="og:title"]').getAttribute('content');
                var image = document.querySelector('link[rel="image_src"]').getAttribute('href');
                [channelId, description, rssFeed, title, image];
            """

        func stopObserving() {
            observation?.invalidate()
            observation = nil
        }
    }
}

#Preview {
    BrowserView()
        .modelContainer(DataController.previewContainer)
}
