//
//  FixSubscriptionsView.swift
//  Unwatched
//

import SwiftUI
import WebKit
import OSLog
import UnwatchedShared

struct YtBrowserWebView: PlatformViewRepresentable {
    @AppStorage(Const.playBrowserVideosInApp) var playBrowserVideosInApp: Bool = false
    @CloudStorage(Const.defaultShortsSetting) var defaultShortsSetting: ShortsSetting = .show

    @Environment(PlayerManager.self) var player
    @Environment(NavigationManager.self) var navManager
    @Environment(AppNotificationVM.self) var appNotificationVM

    var onDismiss: (() -> Void)?
    @Bindable var browserManager: BrowserManager

    init(
        browserManager: Bindable<BrowserManager>,
        onDismiss: (() -> Void)? = nil
    ) {
        self._browserManager = browserManager
        self.onDismiss = onDismiss
    }

    func makeView(_ coordinator: Coordinator) -> WKWebView {
        let webView: WKWebView

        if let existingWebView = browserManager.webView {
            webView = existingWebView
        } else {
            let webViewConfig = WKWebViewConfiguration()
            webViewConfig.mediaTypesRequiringUserActionForPlayback = [.all]

            #if os(iOS) || os(visionOS)
            webViewConfig.allowsPictureInPictureMediaPlayback = true
            webViewConfig.allowsInlineMediaPlayback = true
            #endif

            webView = WKWebView(frame: .zero, configuration: webViewConfig)
            webView.allowsBackForwardNavigationGestures = true

            if let requestUrl = (browserManager.currentBrowerUrl ?? BrowserUrl.youtubeStartPage).getUrl {
                let request = URLRequest(url: requestUrl)
                webView.load(request)
            }
            webView.configuration.userContentController.add(coordinator, name: "iosListener")
            #if os(macOS)
            webView.configuration.userContentController.add(coordinator, name: "contextMenuListener")
            #endif

            browserManager.webView = webView
        }
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator

        #if os(iOS) || os(visionOS)
        webView.backgroundColor = UIColor(Color.youtubeWebBackground)
        webView.isOpaque = false
        #endif

        coordinator.startObserving(webView: webView)

        return webView
    }

    func updateView(_ view: WKWebView) { }

    #if os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        makeView(context.coordinator)
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        updateView(view)
    }
    #elseif os(iOS) || os(visionOS)

    func makeUIView(context: Context) -> WKWebView {
        makeView(context.coordinator)
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        updateView(view)
    }
    #endif

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

// #Preview {
//    BrowserView(url: .constant(BrowserUrl.youtubeStartPage))
//        .modelContainer(DataController.previewContainer)
//        .environment(RefreshManager())
// }
