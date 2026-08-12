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

@Observable class WebViewState {
    @MainActor static let shared = WebViewState()

    @ObservationIgnored var webView: WKWebView?
}

struct PlayerWebView: PlatformViewRepresentable {
    @Environment(PlayerManager.self) var player
    @Environment(AppNotificationVM.self) var appNotificationVM

    @Binding var overlayVM: OverlayFullscreenVM
    @Binding var autoHideVM: AutoHideVM

    let onVideoEnded: () -> Void
    var handleSwipe: (SwipeDirecton) -> Void

    @State var webViewState = WebViewState.shared
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
        if let warmed = WebPlayerWarmup.shared.takeWebView(for: player.video?.youtubeId) {
            return adopt(warmed, coordinator)
        }

        let webView = PlayerWebView.buildWebView(airplayHD: player.airplayHD)
        webViewState.webView = webView

        player.isLoading = Date()
        player.previousState.videoId = player.video?.youtubeId
        player.previousState.playbackSpeed = player.playbackSpeed

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

    func updateView(_ view: WKWebView, _ coordinator: PlayerWebViewCoordinator) {
        #if os(macOS)
        handleShouldStop(view)
        #endif

        if player.isLoading != nil {
            // avoid setting anything before the player is ready
            Log.info("video not loaded yet – cancelling updateUIView")
            return
        }

        handleUIMode(view, coordinator)
        let prev = player.previousState
        handlePlaybackSpeed(prev, view)
        handlePlayPause(prev, view)
        handlePip(prev, view)
        handleSeek(prev, view)
        handleQueueVideo(prev, view)
        setChapterMarkers()
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

    /// Releases the shared reference when this web view leaves the hierarchy (player type
    /// switched, player reloaded). Without it a detached web view stays reachable for the rest
    /// of the app run, and `repairVideo` keeps probing its `<video>` — which reads
    /// `readyState === 0` once detached and reloads the player on every foregrounding.
    ///
    /// Identity-checked because a reload dismantles the old view around the time the new one is
    /// made, and the order isn't guaranteed; only the instance still on file may clear it.
    static func dismantleView(_ view: WKWebView) {
        guard WebViewState.shared.webView === view else { return }
        WebViewState.shared.webView = nil
    }

    #if os(macOS)
    static func dismantleNSView(_ view: WKWebView, coordinator: PlayerWebViewCoordinator) {
        dismantleView(view)
    }
    #elseif os(iOS) || os(visionOS)
    static func dismantleUIView(_ view: WKWebView, coordinator: PlayerWebViewCoordinator) {
        dismantleView(view)
    }
    #endif

    func evaluateJavaScript(_ view: WKWebView, _ script: String) {
        PlayerWebView.evaluateJavaScript(view, script)
    }

    static func evaluateJavaScript(_ view: WKWebView, _ script: String) {
        view.evaluateJavaScript(script + " undefined;", completionHandler: handleJsError)
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

    func setChapterMarkers(awaitHash: Bool = true) {
        let prev = player.previousState
        if awaitHash && prev.chaptersHash == nil {
            return
        }
        guard let video = player.video,
              prev.videoId == player.video?.youtubeId else {
            return
        }
        let hash = ChapterService.getChaptersHash(
            from: video.sortedChapters, duration: video.duration
        )
        player.previousState.chaptersHash = hash
        if prev.chaptersHash == hash {
            return
        }
        if let chapters = player.video?.sortedChapters,
           let view = webViewState.webView {
            Log.info("CHAPTERMARKERS")
            let enableLogging = UserDefaults.standard.bool(forKey: Const.enableLogging)
            let script = PlayerWebView.setChapterMarkersScript(
                chapters: chapters,
                videoDuration: player.video?.duration ?? 0,
                enableLogging: enableLogging
            )
            evaluateJavaScript(view, script)
        }
    }

    func handleShouldStop(_ view: WKWebView) {
        // workaround: reload otherwise keeps old audio playing in the background
        if player.shouldStop {
            Log.info("STOP")
            view.pauseAllMediaPlayback()
            player.shouldStop = false
        }
    }

    /// Switches the player variant without touching playback: they all run this same page.
    func handleUIMode(_ uiView: WKWebView, _ coordinator: PlayerWebViewCoordinator) {
        let mode = uiMode
        guard coordinator.appliedUIMode != mode else {
            return
        }
        Log.info("UI MODE: \(mode)")
        coordinator.appliedUIMode = mode
        evaluateJavaScript(uiView, PlayerWebView.applyUIModeScript(mode))
    }

    func handlePlaybackSpeed(_ prev: PreviousState, _ uiView: WKWebView) {
        if prev.playbackSpeed != player.playbackSpeed {
            Log.info("SPEED")
            evaluateJavaScript(uiView, getSetPlaybackRateScript())
            player.previousState.playbackSpeed = player.playbackSpeed
        }
    }

    func handlePlayPause(_ prev: PreviousState, _ uiView: WKWebView) {
        if prev.isPlaying != player.isPlaying {
            if player.isPlaying {
                Log.info("PLAY")
                evaluateJavaScript(uiView, getPlayScript())
            } else {
                Log.info("PAUSE")
                evaluateJavaScript(uiView, getPauseScript())
            }
            player.previousState.isPlaying = player.isPlaying
        }
    }

    func handlePip(_ prev: PreviousState, _ uiView: WKWebView) {
        if prev.pipEnabled != player.pipEnabled && player.canPlayPip {
            if player.pipEnabled {
                evaluateJavaScript(uiView, getEnterPipScript())
            } else {
                Log.info("PIP OFF")
                evaluateJavaScript(uiView, getExitPipScript())
            }
            if !player.pipEnabled {
                player.previousState.pipEnabled = false
            }
        }
    }

    func handleSeek(_ prev: PreviousState, _ uiView: WKWebView) {
        if let seekAbs = player.seekAbsolute {
            Log.info("SEEK ABS")
            evaluateJavaScript(uiView, getSeekToScript(seekAbs))
            player.seekAbsolute = nil
        }

    }

    func handleQueueVideo(_ prev: PreviousState, _ uiView: WKWebView) {
        if prev.videoId != player.video?.youtubeId {
            Log.info("CUE VIDEO: \(player.video?.title ?? "-")")
            let startAt = player.getStartPosition()

            let success = loadPlayer(webView: uiView, startAt: startAt, type: playerType)
            if success {
                player.previousState.videoId = player.video?.youtubeId
            }
        }
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
