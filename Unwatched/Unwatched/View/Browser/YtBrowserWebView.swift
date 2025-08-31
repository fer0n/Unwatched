//
//  FixSubscriptionsView.swift
//  Unwatched
//

import SwiftUI
import WebKit
import OSLog
import UnwatchedShared

// swiftlint:disable:next type_body_length
struct YtBrowserWebView: PlatformViewRepresentable {
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.playBrowserVideosInApp) var playBrowserVideosInApp: Bool = false
    @CloudStorage(Const.defaultShortsSetting) var defaultShortsSetting: ShortsSetting = .show

    @Environment(PlayerManager.self) var player
    @Environment(NavigationManager.self) var navManager

    @Binding var url: BrowserUrl?
    @Binding var appNotificationVM: AppNotificationVM

    var startUrl: BrowserUrl?
    var onDismiss: (() -> Void)?
    @Binding var browserManager: BrowserManager

    init(
        url: Binding<BrowserUrl?> = .constant(
            nil
        ),
        startUrl: BrowserUrl? = nil,
        browserManager: Binding<BrowserManager>,
        appNotificationVM: Binding<AppNotificationVM>,
        onDismiss: (() -> Void)? = nil
    ) {
        self._url = url
        self.startUrl = startUrl
        if startUrl == nil {
            self.startUrl = url.wrappedValue
        }
        self._browserManager = browserManager
        self._appNotificationVM = appNotificationVM
        self.onDismiss = onDismiss
    }

    func makeView(_ coordinator: Coordinator) -> WKWebView {
        let webViewConfig = WKWebViewConfiguration()
        webViewConfig.mediaTypesRequiringUserActionForPlayback = [.all]

        #if os(iOS)
        webViewConfig.allowsPictureInPictureMediaPlayback = true
        webViewConfig.allowsInlineMediaPlayback = !playVideoFullscreen
        #endif

        let webView = WKWebView(frame: .zero, configuration: webViewConfig)
        webView.allowsBackForwardNavigationGestures = true
        webView.configuration.userContentController.add(coordinator, name: "iosListener")
        #if os(macOS)
        webView.configuration.userContentController.add(coordinator, name: "contextMenuListener")
        #endif
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator

        #if os(iOS)
        webView.backgroundColor = UIColor(Color.youtubeWebBackground)
        webView.isOpaque = false
        #endif

        coordinator.startObserving(webView: webView)
        if let requestUrl = (startUrl ?? url ?? BrowserUrl.youtubeStartPage).getUrl {
            let request = URLRequest(url: requestUrl)
            webView.load(request)
            url = nil
        }

        browserManager.webView = webView
        return webView

    }

    func updateView(_ view: WKWebView) {
        if url != nil, let requestUrl = url?.getUrl {
            let request = URLRequest(url: requestUrl)
            view.load(request)
            url = nil
        }
    }

    #if os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        makeView(context.coordinator)
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        updateView(view)
    }
    #elseif os(iOS)

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
//    BrowserView(url: .contant(BrowserUrl.youtubeStartPage))
//        .modelContainer(DataController.previewContainer)
//        .environment(RefreshManager())
// }
