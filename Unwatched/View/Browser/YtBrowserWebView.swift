//
//  FixSubscriptionsView.swift
//  Unwatched
//

import SwiftUI
import WebKit

struct YtBrowserWebView: UIViewRepresentable {
    var url: URL
    var browserManager: BrowserManager
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false

    func makeUIView(context: Context) -> WKWebView {
        let webViewConfig = WKWebViewConfiguration()
        webViewConfig.mediaTypesRequiringUserActionForPlayback = [.all]
        webViewConfig.allowsPictureInPictureMediaPlayback = true
        webViewConfig.allowsInlineMediaPlayback = !playVideoFullscreen

        let webView = WKWebView(frame: .zero, configuration: webViewConfig)
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = UIColor(Color.youtubeWebBackground)
        webView.isOpaque = false
        context.coordinator.startObserving(webView: webView)
        let request = URLRequest(url: url)
        webView.load(request)
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

        @MainActor func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("--- new page loaded")
            if isFirstLoad {
                isFirstLoad = false
                parent.browserManager.firstPageLoaded = true
            }
            guard let url = webView.url else {
                print("no url found")
                return
            }

            print("about to extract info")
            let (userName, channelId) = getInfoFromUrl(url)
            if userName != nil || channelId != nil {
                // is username page, reload the page
                extractSubscriptionInfo(webView, userName: userName, channelId: channelId)
            }
        }

        func getInfoFromUrl(_ url: URL) -> (userName: String?, channelId: String?) {
            let previousUsername = parent.browserManager.desktopUserName
            if let userName = UrlService.getChannelUserNameFromUrl(
                url: url,
                previousUserName: previousUsername
            ) {
                return (userName: userName, channelId: nil)
            }
            if let channelId = UrlService.getChannelIdFromUrl(url) {
                return (userName: nil, channelId: channelId)
            }
            return (nil, nil)
        }

        @MainActor func extractSubscriptionInfo(_ webView: WKWebView, userName: String?, channelId: String?) {
            print("extractSubscriptionInfo")
            let url = webView.url
            webView.evaluateJavaScript(getSubscriptionInfoScript) { (result, error) in
                if let error = error {
                    print("JavaScript evaluation error: \(error)")
                } else if let array = result as? [String] {
                    let pageChannelId = array[0]
                    let description = array[1]
                    let rssFeed = array[2]
                    let title = array[3]
                    let image = array[4]
                    let id = channelId ?? pageChannelId
                    print("Channel ID: \(id)")
                    print("Description: \(description)")
                    print("RSS Feed: \(rssFeed)")
                    print("Title: \(title)")
                    print("Image: \(image)")

                    self.parent.browserManager.setFoundInfo(ChannelInfo(
                        url, id, description, rssFeed, title, userName
                    ))
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

            if isFirstLoad { return }

            let hasNewUserName = handleHasNewUserName(url)
            let hasChannelId = handleHasNewChannelId(url)

            if !hasNewUserName && !hasChannelId {
                return
            }

            print("--- forceReloadUrl")
            let request = URLRequest(url: url)
            webView.load(request)
        }

        func handleHasNewChannelId(_ url: URL) -> Bool {
            guard let channelId = UrlService.getChannelIdFromUrl(url) else {
                print("no channel id")
                return false
            }
            if parent.browserManager.channel?.channelId == channelId {
                print("same channelId as before")
                return false
            }
            print("has new channelId:", channelId)
            parent.browserManager.setFoundInfo(ChannelInfo(channelId: channelId))
            return true
        }

        func handleHasNewUserName(_ url: URL) -> Bool {
            let userName = UrlService.getChannelUserNameFromUrl(
                url: url,
                previousUserName: parent.browserManager.desktopUserName
            )
            guard let userName = userName else {
                parent.browserManager.clearInfo()
                print("no user name found")
                return false
            }
            if [parent.browserManager.channel?.userName, parent.browserManager.desktopUserName].contains(userName) {
                print("same username as before")
                return false
            }
            parent.browserManager.desktopUserName = userName
            return true
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

        var getSubscriptionInfoScript =
            """
            var channelId = document.querySelector('meta[itemprop="identifier"]')?.getAttribute('content');
            var description = document.querySelector('meta[name="description"]')?.getAttribute('content');
            var rssFeed = document
                .querySelector('link[rel="alternate"][type="application/rss+xml"]')
                ?.getAttribute('href');
            var title = document.querySelector('meta[property="og:title"]')?.getAttribute('content');
            var image = document.querySelector('link[rel="image_src"]')?.getAttribute('href');
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
        .environment(RefreshManager())
}
