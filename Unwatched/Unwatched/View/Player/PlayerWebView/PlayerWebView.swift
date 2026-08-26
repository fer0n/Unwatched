//
//  PlayerWebView.swift
//  Unwatched
//

import SwiftUI
import WebKit
import OSLog
import UnwatchedShared

#if os(iOS) || os(visionOS)
typealias PlatformViewRepresentable = UIViewRepresentable
#elseif os(macOS)
typealias PlatformViewRepresentable = NSViewRepresentable
#endif

struct PlayerWebView: PlatformViewRepresentable {
    @Environment(PlayerManager.self) var player
    @Environment(AppNotificationVM.self) var appNotificationVM

    @Binding var overlayVM: OverlayFullscreenVM
    @Binding var autoHideVM: AutoHideVM

    let onVideoEnded: () -> Void
    var handleSwipe: (SwipeDirecton) -> Void

    @State var backend = WebPlayerBackend.shared
    @State var switchManager = PlayerSwitchManager.shared

    /// The variant on screen, which lags the setting while a switch to the native player warms up.
    var playerTypeSetting: PlayerTypeSetting {
        switchManager.activeType
    }

    var playerType: PlayerType {
        playerTypeSetting.webPlayerType(embeddingDisabled: player.embeddingDisabled)
    }

    var uiMode: UIMode {
        UIMode.forSetting(playerTypeSetting, embeddingDisabled: player.embeddingDisabled)
    }

    func makeView(_ coordinator: PlayerWebViewCoordinator) -> WKWebView {
        if let warmed = WebPlayerWarmup.shared.takeWebView(for: player.video?.youtubeId, type: playerType) {
            return adopt(warmed, coordinator)
        }

        let webView = PlayerWebView.buildWebView(airplayHD: player.airplayHD)
        backend.resetAppliedState()
        backend.webView = webView

        player.isLoading = Date()
        backend.loadedVideoId = player.video?.youtubeId

        attach(coordinator, to: webView)
        loadWebContent(webView)
        return webView
    }

    @MainActor
    static func buildWebView(airplayHD: Bool) -> WKWebView {
        let webViewConfig = WKWebViewConfiguration()
        webViewConfig.preferences.isTextInteractionEnabled = false
        webViewConfig.mediaTypesRequiringUserActionForPlayback = [.all]

        #if os(iOS) || os(visionOS)
        webViewConfig.allowsPictureInPictureMediaPlayback = true
        webViewConfig.allowsInlineMediaPlayback = !(Const.playVideoFullscreen.bool ?? false)

        // runs before YouTube's own scripts, so it can override how the page perceives
        // its own visibility before anything reads/listens to it
        if Const.backgroundPlayback.bool ?? true {
            let visibilityScript = WKUserScript(
                source: PlayerWebView.blockVisibilityChangeScript(),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            webViewConfig.userContentController.addUserScript(visibilityScript)
        }
        #endif

        let webView = WKWebView(frame: .zero, configuration: webViewConfig)

        #if os(iOS)
        // on visionOS, this causes the web content to be zoomed in to much
        // when the window is large enough during page reload
        webView.backgroundColor = UIColor.systemBackground
        #endif

        #if os(iOS) || os(visionOS)
        webView.isOpaque = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        #else
        webView.underPageBackgroundColor = NSColor.backgroundGray
        #endif

        #if os(iOS)
        let userAgent = webView.value(forKey: "userAgent") as? String
        if airplayHD {
            let newAgent = customAirPlayCompatibilityUserAgent(userAgent)
            webView.customUserAgent = newAgent
        } else if Device.requiresFullscreenWebWorkaround {
            if let userAgent {
                // workaround: fix "fullscreen" button being blocked on the iPad
                let modifiedUserAgent = userAgent.replacing("iPad", with: "iPhone")
                webView.customUserAgent = modifiedUserAgent
            }
        }
        #endif

        return webView
    }

    /// Playback commands don't come through here: `PlayerManager` calls `WebPlayerBackend` directly, so a command
    /// lands once, in order, whether or not this view is on screen.
    func updateView(_ view: WKWebView, _ coordinator: PlayerWebViewCoordinator) {
        backend.reclaim(view)
        backend.applyUIMode(uiMode)
    }

    #if os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        makeView(context.coordinator)
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        updateView(view, context.coordinator)
    }
    #elseif os(iOS) || os(visionOS)

    func makeUIView(context: Context) -> WKWebView {
        makeView(context.coordinator)
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        updateView(view, context.coordinator)
    }
    #endif

    /// Releases the shared reference when this web view leaves the hierarchy (player type switched, player reloaded).
    static func dismantleView(_ view: WKWebView, _ coordinator: PlayerWebViewCoordinator) {
        // its page is on its way out: late navigation callbacks must not be taken for the live player's, least of all
        // the auto-start, which only ever fires once
        coordinator.retire()
        // otherwise the page plays on unseen once the view is gone, e.g.
        view.pauseAllMediaPlayback()
        guard WebPlayerBackend.shared.webView === view else { return }
        WebPlayerBackend.shared.webView = nil
        WebPlayerBackend.shared.resetAppliedState()
    }

    #if os(macOS)
    static func dismantleNSView(_ view: WKWebView, coordinator: PlayerWebViewCoordinator) {
        dismantleView(view, coordinator)
    }
    #elseif os(iOS) || os(visionOS)
    static func dismantleUIView(_ view: WKWebView, coordinator: PlayerWebViewCoordinator) {
        dismantleView(view, coordinator)
    }
    #endif

    func evaluateJavaScript(_ view: WKWebView, _ script: String) {
        PlayerWebView.evaluateJavaScript(view, script)
    }

    static func evaluateJavaScript(_ view: WKWebView, _ script: String) {
        view.evaluateJavaScript(script + " undefined;", completionHandler: handleJsError)
    }

    /// Whether the page is *not* playing — a page with no media element yet counts, which is the case a
    /// `!!video?.paused` test gets wrong: it reads `false` for "no element" and so looks exactly like "playing".
    @MainActor
    static func evaluateIsNotPlaying(_ view: WKWebView) async -> Bool {
        await evaluateBool(view, "(() => { const v = document.querySelector('video'); return !v || v.paused; })()")
    }

    @MainActor
    static func evaluateBool(_ view: WKWebView, _ script: String) async -> Bool {
        let result = try? await view.evaluateJavaScript(script)
        return (result as? Bool) ?? false
    }

    static func handleJsError(result: Any?, _ error: (any Error)?) {
        guard let error else { return }
        Log.error("Error evaluating JavaScript: \(error)")
    }

    @MainActor
    func loadWebContent(_ webView: WKWebView) {
        let startAt = player.getStartPosition()
        _ = loadPlayer(webView: webView, startAt: startAt, type: playerType)
    }

    func makeCoordinator() -> PlayerWebViewCoordinator {
        PlayerWebViewCoordinator(self)
    }

    static func customAirPlayCompatibilityUserAgent(_ userAgent: String?) -> String {
        // user agent:
        // Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Mobile/15E148 Safari/604.1
        // ---
        // user agent request desktop:
        // Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15

        var osVersion = "18_3"
        var webKitVersion = "605.1.15"

        if let userAgent = userAgent {
            if let range = userAgent.range(of: "AppleWebKit/") {
                let webKitVersionStart = userAgent[range.upperBound...]
                if let endRange = webKitVersionStart.range(of: " ") {
                    webKitVersion = String(webKitVersionStart[..<endRange.lowerBound])
                }
            }
            if let range = userAgent.range(of: "OS ") {
                let osVersionStart = userAgent[range.upperBound...]
                if let endRange = osVersionStart.range(of: " ") {
                    osVersion = String(osVersionStart[..<endRange.lowerBound])
                }
            }
        }

        // swiftlint:disable:next line_length
        return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/\(webKitVersion) (KHTML, like Gecko) Version/\(osVersion.replacing("_", with: ".")) Safari/\(webKitVersion)"
    }
}

#Preview {
    let video = Video.getDummy()
    let player = PlayerManager()
    player.video = video

    return (
        PlayerWebView(
            overlayVM: .constant(OverlayFullscreenVM.shared),
            autoHideVM: .constant(AutoHideVM()),
            onVideoEnded: {

            },
            handleSwipe: { _ in

            })
            .environment(player)
            .modelContainer(DataProvider.previewContainerFilled)
    )
}
