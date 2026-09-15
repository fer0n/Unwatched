//
//  WebPlayerBackend.swift
//  Unwatched
//

import SwiftUI
import WebKit
import OSLog
import UnwatchedShared

/// Drives the embedded YouTube page.
@Observable class WebPlayerBackend: PlayerBackend {
    @MainActor static let shared = WebPlayerBackend()

    @ObservationIgnored var webView: WKWebView?

    /// Video the page has been pointed at, so a video that is already up isn't loaded again.
    @ObservationIgnored var loadedVideoId: String?

    /// Chapter set live in the page, so an unchanged set isn't pushed again.
    @ObservationIgnored var appliedChaptersHash: String?

    /// Mode live in the page, so `applyUIMode` only pushes on an actual change.
    @ObservationIgnored var appliedUIMode: PlayerWebView.UIMode?

    /// The in-flight attempt to get the page playing; see `startPlayback(on:)`.
    @ObservationIgnored private var startTask: Task<Void, Never>?

    /// The in-flight attempt to get the page to stop; see `confirmPause(on:)`.
    @ObservationIgnored private var pauseTask: Task<Void, Never>?

    /// Which start attempt is still running, so `ensurePlaying` stays out of its way. A cancelled attempt drops
    /// out of this right away: unwinding it takes until its current sleep or JS call comes back, and until then it
    /// would look like a start that is still coming for a page it has already been taken off.
    @ObservationIgnored private var runningStart: Int?
    @ObservationIgnored private var startGeneration = 0

    /// How many times to re-send a command before giving up, and how long to give each one to take.
    private static let playAttempts = 4
    private static let pauseAttempts = 2
    private static let retryDelay: Double = 0.5
    /// Rounds a page that has taken the click gets to load its stream, on top of the click attempts.
    private static let playWaits = 8

    /// Forgets what the page had; the next command set re-establishes it.
    @MainActor
    func resetAppliedState() {
        cancelStart()
        pauseTask?.cancel()
        loadedVideoId = nil
        appliedChaptersHash = nil
        appliedUIMode = nil
    }

    /// Called when the player moves to a different video, whether or not a page is on screen.
    @MainActor
    func handleVideoChanged() {
        cancelStart()
        pauseTask?.cancel()
        appliedChaptersHash = nil
    }

    @MainActor
    private var player: PlayerManager { .shared }

    /// The page can't be scripted before it has loaded; `isLoading` is cleared by `didFinish`.
    /// - Returns: the web view to script, or nil when a command has to be dropped.
    @MainActor
    private func commandTarget(_ label: String) -> WKWebView? {
        guard let webView else { return nil }
        guard player.isLoading == nil else {
            Log.info("\(label): dropped, page still loading")
            return nil
        }
        return webView
    }

    /// Starting a page that has never played means clicking its play button through YouTube's own
    /// UI, and that click can simply not land: it is aimed at the middle of the viewport, which may
    /// still be 0×0 while SwiftUI lays the web view out, or may have an overlay or an ad over it.
    /// A page that ignored the click reports nothing back, so it just sits there until the user
    /// taps the page itself — which is what "playback sometimes doesn't start" was.
    ///
    /// So the click is confirmed and repeated here. The script's own `setTimeout` retries can't do
    /// this: only a fresh `evaluateJavaScript` carries the user gesture WebKit requires to start
    /// media, which is also why this can't be a JS-side loop. A click that landed on a page that is
    /// merely slow to load is waited out rather than repeated — see `evaluateStartTook`.
    @MainActor
    func play() {
        // before the guard: a play that can't be dispatched still ends the attempt that came before it, and a
        // start left on the books would block the `ensurePlaying` that has to make up for this one being dropped
        cancelStart()
        pauseTask?.cancel()
        guard let webView = commandTarget("PLAY") else { return }
        // The page plays on the app's session, so the mode that makes AirPods pause on speech rather than duck has
        // to be set here too; WebKit's own default is not `.spokenAudio`.
        PlayerAudioSession.configure()
        startGeneration += 1
        let generation = startGeneration
        runningStart = generation
        startTask = Task { [weak self] in
            await self?.startPlayback(on: webView)
            guard let self, runningStart == generation else { return }
            runningStart = nil
        }
    }

    /// Drops the in-flight start attempt, both the task and the record of it: whatever comes next is the one
    /// that decides whether the page plays.
    @MainActor
    private func cancelStart() {
        startTask?.cancel()
        startTask = nil
        runningStart = nil
    }

    /// Brings a page that has just become the live one in line with what the player says it is doing.
    @MainActor
    func ensurePlaying() {
        guard runningStart == nil,
              player.isPlaying,
              (player.backend as AnyObject) === self,
              let webView = commandTarget("ENSURE PLAYING") else { return }
        Task { [weak self] in
            guard await PlayerWebView.evaluateIsNotPlaying(webView) else { return }
            guard let self, webView === self.webView, player.isPlaying, runningStart == nil else { return }
            Log.info("PLAY: the page never got the switch's play")
            play()
        }
    }

    @MainActor
    private func startPlayback(on webView: WKWebView) async {
        var gateOnPlayerState = false
        if player.unstarted {
            // returns immediately once sized, so this costs nothing in the normal case
            await PlayerWebView.awaitViewport(webView)
            gateOnPlayerState = await PlayerWebView.evaluateIsUnstartedMode(webView)
        }
        var clicks = 0
        var waits = 0
        while true {
            guard !Task.isCancelled, stillWants(true, on: webView) else { return }
            var startTook = false
            if gateOnPlayerState, clicks > 0 {
                startTook = await PlayerWebView.evaluateStartTook(webView)
                guard !Task.isCancelled, stillWants(true, on: webView) else { return }
            }
            if startTook {
                guard waits < Self.playWaits else { break }
                waits += 1
                Log.info("PLAY: the click took, waiting for the page")
            } else {
                guard clicks <= Self.playAttempts else { break }
                Log.info(clicks == 0 ? "PLAY" : "PLAY: didn't take, attempt \(clicks + 1)")
                PlayerWebView.evaluateJavaScript(
                    webView,
                    clicks == 0
                        ? PlayerWebView.playScript(unstarted: player.unstarted)
                        : PlayerWebView.retryPlayScript(unstarted: player.unstarted)
                )
                clicks += 1
            }
            try? await Task.sleep(for: .seconds(Self.retryDelay))
            guard !Task.isCancelled, stillWants(true, on: webView) else { return }
            guard await PlayerWebView.evaluateIsNotPlaying(webView) else { return }
        }
        Log.warning("PLAY: page never started")
    }

    /// The retry stops the moment the user changes their mind, or the page it was aimed at is gone.
    @MainActor
    private func stillWants(_ playing: Bool, on webView: WKWebView) -> Bool {
        player.isPlaying == playing && self.webView === webView && player.isLoading == nil
    }

    /// A pause can be swallowed the way a click can — the page rebuilds its media element, an ad player takes
    /// over — leaving it playing on while the button already says paused, so it is confirmed and re-sent.
    @MainActor
    func pause() {
        cancelStart()
        pauseTask?.cancel()
        guard let webView = commandTarget("PAUSE") else { return }
        Log.info("PAUSE")
        PlayerWebView.evaluateJavaScript(webView, PlayerWebView.pauseScript())
        pauseTask = Task { [weak self] in
            await self?.confirmPause(on: webView)
        }
    }

    @MainActor
    private func confirmPause(on webView: WKWebView) async {
        for attempt in 1...Self.pauseAttempts {
            try? await Task.sleep(for: .seconds(Self.retryDelay))
            guard !Task.isCancelled, stillWants(false, on: webView) else { return }
            guard await !PlayerWebView.evaluateIsNotPlaying(webView) else { return }
            guard stillWants(false, on: webView) else { return }
            Log.info("PAUSE: didn't take, attempt \(attempt + 1)")
            PlayerWebView.evaluateJavaScript(webView, PlayerWebView.pauseScript())
        }
    }

    /// Ungated: a reload has to silence the old page, and by then `isLoading` is already set again.
    @MainActor
    func stop() {
        cancelStart()
        pauseTask?.cancel()
        guard let webView else { return }
        Log.info("STOP")
        webView.pauseAllMediaPlayback()
    }

    @MainActor
    func seek(to time: Double) {
        guard let webView = commandTarget("SEEK") else { return }
        Log.info("SEEK \(time)")
        PlayerWebView.evaluateJavaScript(webView, PlayerWebView.seekToScript(time))
    }

    @MainActor
    func setRate(_ rate: Double) {
        guard let webView = commandTarget("SPEED") else { return }
        Log.info("SPEED \(rate)")
        PlayerWebView.evaluateJavaScript(webView, PlayerWebView.setPlaybackRateScript(rate))
    }

    @MainActor
    func setPip(_ enabled: Bool) {
        guard let webView = commandTarget("PIP") else { return }
        // the page reports whether it found something it can put in a picture
        guard enabled ? player.canPlayPip : true else { return }
        Log.info("PIP \(enabled)")
        PlayerWebView.evaluateJavaScript(
            webView,
            enabled ? PlayerWebView.enterPipScript() : PlayerWebView.exitPipScript()
        )
    }

    /// The page reporting that it now has something it can put in a picture.
    @MainActor
    func handleCanPlayPip() {
        guard player.pipEnabled else { return }
        setPip(true)
    }

    /// Points the shared reference at the page that has just finished loading, which is the one the auto-start
    /// following it is meant for.
    @MainActor
    func takeOver(_ view: WKWebView) {
        guard webView !== view else { return }
        Log.info("web player: page taking over")
        // aimed at the view being replaced, and that page is not the one to start
        cancelStart()
        pauseTask?.cancel()
        webView = view
        // what this page is actually showing, so an unchanged video isn't cued again
        loadedVideoId = view.url.flatMap { UrlService.getYoutubeIdFromUrl(url: $0) }
        appliedChaptersHash = nil
        appliedUIMode = nil
    }

    /// Re-registers a page that is on screen while the shared reference has been emptied by another `PlayerWebView`'s
    /// teardown — the same two-web-view window as above, where the one that goes away is the one that was registered.
    @MainActor
    func reclaim(_ view: WKWebView) {
        guard webView == nil else { return }
        Log.info("web player: re-registering the page on screen")
        takeOver(view)
        ensurePlaying()
    }

    /// Ungated: pointing the page at a video is what eventually makes it ready.
    @MainActor
    func cueVideo() {
        guard let webView, let youtubeId = player.video?.youtubeId else { return }
        guard loadedVideoId != youtubeId else { return }
        Log.info("CUE VIDEO: \(player.video?.title ?? "-")")
        let type = PlayerSwitchManager.shared.activeType
            .webPlayerType(embeddingDisabled: player.embeddingDisabled)
        let loaded = PlayerWebView.loadPlayer(
            webView: webView,
            youtubeId: youtubeId,
            startAt: player.getStartPosition(),
            type: type
        )
        if loaded {
            loadedVideoId = youtubeId
        }
    }

    /// Switches the player variant without touching playback: they all run this same page.
    @MainActor
    func applyUIMode(_ mode: PlayerWebView.UIMode) {
        guard appliedUIMode != mode else { return }
        guard let webView = commandTarget("UI MODE") else { return }
        Log.info("UI MODE: \(mode)")
        appliedUIMode = mode
        PlayerWebView.evaluateJavaScript(webView, PlayerWebView.applyUIModeScript(mode))
    }

    /// - Parameter force: push even though the page hasn't taken its initial set yet, for the
    ///   point where the page reports its chapters are in.
    @MainActor
    func setChapterMarkers(force: Bool) {
        guard force || appliedChaptersHash != nil else { return }
        guard let video = player.video,
              // not into a page that is still showing the previous video
              loadedVideoId == video.youtubeId,
              let webView = commandTarget("CHAPTERMARKERS") else { return }
        let hash = ChapterService.getChaptersHash(
            from: video.sortedChapterData, duration: video.duration
        )
        guard appliedChaptersHash != hash else { return }
        appliedChaptersHash = hash
        Log.info("CHAPTERMARKERS")
        let script = PlayerWebView.setChapterMarkersScript(
            chapters: video.sortedChapterData,
            playbackOrder: video.orderedChapterData,
            videoDuration: video.duration ?? 0,
            enableLogging: UserDefaults.standard.bool(forKey: Const.enableLogging)
        )
        PlayerWebView.evaluateJavaScript(webView, script)
    }
}
