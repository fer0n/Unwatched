//
//  FixSubscriptionsView.swift
//  Unwatched
//

import SwiftUI
import WebKit
import OSLog
import UnwatchedShared

struct YtBrowserWebView: UIViewRepresentable {
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false

    @Binding var url: BrowserUrl?
    var startUrl: BrowserUrl?
    var browserManager: BrowserManager

    init(url: Binding<BrowserUrl?> = .constant(nil), startUrl: BrowserUrl? = nil, browserManager: BrowserManager) {
        self._url = url
        self.startUrl = startUrl
        if startUrl == nil {
            self.startUrl = url.wrappedValue
        }
        self.browserManager = browserManager
    }

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
        if let requestUrl = (startUrl ?? url ?? BrowserUrl.youtubeStartPage).getUrl {
            let request = URLRequest(url: requestUrl)
            webView.load(request)
            url = nil
        }
        return webView

    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if url != nil, let requestUrl = url?.getUrl {
            let request = URLRequest(url: requestUrl)
            uiView.load(request)
            url = nil
        }
    }

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
            observation?.invalidate()
            observation = nil
        }

        @MainActor func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Logger.log.info("--- new page loaded")
            if isFirstLoad {
                isFirstLoad = false
                parent.browserManager.firstPageLoaded = true
            }
            guard let url = webView.url else {
                Logger.log.warning("no url found")
                return
            }

            Logger.log.info("about to extract info")
            let info = getInfoFromUrl(url)
            if info.userName != nil || info.channelId != nil || info.playlistId != nil {
                // is username page, reload the page
                extractSubscriptionInfo(webView, info)
            }
        }

        func getInfoFromUrl(_ url: URL) -> SubscriptionInfo {
            let previousUsername = parent.browserManager.desktopUserName
            if let userName = UrlService.getChannelUserNameFromUrl(
                url,
                previousUserName: previousUsername
            ) {
                return SubscriptionInfo(userName: userName)
            }
            if let channelId = UrlService.getChannelIdFromUrl(url) {
                return SubscriptionInfo(channelId: channelId)
            }
            if let playlistId = UrlService.getPlaylistIdFromUrl(url) {
                return SubscriptionInfo(playlistId: playlistId)
            }
            return SubscriptionInfo()
        }

        @MainActor func extractSubscriptionInfo(_ webView: WKWebView, _ info: SubscriptionInfo) {
            Logger.log.info("extractSubscriptionInfo")
            let url = webView.url
            webView.evaluateJavaScript(getSubscriptionInfoScript) { (result, error) in
                if let error = error {
                    Logger.log.error("JavaScript evaluation error: \(error)")
                } else if let array = result as? [String] {
                    let pageChannelId = array[0]
                    let description = array[1]
                    let rssFeed = array[2]
                    let title = array[3]
                    let imageUrl = array[4]
                    let id = info.channelId ?? pageChannelId
                    Logger.log.info("Channel ID: \(id)")
                    Logger.log.info("Description: \(description)")
                    Logger.log.info("RSS Feed: \(rssFeed)")
                    Logger.log.info("Title: \(title)")
                    Logger.log.info("Image: \(imageUrl)")
                    self.parent.browserManager.setFoundInfo(SubscriptionInfo(
                        url, id, description, rssFeed, title, info.userName, info.playlistId, imageUrl
                    ))
                } else {
                    Logger.log.warning("no result received: \(result.debugDescription)")
                }
            }
        }

        @MainActor
        func handleUrlChange(_ webView: WKWebView) {
            guard let url = webView.url else {
                Logger.log.warning("no url found")
                return
            }
            Logger.log.info("URL changed: \(url)")
            handleIsMobilePage(url)
            handleVideoUrl(url)

            if isFirstLoad { return }

            let hasNewUserName = handleHasNewUserName(url)
            let hasNewChannelId = handleHasNewChannelId(url)
            let newPlaylistId = getNewPlaylistId(url)

            if let playlistId = newPlaylistId {
                // does not require a force reload
                extractSubscriptionInfo(webView, SubscriptionInfo(playlistId: playlistId))
                return
            }

            // && !hasNewPlaylistId reload necessary?
            if !hasNewUserName && !hasNewChannelId {
                return
            }

            Logger.log.info("--- forceReloadUrl")
            let request = URLRequest(url: url)
            webView.load(request)
        }

        func handleVideoUrl(_ url: URL) {
            parent.browserManager.videoUrl = url
        }

        func getNewPlaylistId(_ url: URL) -> String? {
            guard let playlistId = UrlService.getPlaylistIdFromUrl(url) else {
                Logger.log.info("no channel id")
                return nil
            }
            if parent.browserManager.info?.playlistId == playlistId {
                Logger.log.info("same playlistId as before")
                return nil
            }
            Logger.log.info("has new playlistId: \(playlistId)")
            return playlistId
        }

        func handleHasNewChannelId(_ url: URL) -> Bool {
            guard let channelId = UrlService.getChannelIdFromUrl(url) else {
                Logger.log.info("no channel id")
                return false
            }
            if parent.browserManager.info?.channelId == channelId {
                Logger.log.info("same channelId as before")
                return false
            }
            Logger.log.info("has new channelId: \(channelId)")
            parent.browserManager.setFoundInfo(SubscriptionInfo(channelId: channelId))
            return true
        }

        func handleHasNewUserName(_ url: URL) -> Bool {
            let userName = UrlService.getChannelUserNameFromUrl(
                url,
                previousUserName: parent.browserManager.desktopUserName
            )
            guard let userName = userName else {
                parent.browserManager.clearInfo()
                Logger.log.info("no user name found")
                return false
            }
            if [parent.browserManager.info?.userName?.lowercased(), parent.browserManager.desktopUserName?.lowercased()]
                .contains(userName.lowercased()) {
                Logger.log.info("same username as before")
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
    }
}

// #Preview {
//    BrowserView(url: .contant(BrowserUrl.youtubeStartPage))
//        .modelContainer(DataController.previewContainer)
//        .environment(RefreshManager())
// }
