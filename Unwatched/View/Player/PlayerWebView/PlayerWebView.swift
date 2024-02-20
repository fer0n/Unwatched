//
//  PlayerWebView.swift
//  Unwatched
//

import SwiftUI
import WebKit

struct PlayerWebView: UIViewRepresentable {
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.playbackSpeed) var playbackSpeed = 1.0
    // workaround: view doesn't update otherwise
    @Environment(PlayerManager.self) var player

    let playerType: PlayerType
    let onVideoEnded: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webViewConfig = WKWebViewConfiguration()
        webViewConfig.allowsPictureInPictureMediaPlayback = true
        webViewConfig.mediaTypesRequiringUserActionForPlayback = [.all]
        webViewConfig.allowsInlineMediaPlayback = !playVideoFullscreen

        let coordinator = context.coordinator
        coordinator.previousState.videoId = player.video?.youtubeId
        coordinator.previousState.playbackSpeed = player.playbackSpeed

        let webView = WKWebView(frame: .zero, configuration: webViewConfig)
        webView.navigationDelegate = coordinator
        webView.configuration.userContentController.add(coordinator, name: "iosListener")
        webView.backgroundColor = UIColor.systemBackground
        webView.isOpaque = false

        loadWebContent(webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // print("updateUiView")
        let prev = context.coordinator.previousState

        if prev.playbackSpeed != player.playbackSpeed {
            print("SPEED")
            uiView.evaluateJavaScript(getSetPlaybackRateScript(), completionHandler: nil)
            context.coordinator.previousState.playbackSpeed = player.playbackSpeed
        }

        if prev.isPlaying != player.isPlaying {
            if player.isPlaying {
                print("PLAY")
                uiView.evaluateJavaScript(getPlayScript(), completionHandler: nil)
            } else {
                print("PAUSE")
                uiView.evaluateJavaScript(getPauseScript(), completionHandler: nil)
            }
            context.coordinator.previousState.isPlaying = player.isPlaying
        }

        let seekPosition = player.seekPosition
        if prev.seekPosition != seekPosition, let seekTo = seekPosition {
            print("SEEK")
            uiView.evaluateJavaScript(getSeekToScript(seekTo), completionHandler: nil)
            context.coordinator.previousState.seekPosition = seekPosition
        }

        if prev.videoId != player.video?.youtubeId, let videoId = player.video?.youtubeId {
            print("CUE VIDEO")
            if playerType == .youtube {
                if let url = URL(string: UrlService.getNonEmbeddedYoutubeUrl(videoId, player.getStartPosition())) {
                    let request = URLRequest(url: url)
                    uiView.load(request)
                }
            } else {
                let script = "player.cueVideoById('\(videoId)', \(player.video?.elapsedSeconds ?? 0));"
                uiView.evaluateJavaScript(script, completionHandler: nil)
            }
            context.coordinator.previousState.videoId = player.video?.youtubeId
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

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: PlayerWebView
        var previousState = PreviousState()

        init(_ parent: PlayerWebView) {
            self.parent = parent
        }

        @MainActor
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            parent.loadWebContent(webView)
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            if message.name == "iosListener", let messageBody = message.body as? String {
                let body = messageBody.split(separator: ";")
                guard let topic = body[safe: 0] else {
                    return
                }
                let payload = body[safe: 1]
                let payloadString = payload.map { String($0) }
                if topic != "currentTime" {
                    debugPrint(messageBody)
                }
                handleJsMessages(String(topic), payloadString)
            }
        }

        func handleJsMessages(_ topic: String, _ payload: String?) {
            switch topic {
            case "pause":
                previousState.isPlaying = false
                parent.player.pause()
                handleTimeUpdate(payload, persist: true)
            case "play":
                previousState.isPlaying = true
                parent.player.play()
            case "ended":
                previousState.isPlaying = false
                parent.onVideoEnded()
            case "unstarted":
                parent.player.handleAutoStart()
            case "currentTime":
                handleTimeUpdate(payload)
            case "updateTitle":
                handleTitleUpdate(payload)
            case "duration":
                handleDuration(payload)
            case "playbackRate":
                handlePlaybackSpeed(payload)
            case "error":
                handleError(payload)
            default:
                break
            }
        }

        func handlePlaybackSpeed(_ payload: String?) {
            guard let payload = payload,
                  let playbackRate = Double(payload),
                  parent.player.playbackSpeed != playbackRate else {
                return
            }
            parent.player.playbackSpeed = playbackRate
        }

        func handleTitleUpdate(_ title: String?) {
            if var title = title {
                title = title.replacingOccurrences(of: " - YouTube", with: "")
                self.parent.player.video?.title = title
            }
        }

        func handleDuration(_ payload: String?) {
            guard let payload = payload, let duration = Double(payload), duration > 0 else {
                return
            }
            if let video = parent.player.video {
                VideoService.updateDuration(video, duration: duration)
            }
        }

        func handleError(_ payload: String?) {
            if payload == "150" {
                withAnimation {
                    previousState.isPlaying = false
                    parent.player.pause()
                    parent.player.embeddingDisabled = true
                }
            }
        }

        func handleTimeUpdate(_ payload: String?, persist: Bool = false) {
            guard let payload = payload else {
                return
            }
            // "paused:2161.00033421,https://www.youtube.com/watch?t=2161&v=dKbT0iFia0I"
            let payloadArray = payload.split(separator: ",")
            let timeString = payloadArray[safe: 0]
            let urlString = payloadArray[safe: 1]
            guard let time = timeString.flatMap({ Double($0) }) else {
                return
            }
            if parent.player.isPlaying {
                parent.player.monitorChapters(time: time)
            }
            if let urlString = urlString,
               let url = URL(string: String(urlString)),
               let videoId = UrlService.getYoutubeIdFromUrl(url: url),
               persist {
                parent.player.updateElapsedTime(time, videoId: videoId)
            }
        }

        @MainActor func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
            if parent.playerType != .youtube {
                return
            }
            parent.player.handleAutoStart()
            let script = PlayerWebView.nonEmbeddedInitScript(
                parent.player.playbackSpeed,
                parent.player.getStartPosition(),
                parent.player.requiresFetchingVideoData()
            )
            webView.evaluateJavaScript(script)
        }
    }

    enum PlayerType {
        case youtubeEmbedded
        case youtube
    }
}

struct PreviousState {
    var videoId: String?
    var playbackSpeed: Double?
    var seekPosition: Double?
    var isPlaying: Bool = false
}
