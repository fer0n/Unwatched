//
//  WebPlayerWarmup.swift
//  Unwatched
//

import SwiftUI
import WebKit
import OSLog
import UnwatchedShared

/// Loads the web player off screen while another player is still playing, so switching to it takes
/// over a running page instead of waiting for a fresh load. The web view built here is the one
/// `PlayerWebView` ends up showing — see `takeWebView`.
///
/// Nothing in here touches `PlayerManager`: the outgoing player owns that state until the switch
/// is committed.
final class WebPlayerWarmup: NSObject {
    @MainActor static let shared = WebPlayerWarmup()

    /// A page that has run its init script and is waiting to be adopted.
    struct Warmed {
        let webView: WKWebView
        let uiMode: PlayerWebView.UIMode
        let startAt: Double
        let playbackSpeed: Double
        /// Got playing on its own, muted and lined up with the outgoing player, so adopting it is
        /// a matter of unmuting.
        var didStart = false
        /// Still playing at hand-over; `didStart` without this means it was paused in between.
        var isPlaying = false
        /// One-shot events the live player didn't see, replayed on adoption.
        var messages: [(topic: String, payload: String?)] = []
    }

    /// The one-shot state the page reports as it starts; everything else the live player works out.
    static let replayTopics: Set<String> = ["duration", "aspectRatio", "videoData", "transcriptUrl", "pip"]

    /// How long the page gets to start playing before adoption settles for a play click instead.
    private static let startTimeout: Double = 3
    /// The outgoing player keeps going while the seek lands, so aim slightly ahead of it.
    private static let syncLead: Double = 0.15

    @MainActor private var webView: WKWebView?
    @MainActor private var videoId: String?
    @MainActor private var warmed: Warmed?
    @MainActor private var options: PlayerWebView.InitScriptOptions?
    @MainActor private var failed = false
    /// A page that finishes loading after `warmUp` returned is too late to be waited for.
    @MainActor private var finished = false
    /// The outgoing player was still playing when this page started, so a pause that lands after
    /// that is the warmed page taking the audio session rather than the user's doing.
    @MainActor private(set) var startedWhileLivePlaying = false

    /// Loads `videoId` off screen and returns whether it got ready within `timeout`. A page that
    /// didn't make it that far is still kept for adoption if it at least finished loading.
    @MainActor
    func warmUp(videoId: String, startAt: Double, setting: PlayerTypeSetting, timeout: Double) async -> Bool {
        cancel()
        let player = PlayerManager.shared
        let uiMode = PlayerWebView.UIMode.forSetting(setting, embeddingDisabled: player.embeddingDisabled)
        let webView = PlayerWebView.buildWebView(airplayHD: player.airplayHD)
        webView.frame = CGRect(origin: .zero, size: Self.warmupSize)
        webView.navigationDelegate = self
        webView.configuration.userContentController.add(self, name: "iosListener")

        finished = false
        failed = false
        self.webView = webView
        self.videoId = videoId
        options = PlayerWebView.initScriptOptions(startAt: startAt, uiMode: uiMode, player: player)

        guard PlayerWebView.loadPlayer(
            webView: webView,
            youtubeId: videoId,
            startAt: startAt,
            type: setting.webPlayerType(embeddingDisabled: player.embeddingDisabled)
        ) else {
            cancel()
            return false
        }

        let ready = await awaitPlayable(webView, timeout: timeout)
        if ready, await startSilently(webView) {
            warmed?.didStart = true
            warmed?.isPlaying = true
        }
        // JS evaluation isn't cancellable, so this can resume after a newer warm-up has started;
        // claiming `finished` then would make that one discard its own page on didFinish.
        guard isCurrent(webView) else {
            return false
        }
        finished = true
        Log.info("webWarmup: ready \(ready), playing: \(warmed?.isPlaying == true)")
        return ready && warmed != nil
    }

    /// Starts the page muted, so the switch hands over to a player that is already running: the
    /// outgoing player stays audible until the swap, and unmuting is free where a play click costs
    /// however long YouTube takes to start. Returns whether it took.
    @MainActor
    private func startSilently(_ webView: WKWebView) async -> Bool {
        PlayerWebView.evaluateJavaScript(webView, PlayerWebView.muteScript(true))
        startedWhileLivePlaying = PlayerManager.shared.isPlaying
        PlayerWebView.evaluateJavaScript(webView, PlayerWebView.unstartedPlayScript)
        let playing = await Poll.until(timeout: Self.startTimeout) {
            guard isCurrent(webView), !failed else {
                return .abort
            }
            let isPlaying = await PlayerWebView.evaluateBool(
                webView,
                "!!document.querySelector('video') && !document.querySelector('video').paused"
            )
            return isPlaying ? .done : .retry
        }
        guard playing else {
            Log.info("webWarmup: silent start didn't take")
            return false
        }
        syncPosition(webView)
        return true
    }

    /// Both pages run in real time afterwards, so this one correction is enough — but it has to
    /// come off the exact playhead, since the swap no longer has a gap that would hide a jump.
    @MainActor
    private func syncPosition(_ webView: WKWebView) {
        let player = PlayerManager.shared
        guard let live = player.precisePosition?() ?? player.currentTime else {
            return
        }
        PlayerWebView.evaluateJavaScript(
            webView,
            PlayerWebView.videoPropertyScript("currentTime", "\(live + Self.syncLead)")
        )
    }

    /// Waits for the page to have loaded *and* built its media element — the point where taking
    /// over costs no more than a normal play click.
    ///
    /// Deliberately doesn't wait for buffered media: a cued embed that was never played keeps its
    /// `<video>` at `readyState` 0 and fires neither `loadedmetadata` nor `canplay`.
    @MainActor
    private func awaitPlayable(_ webView: WKWebView, timeout: Double) async -> Bool {
        await Poll.until(timeout: timeout) {
            guard isCurrent(webView), !failed else {
                return .abort
            }
            guard warmed != nil else {
                return .retry
            }
            return await PlayerWebView.evaluateBool(webView, "!!document.querySelector('video')") ? .done : .retry
        }
    }

    /// False once this page has been cancelled, adopted or replaced by a newer warm-up.
    @MainActor
    private func isCurrent(_ webView: WKWebView) -> Bool {
        self.webView === webView
    }

    /// Hands over paused instead: the page keeps what it loaded and buffered, it just doesn't
    /// resume behind the user's back.
    @MainActor
    func pauseWarmed() {
        guard warmed?.isPlaying == true, let webView else {
            return
        }
        Log.info("webWarmup: pausing warmed page")
        PlayerWebView.evaluateJavaScript(webView, "document.querySelector('video')?.pause();")
        warmed?.isPlaying = false
    }

    /// Hands the warmed page to `PlayerWebView`, which takes over its delegates from here.
    @MainActor
    func takeWebView(for videoId: String?) -> Warmed? {
        guard let warmed, let videoId, videoId == self.videoId else {
            // a warmed page is playing by now, and nothing else will come to adopt it
            cancel()
            return nil
        }
        Log.info("webWarmup: adopting warmed page")
        detachHandlers(from: warmed.webView)
        reset()
        return warmed
    }

    @MainActor
    func cancel() {
        if let webView {
            Log.info("webWarmup: discarding page")
            detachHandlers(from: webView)
            webView.stopLoading()
            webView.pauseAllMediaPlayback()
        }
        reset()
    }

    @MainActor
    private func detachHandlers(from webView: WKWebView) {
        webView.navigationDelegate = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "iosListener")
    }

    @MainActor
    private func reset() {
        webView = nil
        videoId = nil
        warmed = nil
        options = nil
        startedWhileLivePlaying = false
    }

    /// Roughly the size the player runs at, so YouTube picks a comparable quality.
    @MainActor
    private static var warmupSize: CGSize {
        #if os(iOS)
        let bounds = UIScreen.main.bounds
        let width = min(bounds.width, bounds.height)
        #else
        let width: CGFloat = 640
        #endif
        return CGSize(width: width, height: (width / Const.defaultVideoAspectRatio).rounded())
    }
}

extension PlayerWebView {
    /// Takes over the page `WebPlayerWarmup` loaded while the previous player was still playing.
    /// It's initialized already, so all that's left is moving it to the live playback position and
    /// replaying the one-shot events the warmup swallowed.
    func adopt(_ warmed: WebPlayerWarmup.Warmed, _ coordinator: PlayerWebViewCoordinator) -> WKWebView {
        let webView = warmed.webView
        backend.resetAppliedState()
        backend.webView = webView
        backend.loadedVideoId = player.video?.youtubeId
        backend.appliedUIMode = warmed.uiMode

        attach(coordinator, to: webView)

        if warmed.didStart {
            player.unstarted = false
            evaluateJavaScript(webView, PlayerWebView.muteScript(false))
        } else {
            // the page still shows YouTube's poster until it starts, so it has to be covered from
            // the moment the swap happens, not a frame later
            withAnimation {
                player.unstarted = true
            }
        }

        let startAt = player.getStartPosition()
        Task { @MainActor in
            if !warmed.didStart, abs(startAt - warmed.startAt) > 0.5 {
                evaluateJavaScript(webView, PlayerWebView.seekToScript(startAt))
            }
            for message in warmed.messages {
                coordinator.handleJsMessages(message.topic, message.payload)
            }
            player.isLoading = nil
            // the speed the page was warmed at can be stale by now: it was read when the warm-up started, and the
            // user had the outgoing player in front of them the whole time
            if warmed.playbackSpeed != player.playbackSpeed {
                backend.setRate(player.playbackSpeed)
            }
            if !warmed.didStart {
                await PlayerWebView.awaitViewport(webView)
            }
            // `play()` confirms and re-clicks on its own, so adoption no longer needs a retry loop of its own — two
            // of them would double-click the page.
            player.handleAutoStart(webView.url)
            backend.setChapterMarkers(force: true)
        }
        return webView
    }

    /// The play click is aimed at the middle of the viewport, which is still 0×0 right after
    /// adoption: SwiftUI inserts the web view before laying it out.
    @MainActor
    static func awaitViewport(_ webView: WKWebView) async {
        let sized = await Poll.until(timeout: Self.viewportTimeout, step: Self.viewportPollSeconds) {
            let result = try? await webView.evaluateJavaScript("window.innerWidth")
            return (result as? Double ?? 0) > 0 ? .done : .retry
        }
        if !sized {
            Log.warning("adopt: viewport stayed empty")
        }
    }

    private static let viewportPollSeconds: Double = 0.03
    private static let viewportTimeout: Double = 0.9

    func attach(_ coordinator: PlayerWebViewCoordinator, to webView: WKWebView) {
        webView.navigationDelegate = coordinator
        webView.configuration.userContentController.add(coordinator, name: "iosListener")
        #if os(iOS) || os(visionOS)
        webView.scrollView.delegate = coordinator
        #endif
    }
}

extension WebPlayerWarmup: WKNavigationDelegate {
    @MainActor
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
        guard isCurrent(webView), let options else {
            return
        }
        guard !finished else {
            // took too long, the switch already went ahead without it
            cancel()
            return
        }
        Log.info("webWarmup: didFinish")
        PlayerWebView.evaluateJavaScript(webView, PlayerWebView.initScript(options))
        warmed = Warmed(
            webView: webView,
            uiMode: options.uiMode,
            startAt: options.startAt,
            playbackSpeed: options.playbackSpeed
        )
    }

    @MainActor
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation, withError error: any Error) {
        handleFailure(error)
    }

    @MainActor
    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation,
                 withError error: any Error) {
        handleFailure(error)
    }

    @MainActor
    private func handleFailure(_ error: any Error) {
        Log.error("webWarmup: didFail \(error)")
        failed = true
    }
}

extension WebPlayerWarmup: WKScriptMessageHandler {
    /// None of this may reach `PlayerManager`, which still belongs to the player that's playing —
    /// only the one-shot events the live player would otherwise miss are kept.
    @MainActor
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? String else {
            return
        }
        let parts = body.split(separator: ";")
        guard let topic = parts[safe: 0].map({ String($0) }) else {
            return
        }
        let payload = parts[safe: 1].map { String($0) }

        if topic == "youtubeError" {
            Log.error("webWarmup: page error \(payload ?? "-")")
            failed = true
        } else if Self.replayTopics.contains(topic) {
            warmed?.messages.append((topic, payload))
        }
    }
}
