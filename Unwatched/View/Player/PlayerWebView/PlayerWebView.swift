//
//  PlayerWebView.swift
//  Unwatched
//

import SwiftUI
import WebKit
import OSLog

struct PlayerWebView: UIViewRepresentable {
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.playbackSpeed) var playbackSpeed = 1.0
    // workaround: view doesn't update otherwise
    @Environment(PlayerManager.self) var player

    let playerType: PlayerType
    let onVideoEnded: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        player.isLoading = true

        let webViewConfig = WKWebViewConfiguration()
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

        loadWebContent(webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let prev = player.previousState

        if prev.playbackSpeed != player.playbackSpeed {
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

        if let seekTo = player.seekPosition {
            Logger.log.info("SEEK")
            uiView.evaluateJavaScript(getSeekToScript(seekTo))
            player.seekPosition = nil
        }

        if prev.videoId != player.video?.youtubeId, let videoId = player.video?.youtubeId {
            Logger.log.info("CUE VIDEO")
            let startAt = player.getStartPosition()
            if playerType == .youtube {
                if let url = URL(string: UrlService.getNonEmbeddedYoutubeUrl(videoId, startAt)) {
                    let request = URLRequest(url: url)
                    uiView.load(request)
                }
            } else {
                let script = "player.cueVideoById('\(videoId)', \(startAt));"
                uiView.evaluateJavaScript(script)
            }
            player.previousState.videoId = player.video?.youtubeId
        }
    }

    @MainActor
    func loadWebContent(_ webView: WKWebView) {
        let startAt = player.getStartPosition()
        if playerType == .youtubeEmbedded {
            setupEmbeddedYouTubePlayer(webView: webView, startAt: startAt)
        } else {
            setupYouTubePlayer(webView: webView, startAt: startAt)
        }
    }

    func getPlayScript() -> String {
        if playerType == .youtube {
            return "document.querySelector('video').play();"
        } else {
            return "player.playVideo()"
        }
    }

    func getPauseScript() -> String {
        if playerType == .youtube {
            return "document.querySelector('video').pause();"
        } else {
            return "player.pauseVideo()"
        }
    }

    func getSeekToScript(_ seekTo: Double) -> String {
        if playerType == .youtube {
            return "document.querySelector('video').currentTime = \(seekTo);"
        } else {
            return "player.seekTo(\(seekTo), true)"
        }
    }

    func getSetPlaybackRateScript() -> String {
        if playerType == .youtube {
            return "document.querySelector('video').playbackRate = \(player.playbackSpeed);"
        } else {
            return "player.setPlaybackRate(\(player.playbackSpeed))"
        }
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
}

#Preview {
    let video = Video.getDummy()
    let player = PlayerManager()
    player.video = video
    return (
        PlayerWebView(playerType: .youtubeEmbedded, onVideoEnded: { })
            .environment(player)
    )
}
