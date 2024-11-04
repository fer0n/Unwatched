//
//  PlayerWebView.swift
//  Unwatched
//

import SwiftUI
import WebKit
import OSLog
import UnwatchedShared

struct PlayerWebView: UIViewRepresentable {
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.playbackSpeed) var playbackSpeed = 1.0
    // workaround: view doesn't update otherwise
    @Environment(PlayerManager.self) var player

    @Binding var overlayVM: OverlayFullscreenVM
    @Binding var autoHideVM: AutoHideVM
    let playerType: PlayerType
    let onVideoEnded: () -> Void
    var setShowMenu: (() -> Void)?
    var handleSwipe: (SwipeDirecton) -> Void

    func makeUIView(context: Context) -> WKWebView {
        player.isLoading = true

        let webViewConfig = WKWebViewConfiguration()
        webViewConfig.preferences.isTextInteractionEnabled = false
        webViewConfig.allowsPictureInPictureMediaPlayback = true
        webViewConfig.mediaTypesRequiringUserActionForPlayback = [.all]
        webViewConfig.allowsInlineMediaPlayback = !playVideoFullscreen

        let coordinator = context.coordinator
        player.previousState.videoId = player.video?.youtubeId
        player.previousState.playbackSpeed = player.playbackSpeed

        let webView = WKWebView(frame: .zero, configuration: webViewConfig)
        webView.navigationDelegate = coordinator
        webView.configuration.userContentController.add(coordinator, name: "iosListener")
        webView.backgroundColor = UIColor.systemBackground
        webView.isOpaque = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        let userAgent = webView.value(forKey: "userAgent") as? String
        if ProcessInfo.processInfo.isiOSAppOnMac {
            // workaround: enables higher quality on "Mac (Designed for iPad)",
            // but breaks fullscreen
            webView.customUserAgent = createCustomMacOsUserAgent(userAgent)
        } else if UIDevice.requiresFullscreenWebWorkaround {
            if let userAgent = userAgent {
                // workaround: fix "fullscreen" button being blocked on the iPad
                let modifiedUserAgent = userAgent.replacingOccurrences(of: "iPad", with: "iPhone")
                webView.customUserAgent = modifiedUserAgent
            }
        }

        DispatchQueue.main.async {
            webView.becomeFirstResponder()
        }

        loadWebContent(webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if player.isLoading {
            // avoid setting anything before the player is ready
            Logger.log.info("video not loaded yet – cancelling updateUIView")
            return
        }

        let prev = player.previousState

        if prev.playbackSpeed != (player.temporaryPlaybackSpeed ?? player.playbackSpeed) {
            Logger.log.info("SPEED")
            uiView.evaluateJavaScript(getSetPlaybackRateScript())
            player.previousState.playbackSpeed = player.playbackSpeed
        }

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

        if prev.pipEnabled != player.pipEnabled {
            if player.pipEnabled {
                Logger.log.info("PIP ON")
                uiView.evaluateJavaScript(getEnterPipScript())
            } else {
                Logger.log.info("PIP OFF")
                uiView.evaluateJavaScript(getExitPipScript())
            }
            player.previousState.pipEnabled = player.pipEnabled
        }

        if let seekTo = player.seekPosition {
            Logger.log.info("SEEK")
            uiView.evaluateJavaScript(getSeekToScript(seekTo))
            player.seekPosition = nil
        }

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

    func createCustomMacOsUserAgent(_ userAgent: String?) -> String {
        var osVersion = "17_5"
        var webKitVersion = "605.1.15"

        if let userAgent = userAgent {
            if let range = userAgent.range(of: "AppleWebKit/") {
                let webKitVersionStart = userAgent[range.upperBound...]
                if let endRange = webKitVersionStart.range(of: " ") {
                    webKitVersion = String(webKitVersionStart[..<endRange.lowerBound])
                }
            }
            if let range = userAgent.range(of: "CPU OS ") {
                let osVersionStart = userAgent[range.upperBound...]
                if let endRange = osVersionStart.range(of: " ") {
                    osVersion = String(osVersionStart[..<endRange.lowerBound]).replacingOccurrences(of: "_", with: ".")
                    print("osVersion", osVersion)
                }
            }
        }

        return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/\(webKitVersion)"
            + " (KHTML, like Gecko) Version/\(osVersion) Safari/\(webKitVersion)"
    }
}

enum PlayerType {
    case youtubeEmbedded
    case youtube
}

struct PreviousState {
    var videoId: String?
    var playbackSpeed: Double?
    var isPlaying: Bool = false
    var pipEnabled: Bool = false
}

// #Preview {
//    let video = Video.getDummy()
//    let player = PlayerManager()
//    player.video = video
//
//    (
//        PlayerWebView(
//            autoHideVM: AutoHideVM(),
//            playerType: .youtubeEmbedded,
//            onVideoEnded: {
//
//            })
//            .environment(player)
//    )
// }
