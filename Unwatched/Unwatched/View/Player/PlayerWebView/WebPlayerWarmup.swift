//
//  WebPlayerWarmup.swift
//  Unwatched
//

import SwiftUI
import WebKit
import OSLog
import UnwatchedShared

/// Loads the web player out of sight while another player is still playing, so switching to it takes
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
    private static let seekLead: Double = 0.4
    private static let bufferedSeekLead: Double = 0.15
    private static let syncTolerance: Double = 0.3
    private static let syncTimeout: Double = 3

    @MainActor private var webView: WKWebView?
    @MainActor private var videoId: String?
    @MainActor private var warmed: Warmed?
    @MainActor private var options: PlayerWebView.InitScriptOptions?
    /// Which page the warmed view actually loaded. A page warmed as the embed can't stand in
    /// for the full-website fallback (or the reverse): they're different URLs.
    @MainActor private var warmedType: PlayerType?
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
        hideBehindKeyWindow(webView)
        webView.navigationDelegate = self
        webView.configuration.userContentController.add(self, name: "iosListener")

        finished = false
        failed = false
        self.webView = webView
        self.videoId = videoId
        options = PlayerWebView.initScriptOptions(startAt: startAt, uiMode: uiMode, player: player)

        let type = setting.webPlayerType(embeddingDisabled: player.embeddingDisabled)
        warmedType = type

        guard PlayerWebView.loadPlayer(
            webView: webView,
            youtubeId: videoId,
            startAt: startAt,
            type: type
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
            guard isLive(webView) else {
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
        await syncPosition(webView)
        return true
    }

    @MainActor
    private func syncPosition(_ webView: WKWebView) async {
        guard let lag = await lagAfterSeeking(webView, ahead: Self.seekLead), lag >= Self.syncTolerance else {
            return
        }
        _ = await lagAfterSeeking(webView, ahead: Self.bufferedSeekLead)
    }

    @MainActor
    private func lagAfterSeeking(_ webView: WKWebView, ahead lead: Double) async -> Double? {
        guard let live = livePosition else {
            return nil
        }
        let target = live + lead * PlayerManager.shared.playbackSpeed
        PlayerWebView.evaluateJavaScript(webView, PlayerWebView.seekToScript(target))
        var page: Double?
        _ = await Poll.until(timeout: Self.syncTimeout, step: 0.05) {
            guard isLive(webView) else {
                return .abort
            }
            page = await PlayerWebView.evaluatePosition(webView, whilePlaying: true)
            return page == nil ? .retry : .done
        }
        guard let page, let now = livePosition else {
            return nil
        }
        Log.info("webWarmup: synced \(String(format: "%.2f", now - page))s behind")
        return now - page
    }

    @MainActor
    private var livePosition: Double? {
        let player = PlayerManager.shared
        return player.precisePosition?() ?? player.currentTime
    }

    /// Waits for the page to have loaded *and* built its media element — the point where taking
    /// over costs no more than a normal play click.
    ///
    /// Deliberately doesn't wait for buffered media: a cued embed that was never played keeps its
    /// `<video>` at `readyState` 0 and fires neither `loadedmetadata` nor `canplay`.
    @MainActor
    private func awaitPlayable(_ webView: WKWebView, timeout: Double) async -> Bool {
        await Poll.until(timeout: timeout) {
            guard isLive(webView) else {
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

    @MainActor
    private func isLive(_ webView: WKWebView) -> Bool {
        isCurrent(webView) && !failed
    }

    /// Out of a window the page never loads any media.
    @MainActor
    private func hideBehindKeyWindow(_ webView: WKWebView) {
        #if os(iOS)
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        window?.insertSubview(webView, at: 0)
        setHidden(webView, true)
        #endif
    }

    @MainActor
    private func setHidden(_ webView: WKWebView, _ hidden: Bool) {
        #if os(iOS)
        webView.accessibilityElementsHidden = hidden
        webView.isUserInteractionEnabled = !hidden
        #endif
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
    func takeWebView(for videoId: String?, type: PlayerType) -> Warmed? {
        guard let warmed, let videoId, videoId == self.videoId, type == warmedType else {
            // a warmed page is playing by now, and nothing else will come to adopt it
            cancel()
            return nil
        }
        Log.info("webWarmup: adopting warmed page")
        detachHandlers(from: warmed.webView)
        setHidden(warmed.webView, false)
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
            webView.removeFromSuperview()
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
        warmedType = nil
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
