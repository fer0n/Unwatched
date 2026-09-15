//
//  PlayerOwnershipTests.swift
//  UnwatchedUITests
//

import XCTest
import WebKit
import UnwatchedShared

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

/// Which `AVPlayerView` is allowed to tear the native player down. A player switch briefly has two of them.
@MainActor
final class NativePlayerOwnershipTests: XCTestCase {

    private let live = UUID()
    private let phantom = UUID()

    func testTheOutgoingSubtreesViewDoesNotTearDownTheLiveOne() {
        let viewModel = playingEpisode(owners: live, phantom)

        viewModel.cleanup(owner: phantom)

        XCTAssertEqual(viewModel.loadedVideoId, "pod-episode")
    }

    func testTheLastViewToGoAwayTearsThePlayerDown() {
        let viewModel = playingEpisode(owners: live, phantom)

        viewModel.cleanup(owner: phantom)
        viewModel.cleanup(owner: live)

        XCTAssertNil(viewModel.loadedVideoId)
    }

    /// `onDisappear` and the lifetime's `deinit` both clean up, so the second call arrives with a spent token.
    func testATokenThatHasAlreadyCleanedUpTearsDownNothing() {
        let viewModel = AVPlayerViewModel()
        let gone = UUID()
        viewModel.takeOwnership(gone)
        viewModel.cleanup(owner: gone)

        let next = UUID()
        viewModel.takeOwnership(next)
        viewModel.loadedVideoId = "next-video"

        viewModel.cleanup(owner: gone)

        XCTAssertEqual(viewModel.loadedVideoId, "next-video")
    }

    /// The untokened call is `revertNativeFallback`'s: it means whatever is on screen.
    func testAnUntokenedCleanupAlwaysRuns() {
        let viewModel = AVPlayerViewModel()
        viewModel.takeOwnership(UUID())
        viewModel.loadedVideoId = "video"

        viewModel.cleanup()

        XCTAssertNil(viewModel.loadedVideoId)
    }

    private func playingEpisode(owners: UUID...) -> AVPlayerViewModel {
        let viewModel = AVPlayerViewModel()
        owners.forEach { viewModel.takeOwnership($0) }
        viewModel.loadedVideoId = "pod-episode"
        return viewModel
    }
}
