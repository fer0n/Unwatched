//
//  FixSubscriptionsView.swift
//  Unwatched
//

import SwiftUI
import WebKit
import OSLog
import UnwatchedShared

extension YtBrowserWebView {
    // swiftlint:disable:next type_body_length
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        // MARK: - Properties
        var parent: YtBrowserWebView
        var observation: NSKeyValueObservation?
        var isFirstLoad = true

        #if os(macOS)
        private var contextMenuUrl: URL?
        #endif

        // MARK: - Lifecycle

        init(_ parent: YtBrowserWebView) {
            self.parent = parent
        }

        deinit {
            observation?.invalidate()
            observation = nil
        }

        func startObserving(webView: WKWebView) {
            observation = webView.observe(\.url, options: .new) { (webView, _) in
                Task { @MainActor in
                    self.handleUrlChange(webView)
                }
            }
        }

        // MARK: - WKNavigationDelegate

        @MainActor func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Log.info("--- new page loaded")
            if isFirstLoad {
                isFirstLoad = false
                parent.browserManager.firstPageLoaded = true

                #if os(macOS)
                setupMacOSContextMenu(webView)
                #endif
            }
            guard let url = webView.url else {
                Log.warning("no url found")
                return
            }

            // Apply settings and inject scripts
            applySettingsToWebView(webView)

            // Extract subscription information if available
            Log.info("about to extract info")
            let info = getInfoFromUrl(url)
            if info.userName != nil || info.channelId != nil || info.playlistId != nil {
                // is username page, reload the page
                extractSubscriptionInfo(webView, info)
            }
        }

        // MARK: - Script Message Handler

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            if message.name == "iosListener" {
                handleVideoLinkMessage(message)
            }
            #if os(macOS)
            if message.name == "contextMenuListener" {
                handleContextMenuMessage(message)
            }
            #endif
        }

        private func handleVideoLinkMessage(_ message: WKScriptMessage) {
            Log.info("Intercepted video click: \(message.body)")
            Signal.log("Browser.VideoLinkIntercepted")

            guard let bodyString = message.body as? String,
                  let data = bodyString.data(using: .utf8),
                  let clickData = try? JSONDecoder().decode(VideoClickData.self, from: data) else {
                Log.warning("Failed to decode message body")
                return
            }

            guard let url = URL(string: clickData.url) else {
                Log.warning("no url found")
                return
            }
            let task = VideoService.addForeignUrls(
                [url],
                in: .queue,
                at: 0
            )
            Task {
                try? await task.value
                parent.player.loadTopmostVideoFromQueue(
                    source: .userInteraction,
                    playIfCurrent: true
                )
                if let videoDuration = parent.player.video?.duration {
                    // Try to find a video with a matching duration, best way I could find
                    // to match the clicked video with the one that has auto played partially
                    for state in clickData.videos where (
                        state.duration >= videoDuration - 1
                            && state.duration <= videoDuration) {
                        parent.player.video?.elapsedSeconds = state.currentTime
                        parent.player.currentTime = state.currentTime
                        break
                    }
                }
                parent.navManager.handlePlay()
                parent.onDismiss?()
            }
        }

        #if os(macOS)
        private func handleContextMenuMessage(_ message: WKScriptMessage) {
            guard let dict = message.body as? [String: Any],
                  let urlString = dict["url"] as? String,
                  let url = URL(string: urlString),
                  let xPos = dict["x"] as? Double,
                  let yPos = dict["y"] as? Double else {
                return
            }

            // Convert web coordinates to view coordinates
            Task { @MainActor in
                if let webView = message.webView {
                    let point = NSPoint(x: xPos, y: yPos)
                    self.showContextMenu(for: url, at: point, in: webView)
                }
            }
        }
        #endif

        // MARK: - JavaScript Injection

        private func applySettingsToWebView(_ webView: WKWebView) {
            if parent.defaultShortsSetting == .hide {
                injectHideShortsCSS(webView)
            }

            if parent.playBrowserVideosInApp {
                injectVideoInterceptionScript(webView)
            }
        }

        func injectVideoInterceptionScript(_ webView: WKWebView) {
            let script = """
                (function() {
                    document.addEventListener('click', function(e) {
                        const videoLink = e.target.closest('a[href*="/watch?v="]')?.href;
                        if (videoLink) {
                            e.preventDefault();
                            e.stopPropagation();

                            const videos = Array.from(document.querySelectorAll('video'));
                            const videoStates = videos
                                .filter(v => v.duration)
                                .map(v => ({
                                    duration: v.duration,
                                    currentTime: v.currentTime
                                }));

                            window.webkit.messageHandlers.iosListener.postMessage(
                                JSON.stringify({
                                    url: videoLink,
                                    videos: videoStates
                                })
                            );
                        }
                    }, true);
                })();
                """
            webView.evaluateJavaScript(script + " undefined;")
        }

        func injectHideShortsCSS(_ webView: WKWebView) {
            let script = """
            (function() {
                var style = document.createElement('style');
                style.textContent = `
                    .rich-section-content:has(.shortsLockupViewModelHost),
                    .reel-shelf-items {
                        display: none !important;
                    }
                `
                document.head.appendChild(style);
            })();
            """
            webView.evaluateJavaScript(script) { (_, error) in
                if let error {
                    Log.error("Failed to inject CSS: \(error)")
                } else {
                    Log.info("Successfully injected CSS to hide Shorts")
                }
            }
        }

        // MARK: - URL Handling & Subscription Info

        @MainActor
        func handleUrlChange(_ webView: WKWebView) {
            guard let url = webView.url else {
                Log.warning("no url found")
                return
            }
            Log.info("URL changed: \(url)")
            handleIsMobilePage(url)
            handleCurrentUrl(url)

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

            Log.info("--- forceReloadUrl")
            let request = URLRequest(url: url)
            webView.load(request)
        }

        func handleCurrentUrl(_ url: URL) {
            parent.browserManager.isVideoUrl = UrlService.getYoutubeIdFromUrl(url: url) != nil
        }

        func handleIsMobilePage(_ url: URL) {
            parent.browserManager.isMobileVersion = UrlService.isMobileYoutubePage(url)
        }

        func getNewPlaylistId(_ url: URL) -> String? {
            guard let playlistId = UrlService.getPlaylistIdFromUrl(url) else {
                Log.info("no channel id")
                return nil
            }
            if parent.browserManager.info?.playlistId == playlistId {
                Log.info("same playlistId as before")
                return nil
            }
            Log.info("has new playlistId: \(playlistId)")
            return playlistId
        }

        func handleHasNewChannelId(_ url: URL) -> Bool {
            guard let channelId = UrlService.getChannelIdFromUrl(url) else {
                Log.info("no channel id")
                return false
            }
            if parent.browserManager.info?.channelId == channelId {
                Log.info("same channelId as before")
                return false
            }
            Log.info("has new channelId: \(channelId)")
            parent.browserManager.setFoundInfo(SubscriptionInfo(channelId: channelId))
            return true
        }

        func handleHasNewUserName(_ url: URL) -> Bool {
            let userName = UrlService.getChannelUserNameFromUrl(
                url,
                previousUserName: parent.browserManager.desktopUserName
            )
            guard let userName else {
                parent.browserManager.clearInfo()
                Log.info("no user name found")
                return false
            }
            if [parent.browserManager.info?.userName?.lowercased(), parent.browserManager.desktopUserName?.lowercased()]
                .contains(userName.lowercased()) {
                Log.info("same username as before")
                return false
            }
            parent.browserManager.desktopUserName = userName
            return true
        }

        func getInfoFromUrl(_ url: URL) -> SubscriptionInfo {
            let previousUsername = parent.browserManager.desktopUserName
            var info = SubscriptionInfo(url)
            if let userName = UrlService.getChannelUserNameFromUrl(
                url,
                previousUserName: previousUsername
            ) {
                info.userName = userName
                return info
            }
            if let channelId = UrlService.getChannelIdFromUrl(url) {
                info.channelId = channelId
                return info
            }
            if let playlistId = UrlService.getPlaylistIdFromUrl(url) {
                info.playlistId = playlistId
                return info
            }
            return info
        }

        @MainActor func extractSubscriptionInfo(_ webView: WKWebView, _ info: SubscriptionInfo) {
            Log.info("extractSubscriptionInfo")
            let url = webView.url
            webView.evaluateJavaScript(getSubscriptionInfoScript) { (result, error) in
                if let error = error {
                    Log.error("JavaScript evaluation error: \(error)")
                } else if let array = result as? [String] {
                    let pageChannelId = array[0]
                    let description = array[1]
                    let rssFeed = array[2]
                    let title = array[3]
                    let imageUrl = array[4]
                    let id = info.channelId ?? pageChannelId
                    Log.info("Channel ID: \(id)")
                    Log.info("Description: \(description)")
                    Log.info("RSS Feed: \(rssFeed)")
                    Log.info("Title: \(title)")
                    Log.info("Image: \(imageUrl)")
                    self.parent.browserManager.setFoundInfo(SubscriptionInfo(
                        url, id, description, rssFeed, title, info.userName, info.playlistId, imageUrl
                    ))
                } else {
                    Log.warning("no result received: \(result.debugDescription)")
                }
                self.parent.browserManager.hasCheckedInfo = true
            }
        }

        // MARK: - Common Context Menu Logic

        /// Handle subscription action
        @MainActor
        func handleSubscribeAction(info: SubscriptionInfo) {
            self.parent.appNotificationVM.show(.loading)
            Task {
                do {
                    try await SubscriptionService.addSubscription(subscriptionInfo: info)
                    await MainActor.run {
                        self.parent.appNotificationVM.show(.success)
                    }
                } catch {
                    await MainActor.run {
                        self.parent.appNotificationVM.show(.error(error))
                    }
                    Log.error("Failed to add subscription: \(error)")
                }
            }
            Signal.log("Browser.ContextMenu.Subscribe")
        }

        /// Handle queue next action
        @MainActor
        func handleQueueNextAction(url: URL) {
            self.parent.appNotificationVM.show(.loading)
            let task = VideoService.addForeignUrls([url], in: .queue, at: 1)
            Task {
                do {
                    try await task.value
                    await MainActor.run {
                        self.parent.appNotificationVM.show(.success)
                    }
                } catch {
                    await MainActor.run {
                        self.parent.appNotificationVM.show(.error(error))
                    }
                }
            }
            Signal.log("Browser.ContextMenu.QueueNext")
        }

        /// Handle add to inbox action
        @MainActor
        func handleAddToInboxAction(url: URL) {
            self.parent.appNotificationVM.show(.loading)
            let task = VideoService.addForeignUrls([url], in: .inbox)
            Task {
                do {
                    try await task.value
                    await MainActor.run {
                        self.parent.appNotificationVM.show(.success)
                    }
                } catch {
                    await MainActor.run {
                        self.parent.appNotificationVM.show(.error(error))
                    }
                }
            }
            Signal.log("Browser.ContextMenu.AddToInbox")
        }

        // MARK: - Context Menu Handling (iOS)
        #if os(iOS)
        @MainActor
        func webView(
            _ webView: WKWebView,
            contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
            completionHandler: @escaping @MainActor (UIContextMenuConfiguration?) -> Void
        ) {
            // Only customize URL context menus
            guard let url = elementInfo.linkURL else {
                completionHandler(nil)
                return
            }

            let identifier = "YtBrowserLinkContextMenu" as NSString
            let info = self.getInfoFromUrl(url)
            let actions = ContextMenuAction.getActionsForUrl(url, info: info)

            let configuration = UIContextMenuConfiguration(identifier: identifier, previewProvider: nil) { _ in
                // Group actions by type
                var basicActions: [UIAction] = []
                var channelActions: [UIAction] = []
                var videoActions: [UIAction] = []

                // Create menu actions based on available actions
                for action in actions {
                    let uiAction = UIAction(title: action.title, image: UIImage(systemName: action.imageName)) { _ in
                        switch action.type {
                        case .openInBrowser:
                            webView.load(URLRequest(url: url))
                        case .copyUrl:
                            ClipboardService.set(url.absoluteString)
                        case .subscribe:
                            self.handleSubscribeAction(info: info)
                        case .queueNext:
                            self.handleQueueNextAction(url: url)
                        case .addToInbox:
                            self.handleAddToInboxAction(url: url)
                        }
                    }

                    // Add to appropriate group using the action.group property
                    switch action.group {
                    case .basic:
                        basicActions.append(uiAction)
                    case .channel:
                        channelActions.append(uiAction)
                    case .video:
                        videoActions.append(uiAction)
                    }
                }

                // Create submenu sections with appropriate separators
                var menuElements: [UIMenuElement] = []

                if !basicActions.isEmpty {
                    menuElements.append(UIMenu(title: "", options: .displayInline, children: basicActions))
                }

                if !channelActions.isEmpty {
                    menuElements.append(UIMenu(title: "", options: .displayInline, children: channelActions))
                }

                if !videoActions.isEmpty {
                    menuElements.append(UIMenu(title: "", options: .displayInline, children: videoActions))
                }

                return UIMenu(title: "", children: menuElements)
            }

            completionHandler(configuration)
        }
        #endif

        // MARK: - Context Menu Handling (macOS)
        #if os(macOS)
        func setupMacOSContextMenu(_ webView: WKWebView) {
            // Inject JavaScript to detect right-clicks on links
            let script = """
                document.addEventListener('contextmenu', function(e) {
                    const link = e.target.closest('a');
                    if (link && link.href) {
                        e.preventDefault();
                        window.webkit.messageHandlers.contextMenuListener.postMessage({
                            url: link.href,
                            x: e.clientX,
                            y: e.clientY
                        });
                    }
                });
            """
            webView.evaluateJavaScript(script + " undefined;")
        }

        @MainActor
        func showContextMenu(for url: URL, at point: NSPoint, in view: NSView) {
            let menu = NSMenu()
            let info = self.getInfoFromUrl(url)
            let actions = ContextMenuAction.getActionsForUrl(url, info: info)

            var lastGroup: ContextMenuAction.ActionGroup?

            // Create menu items based on available actions
            for action in actions {
                // Add separators when the group changes
                if let lastGroup = lastGroup, lastGroup != action.group {
                    menu.addItem(NSMenuItem.separator())
                }

                // Update the last group
                lastGroup = action.group

                // Create and add menu item
                let menuItem = NSMenuItem(
                    title: action.title,
                    action: nil,
                    keyEquivalent: ""
                )
                menuItem.image = NSImage(systemSymbolName: action.imageName, accessibilityDescription: nil)

                switch action.type {
                case .openInBrowser:
                    menuItem.action = #selector(openInExternalBrowser(_:))
                    menuItem.representedObject = url
                case .copyUrl:
                    menuItem.action = #selector(copyUrl(_:))
                    menuItem.representedObject = url
                case .subscribe:
                    menuItem.action = #selector(subscribe(_:))
                    menuItem.representedObject = info
                case .queueNext:
                    menuItem.action = #selector(queueNext(_:))
                    menuItem.representedObject = url
                case .addToInbox:
                    menuItem.action = #selector(addToInbox(_:))
                    menuItem.representedObject = url
                }

                menuItem.target = self
                menu.addItem(menuItem)
            }

            menu.popUp(positioning: nil, at: point, in: view)
        }

        // Context Menu Actions
        @objc private func openInExternalBrowser(_ sender: NSMenuItem) {
            guard let url = sender.representedObject as? URL else { return }
            NSWorkspace.shared.open(url)
        }

        @objc private func copyUrl(_ sender: NSMenuItem) {
            guard let url = sender.representedObject as? URL else { return }
            ClipboardService.set(url.absoluteString)
        }

        @objc private func subscribe(_ sender: NSMenuItem) {
            guard let info = sender.representedObject as? SubscriptionInfo else { return }
            handleSubscribeAction(info: info)
        }

        @objc private func queueNext(_ sender: NSMenuItem) {
            guard let url = sender.representedObject as? URL else { return }
            handleQueueNextAction(url: url)
        }

        @objc private func addToInbox(_ sender: NSMenuItem) {
            guard let url = sender.representedObject as? URL else { return }
            handleAddToInboxAction(url: url)
        }
        #endif

        // MARK: - Helper Properties and Methods

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

struct VideoClickData: Codable {
    struct VideoState: Codable {
        let duration: Double
        let currentTime: Double
    }
    let url: String
    let videos: [VideoState]
}

// #Preview {
//    BrowserView(url: .contant(BrowserUrl.youtubeStartPage))
//        .modelContainer(DataController.previewContainer)
//        .environment(RefreshManager())
// }
