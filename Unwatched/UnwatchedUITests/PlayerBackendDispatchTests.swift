//
//  PlayerBackendDispatchTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData
import WebKit
import UnwatchedShared

/// Covers what reaches the playback engine, and what deliberately doesn't.
@MainActor
final class PlayerBackendDispatchTests: XCTestCase {

    /// Records what it was told instead of playing anything.
    private final class SpyBackend: PlayerBackend {
        enum Command: Equatable {
            case play
            case pause
            case stop
            case seek(Double)
            case setRate(Double)
            case setPip(Bool)
            case cueVideo
            case setChapterMarkers(force: Bool)
            case setAudioLanguage(String)
            case setVideoQuality(Int)
            case applyTrimSilence
        }

        var commands: [Command] = []

        func play() { commands.append(.play) }
        func pause() { commands.append(.pause) }
        func stop() { commands.append(.stop) }
        func seek(to time: Double) { commands.append(.seek(time)) }
        func setRate(_ rate: Double) { commands.append(.setRate(rate)) }
        func setPip(_ enabled: Bool) { commands.append(.setPip(enabled)) }
        func cueVideo() { commands.append(.cueVideo) }
        func setChapterMarkers(force: Bool) { commands.append(.setChapterMarkers(force: force)) }
        func setAudioLanguage(_ code: String) { commands.append(.setAudioLanguage(code)) }
        func setVideoQuality(_ height: Int) { commands.append(.setVideoQuality(height)) }
        func applyTrimSilence() { commands.append(.applyTrimSilence) }

        /// Commands other than the rate, which several tests trigger incidentally by touching a speed-derived
        /// property.
        var withoutRateChanges: [Command] {
            commands.filter {
                if case .setRate = $0 { return false }
                return true
            }
        }
    }

    private var container: ModelContainer!
    private var context: ModelContext!
    private var player: PlayerManager!
    private var spy: SpyBackend!

    override func setUpWithError() throws {
        let schema = DataProvider.schema
        container = try ModelContainer(
            for: schema,
            configurations: [
                ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            ]
        )
        context = ModelContext(container)

        spy = SpyBackend()
        player = PlayerManager()
        player.backendOverride = spy
        // nothing is loading, so commands aren't dropped for readiness
        player.isLoading = nil
    }

    override func tearDownWithError() throws {
        player.backendOverride = nil
        player = nil
        spy = nil
        context = nil
        container = nil
    }

    private func makeVideo(youtubeId: String = "abc123", duration: Double? = 600) -> Video {
        let video = Video(
            title: "Test",
            url: URL(string: "https://youtube.com/watch?v=\(youtubeId)"),
            youtubeId: youtubeId,
            duration: duration
        )
        context.insert(video)
        return video
    }

    // MARK: - Seeking

    func testSeekReachesTheEngine() {
        player.seek(to: 42)

        XCTAssertEqual(spy.withoutRateChanges, [.seek(42)])
    }

    /// The regression this refactor exists for: two seeks in quick succession used to be written to
    /// one optional and the second overwrote the first before any view got to look at it, so a fast
    /// double chapter-skip only moved once.
    func testTwoSeeksInARowBothReachTheEngine() {
        player.seek(to: 30)
        player.seek(to: 60)

        XCTAssertEqual(spy.withoutRateChanges, [.seek(30), .seek(60)])
    }

    func testSeekPastTheEndClampsShortOfIt() {
        player.video = makeVideo(duration: 600)
        spy.commands.removeAll()

        player.seek(to: 900)

        XCTAssertEqual(spy.withoutRateChanges, [.seek(600 - Const.seekToEndBuffer)])
    }

    func testRelativeSeekReachesTheEngineAndMovesTheScrubber() {
        player.video = makeVideo(duration: 600)
        player.currentTime = 100
        spy.commands.removeAll()

        XCTAssertTrue(player.seekForward(20))

        XCTAssertEqual(spy.withoutRateChanges, [.seek(120)])
        XCTAssertEqual(player.currentTime, 120)
    }

    /// With no video there is nothing to seek in, and the engine shouldn't be poked.
    func testRelativeSeekWithoutAVideoDoesNothing() {
        XCTAssertFalse(player.seekForward(20))

        XCTAssertEqual(spy.withoutRateChanges, [])
    }

    // MARK: - Play / pause, and the engine reporting back

    func testPlayCommandsTheEngine() {
        player.play()

        XCTAssertEqual(spy.withoutRateChanges, [.play])
        XCTAssertTrue(player.isPlaying)
    }

    func testPauseCommandsTheEngine() {
        player.play()
        spy.commands.removeAll()

        player.pause()

        XCTAssertEqual(spy.withoutRateChanges, [.pause])
        XCTAssertFalse(player.isPlaying)
    }

    /// The page's own controls report that playback started.
    func testReportedPlayingUpdatesStateWithoutCommandingTheEngine() {
        player.reportPlaying()

        XCTAssertEqual(spy.withoutRateChanges, [])
        XCTAssertTrue(player.isPlaying)
    }

    func testReportedPausedUpdatesStateWithoutCommandingTheEngine() {
        player.play()
        spy.commands.removeAll()

        player.reportPaused()

        XCTAssertEqual(spy.withoutRateChanges, [])
        XCTAssertFalse(player.isPlaying)
    }

    /// `handlePlayButton` is the one the play button and the shortcuts go through.
    func testPlayButtonTogglesAndCommandsEachWay() {
        player.handlePlayButton()
        XCTAssertEqual(spy.withoutRateChanges, [.play])

        spy.commands.removeAll()
        player.handlePlayButton()
        XCTAssertEqual(spy.withoutRateChanges, [.pause])
    }

    /// Pausing while the page is still loading used to be undone by the auto-start that runs once it finishes.
    func testPauseWhileLoadingCancelsThePendingAutoStart() {
        player.isLoading = Date()
        player.videoSource = .userInteraction

        player.pause()
        spy.commands.removeAll()

        player.isLoading = nil
        player.handleAutoStart(nil)

        XCTAssertEqual(spy.withoutRateChanges, [])
        XCTAssertFalse(player.isPlaying)
    }

    /// The same for a player switch, which starts again only if it was playing before.
    func testPauseWhileLoadingCancelsAHotSwapResume() {
        player.isLoading = Date()
        player.previousIsPlaying = true
        player.videoSource = .hotSwap

        player.pause()
        spy.commands.removeAll()

        player.isLoading = nil
        player.handleAutoStart(nil)

        XCTAssertEqual(spy.withoutRateChanges, [])
        XCTAssertFalse(player.isPlaying)
    }

    /// Nothing is loading, so the pause is a plain pause and a later start is unaffected.
    func testPauseWhileLoadedLeavesTheSourceAlone() {
        player.videoSource = .userInteraction

        player.pause()
        spy.commands.removeAll()

        player.handleAutoStart(nil)

        XCTAssertEqual(spy.withoutRateChanges, [.play])
        XCTAssertTrue(player.isPlaying)
    }

    // MARK: - Picture in picture

    func testSetPipCommandsTheEngine() {
        player.setPip(true)

        XCTAssertEqual(spy.withoutRateChanges, [.setPip(true)])
        XCTAssertTrue(player.pipEnabled)
    }

    func testTogglePipCommandsTheEngine() {
        player.togglePip()

        XCTAssertEqual(spy.withoutRateChanges, [.setPip(true)])
        XCTAssertTrue(player.pipEnabled)
    }

    /// The system PiP button, or the PiP window being closed: the page has already done it.
    func testReportedPipUpdatesStateWithoutCommandingTheEngine() {
        player.reportPip(true)

        XCTAssertEqual(spy.withoutRateChanges, [])
        XCTAssertTrue(player.pipEnabled)
    }

    // MARK: - Speed

    func testTemporarySpeedPushesARateAndReleasingPutsItBack() {
        player.defaultPlaybackSpeed = 1.5
        spy.commands.removeAll()

        player.temporaryPlaybackSpeed = 2.5
        XCTAssertEqual(spy.commands, [.setRate(2.5)])

        player.resetTemporaryPlaybackSpeed()
        XCTAssertEqual(spy.commands, [.setRate(2.5), .setRate(1.5)])
    }

    /// Nothing changed, so nothing should be pushed — the `didSet` guards on the old value.
    func testSettingTheSameTemporarySpeedPushesNothing() {
        player.temporaryPlaybackSpeed = 2
        spy.commands.removeAll()

        player.temporaryPlaybackSpeed = 2

        XCTAssertEqual(spy.commands, [])
    }

    // MARK: - Loading a video

    func testSettingAVideoCuesItOnTheEngine() {
        player.video = makeVideo(youtubeId: "first")

        XCTAssertTrue(spy.withoutRateChanges.contains(.cueVideo))
    }

    /// `handleNewVideoSet` bails on an unchanged id, so re-assigning the same video mustn't reload the page out from
    /// under whatever is playing.
    func testSettingTheSameVideoAgainDoesNotCue() {
        let video = makeVideo(youtubeId: "same")
        player.video = video
        spy.commands.removeAll()

        player.video = video

        XCTAssertEqual(spy.withoutRateChanges, [])
    }

    // MARK: - Track and variant selection

    func testPickingAnAudioLanguageCommandsTheEngine() {
        player.setAudioLanguage("de")

        XCTAssertEqual(spy.withoutRateChanges, [.setAudioLanguage("de")])
        XCTAssertEqual(player.selectedAudioLanguage, "de")
    }

    /// The engine reporting which track it actually landed on.
    func testReportedAudioLanguageDoesNotCommandTheEngine() {
        player.reportAudioLanguage("de")

        XCTAssertEqual(spy.withoutRateChanges, [])
        XCTAssertEqual(player.selectedAudioLanguage, "de")
    }

    func testPickingAQualityCommandsTheEngine() {
        player.setVideoQuality(1080)

        XCTAssertEqual(spy.withoutRateChanges, [.setVideoQuality(1080)])
        XCTAssertEqual(player.selectedVideoQuality, 1080)
    }

    /// A chosen quality failing reverts to automatic and retries.
    func testRevertingToAutomaticQualityDoesNotCommandTheEngine() {
        player.setVideoQuality(1080)
        spy.commands.removeAll()

        player.reportVideoQuality(0)

        XCTAssertEqual(spy.withoutRateChanges, [])
        XCTAssertEqual(player.selectedVideoQuality, 0)
    }

    // MARK: - Trim silence

    /// The toggles bind through the player, so the engine hears about the setting with no view in the middle.
    func testTogglingTrimSilenceWritesTheSettingAndTellsTheEngine() {
        let original = UserDefaults.standard.bool(forKey: Const.trimSilence)
        defer { UserDefaults.standard.set(original, forKey: Const.trimSilence) }

        player.setTrimSilence(true)

        XCTAssertEqual(spy.withoutRateChanges, [.applyTrimSilence])
        XCTAssertTrue(UserDefaults.standard.bool(forKey: Const.trimSilence))

        player.setTrimSilence(false)

        XCTAssertEqual(spy.withoutRateChanges, [.applyTrimSilence, .applyTrimSilence])
        XCTAssertFalse(UserDefaults.standard.bool(forKey: Const.trimSilence))
    }

    // MARK: - Getting the embedded page to start

    /// A repeat play attempt must re-click and nothing more.
    func testRetryingPlayOnlyClicks() {
        let retry = PlayerWebView.retryPlayScript(unstarted: true)

        XCTAssertTrue(retry.contains("elementFromPoint"))
        XCTAssertFalse(retry.contains("ytp-size-button"), "a retry must not re-toggle theater mode")
        XCTAssertFalse(retry.contains("hideOverlay"))
    }

    /// Once the page has played, it takes a plain `play()` and needs no click at all.
    func testRetryingPlayOnAStartedPageDoesNotClick() {
        let retry = PlayerWebView.retryPlayScript(unstarted: false)

        XCTAssertEqual(retry, "play();")
    }

    // MARK: - Reload

    /// A reload has to silence the outgoing page first, or its audio plays on unseen until the web view is torn down.
    func testHotReloadStopsTheEngineBeforeSwapping() {
        player.video = makeVideo()
        spy.commands.removeAll()

        player.hotReloadPlayer()

        XCTAssertEqual(spy.withoutRateChanges.first, .stop)
    }

    // MARK: - Custom chapter order

    /// Timeline A(0-60) B(60-120) C(120-180), dragged into A, C, B.
    private func makeReorderedVideo() -> Video {
        let video = makeVideo(duration: 180)
        let rows = [
            Chapter(title: "A", time: 0, duration: 60, endTime: 60, order: 0),
            Chapter(title: "B", time: 60, duration: 60, endTime: 120, order: 2),
            Chapter(title: "C", time: 120, duration: 60, endTime: 180, order: 1)
        ]
        rows.forEach { context.insert($0) }
        video.chapters = rows
        return video
    }

    private func setPlayhead(_ video: Video, chapter: String, time: Double) {
        player.video = video
        player.currentChapter = video.sortedChapterData.first { $0.title == chapter }
        player.currentTime = time
        spy.commands.removeAll()
    }

    func testAChapterRunningOutJumpsToItsSuccessorInTheOrder() {
        let video = makeReorderedVideo()
        setPlayhead(video, chapter: "A", time: 60)

        player.handleChapterChange()

        XCTAssertEqual(spy.withoutRateChanges, [.seek(120)])
    }

    /// The playhead only follows the order where it ran out of a chapter. Scrubbing lands anywhere,
    /// and used to be redirected because it satisfied the same "past the end of the last chapter" check.
    func testSeekingIntoTheNextChapterIsLeftAlone() {
        let video = makeReorderedVideo()
        setPlayhead(video, chapter: "A", time: 90)

        player.handleChapterChange()

        XCTAssertEqual(spy.withoutRateChanges, [])
        XCTAssertEqual(player.currentChapter?.title, "B")
    }

    func testTheLastChapterOfTheOrderEndsTheVideo() {
        let video = makeReorderedVideo()
        setPlayhead(video, chapter: "B", time: 120)

        player.handleChapterChange()

        XCTAssertEqual(spy.withoutRateChanges, [.seek(180 - Const.seekToEndBuffer)])
    }

    /// The chapter after this one on the timeline is also the one the order wants: nothing to jump to.
    func testAnOrderThatMatchesTheTimelineJustPlaysOn() {
        let video = makeVideo(duration: 180)
        let rows = [
            Chapter(title: "A", time: 0, duration: 60, endTime: 60, order: 0),
            Chapter(title: "B", time: 60, duration: 60, endTime: 120, order: 1),
            Chapter(title: "C", time: 120, duration: 60, endTime: 180, order: 2)
        ]
        rows.forEach { context.insert($0) }
        video.chapters = rows
        setPlayhead(video, chapter: "A", time: 60)

        player.handleChapterChange()

        XCTAssertEqual(spy.withoutRateChanges, [])
        XCTAssertEqual(player.currentChapter?.title, "B")
    }

    // MARK: - Seeking backward through the order

    /// Back out of C lands in A, which played before it, not in B, which sits before it on the
    /// timeline and plays last.
    func testSeekingBackwardFollowsTheOrder() {
        let video = makeReorderedVideo()
        setPlayhead(video, chapter: "C", time: 125)

        _ = player.seek(backward: true, 10)

        XCTAssertEqual(spy.withoutRateChanges, [.seek(55)])
    }

    /// A seek that stays inside the chapter it started in doesn't care about the order.
    func testSeekingBackwardWithinAChapterIsPlain() {
        let video = makeReorderedVideo()
        setPlayhead(video, chapter: "C", time: 150)

        _ = player.seek(backward: true, 10)

        XCTAssertEqual(spy.withoutRateChanges, [.seek(140)])
    }

    /// The first chapter of the order is where playback began: a seek reaching past it stops there.
    func testSeekingBackwardPastTheFirstChapterOfTheOrderStops() {
        let video = makeReorderedVideo()
        setPlayhead(video, chapter: "C", time: 125)

        _ = player.seek(backward: true, 300)

        XCTAssertEqual(spy.withoutRateChanges, [.seek(0)])
    }

    /// Forward is left alone: it has never skipped anything.
    func testSeekingForwardIsPlain() {
        let video = makeReorderedVideo()
        setPlayhead(video, chapter: "C", time: 150)

        _ = player.seek(backward: false, 10)

        XCTAssertEqual(spy.withoutRateChanges, [.seek(160)])
    }

    /// Without an order of the user's own, a backward seek still skips the chapters that are off.
    func testSeekingBackwardStillSkipsInactiveChapters() {
        let video = makeVideo(duration: 180)
        let rows = [
            Chapter(title: "A", time: 0, duration: 60, endTime: 60),
            Chapter(title: "B", time: 60, duration: 60, endTime: 120, isActive: false),
            Chapter(title: "C", time: 120, duration: 60, endTime: 180)
        ]
        rows.forEach { context.insert($0) }
        video.chapters = rows
        setPlayhead(video, chapter: "C", time: 125)

        _ = player.seek(backward: true, 10)

        XCTAssertEqual(spy.withoutRateChanges, [.seek(55)])
    }
}

/// Which web view the embedded player sends its commands to.
@MainActor
final class WebPlayerBackendOwnershipTests: XCTestCase {

    private var backend: WebPlayerBackend!
    private var restored: WKWebView?

    override func setUpWithError() throws {
        backend = WebPlayerBackend.shared
        restored = backend.webView
    }

    override func tearDownWithError() throws {
        backend.webView = restored
        backend = nil
    }

    /// The regression: the transient view's teardown emptied the slot while the page it cleared
    /// wasn't the one on screen, so every later command — the switch's own `play()` first — had
    /// nowhere to go and the player sat there showing "playing".
    func testAPageOnScreenIsReadoptedAfterAnotherViewsTeardownClearedTheSlot() {
        let onScreen = WKWebView()
        backend.webView = nil

        backend.reclaim(onScreen)

        XCTAssertTrue(backend.webView === onScreen)
    }

    /// The mirror case: a view that is merely being updated must not take the page away from the one that owns it, or
    /// a reload would be driven through the web view it just replaced.
    func testReclaimLeavesALiveRegistrationAlone() {
        let live = WKWebView()
        let other = WKWebView()
        backend.webView = live

        backend.reclaim(other)

        XCTAssertTrue(backend.webView === live)
    }

    /// A page that has just finished loading does take over, though: the auto-start that follows
    /// its `didFinish` is for that page, and sending it to whichever web view happened to register
    /// last is how a switch's play ended up clicked into a page on its way out.
    func testThePageThatFinishedLoadingTakesOver() {
        let previous = WKWebView()
        let loaded = WKWebView()
        backend.webView = previous

        backend.takeOver(loaded)

        XCTAssertTrue(backend.webView === loaded)
    }

    /// Teardown retires the coordinator, which is what stops a dismantled page from initialising itself, clearing
    /// `isLoading` or consuming the one-shot auto-start on the player's behalf.
    func testDismantlingRetiresTheCoordinatorAndClearsTheSlot() {
        let view = WKWebView()
        let coordinator = PlayerWebViewCoordinator(makePlayerWebView())
        backend.webView = view

        PlayerWebView.dismantleView(view, coordinator)

        XCTAssertTrue(coordinator.retired)
        XCTAssertNil(backend.webView)
    }

    private func makePlayerWebView() -> PlayerWebView {
        PlayerWebView(
            overlayVM: .constant(OverlayFullscreenVM.shared),
            autoHideVM: .constant(AutoHideVM()),
            onVideoEnded: { },
            handleSwipe: { _ in }
        )
    }
}
