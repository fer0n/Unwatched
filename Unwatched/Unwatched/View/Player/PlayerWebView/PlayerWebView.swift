//
//  PlayerWebView.swift
//  Unwatched
//

import SwiftUI
import WebKit
import OSLog
import UnwatchedShared

#if os(iOS)
typealias PlatformViewRepresentable = UIViewRepresentable
#elseif os(macOS)
typealias PlatformViewRepresentable = NSViewRepresentable
#endif

struct PlayerWebView: PlatformViewRepresentable {
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.playbackSpeed) var playbackSpeed = 1.0
    // workaround: view doesn't update otherwise
    @Environment(PlayerManager.self) var player

    @Binding var overlayVM: OverlayFullscreenVM
    @Binding var autoHideVM: AutoHideVM
    @Binding var appNotificationVM: AppNotificationVM
    @Binding var deferVideoDate: IdentifiableDate?

    let playerType: PlayerType
    let onVideoEnded: () -> Void
    var setShowMenu: (() -> Void)?
    var handleSwipe: (SwipeDirecton) -> Void

    func makeView(_ coordinator: PlayerWebViewCoordinator) -> WKWebView {
        player.isLoading = true

        let webViewConfig = WKWebViewConfiguration()
        webViewConfig.preferences.isTextInteractionEnabled = false
        webViewConfig.mediaTypesRequiringUserActionForPlayback = [.all]

        #if os(iOS)
        webViewConfig.allowsPictureInPictureMediaPlayback = true
        webViewConfig.allowsInlineMediaPlayback = !playVideoFullscreen
        #endif

        player.previousState.videoId = player.video?.youtubeId
        player.previousState.playbackSpeed = player.playbackSpeed

        let webView = WKWebView(frame: .zero, configuration: webViewConfig)
        webView.navigationDelegate = coordinator
        webView.configuration.userContentController.add(coordinator, name: "iosListener")

        #if os(iOS)
        webView.backgroundColor = UIColor.systemBackground
        webView.isOpaque = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        #else
        webView.underPageBackgroundColor = NSColor.backgroundGray
        #endif

        let userAgent = webView.value(forKey: "userAgent") as? String
        if player.airplayHD {
            let newAgent = customAirPlayCompatibilityUserAgent(userAgent)
            webView.customUserAgent = newAgent
        } else if Device.requiresFullscreenWebWorkaround {
            if let userAgent {
                // workaround: fix "fullscreen" button being blocked on the iPad
                let modifiedUserAgent = userAgent.replacingOccurrences(of: "iPad", with: "iPhone")
                webView.customUserAgent = modifiedUserAgent
            }
        }

        loadWebContent(webView)
        return webView
    }

    func updateView(_ view: WKWebView) {
        if player.isLoading {
            // avoid setting anything before the player is ready
            Logger.log.info("video not loaded yet – cancelling updateUIView")
            return
        }

        let prev = player.previousState
        handlePlaybackSpeed(prev, view)
        handlePlayPause(prev, view)
        handlePip(prev, view)
        handleSeek(prev, view)
        handleQueueVideo(prev, view)
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

    func handlePlaybackSpeed(_ prev: PreviousState, _ uiView: WKWebView) {
        if prev.playbackSpeed != (player.temporaryPlaybackSpeed ?? player.playbackSpeed) {
            Logger.log.info("SPEED")
            uiView.evaluateJavaScript(getSetPlaybackRateScript())
            player.previousState.playbackSpeed = player.playbackSpeed
        }
    }

    func handlePlayPause(_ prev: PreviousState, _ uiView: WKWebView) {
        if prev.isPlaying != player.isPlaying {
            if player.isPlaying {
                Logger.log.info("PLAY")
                uiView.evaluateJavaScript(getPlayScript())
            } else {
                Logger.log.info("PAUSE")
                uiView.evaluateJavaScript(getPauseScript())
            }
            player.previousState.isPlaying = player.isPlaying
        }
    }

    func handlePip(_ prev: PreviousState, _ uiView: WKWebView) {
        if prev.pipEnabled != player.pipEnabled && player.canPlayPip {
            if player.pipEnabled {
                Logger.log.info("PIP ON")
                uiView.evaluateJavaScript(getEnterPipScript())
            } else {
                Logger.log.info("PIP OFF")
                uiView.evaluateJavaScript(getExitPipScript())
            }
            if !player.pipEnabled {
                player.previousState.pipEnabled = false
            }
        }
    }

    func handleSeek(_ prev: PreviousState, _ uiView: WKWebView) {
        if let seekAbs = player.seekAbsolute {
            Logger.log.info("SEEK ABS")
            uiView.evaluateJavaScript(getSeekToScript(seekAbs))
            player.seekAbsolute = nil
        }

        if let seekRel = player.seekRelative {
            Logger.log.info("SEEK REL")
            uiView.evaluateJavaScript(getSeekRelScript(seekRel))
            player.seekRelative = nil
        }
    }

    func handleQueueVideo(_ prev: PreviousState, _ uiView: WKWebView) {
        if prev.videoId != player.video?.youtubeId {
            Logger.log.info("CUE VIDEO: \(player.video?.title ?? "-")")
            print("\(playerType)")
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

    func customAirPlayCompatibilityUserAgent(_ userAgent: String?) -> String {
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

        return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/\(webKitVersion) (KHTML, like Gecko) Version/\(osVersion.replacingOccurrences(of: "_", with: ".")) Safari/\(webKitVersion)"
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
            appNotificationVM: .constant(AppNotificationVM()),
            deferVideoDate: .constant(nil),
            playerType: .youtubeEmbedded,
            onVideoEnded: {

            },
            handleSwipe: { _ in

            })
            .environment(player)
            .modelContainer(DataProvider.previewContainerFilled)
    )
}
