//
//  LaunchTraceTests.swift
//  UnwatchedUITests
//

import XCTest
import UnwatchedShared

/// Guards the launch critical path: everything the first frame doesn't need has to stay off it.
///
/// Asserts on the *order* of the phases `LaunchTrace` records rather than on wall-clock times,
/// which are too machine- and build-dependent to gate on. The one duration that is checked has a
/// budget wide enough to survive a slow machine, and narrow enough to catch the regression it
/// exists for: warming up WebKit inside `didFinishLaunchingWithOptions` used to cost 60-700ms.
final class LaunchTraceTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        dismissSystemAlerts()
        app = XCUIApplication()
        app.launchArguments = ["launch-trace"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testWebKitWarmUpStaysOffTheLaunchCriticalPath() throws {
        let phases = try waitForPhases(including: "webViewWarmup.end")

        let sceneActive = try XCTUnwrap(phases["sceneActive"], "no first frame recorded")
        let warmUp = try XCTUnwrap(phases["webViewWarmup.begin"])

        XCTAssertGreaterThan(
            warmUp,
            sceneActive,
            "the WebKit warm-up ran before the app was on screen, delaying launch by that much"
        )
    }

    func testDidFinishLaunchingDoesLittleWork() throws {
        let phases = try waitForPhases(including: "sceneActive")

        let begin = try XCTUnwrap(phases["didFinishLaunching.begin"])
        let end = try XCTUnwrap(phases["didFinishLaunching.end"])

        XCTAssertLessThan(
            end - begin,
            200,
            "didFinishLaunchingWithOptions grew to \(Int(end - begin))ms; the first frame waits on it"
        )
    }

    func testModelContainerIsOpenedBeforeTheFirstFrame() throws {
        // Not a perf assertion: it pins down that the phases the other tests compare against are
        // the launch ones, so a reporter that came up empty can't pass as a green run.
        let phases = try waitForPhases(including: "sceneActive")

        let containerEnd = try XCTUnwrap(phases["container.end"])
        let sceneActive = try XCTUnwrap(phases["sceneActive"])

        XCTAssertLessThan(containerEnd, sceneActive)
    }

    // MARK: Helpers

    /// A system alert left behind by another test (a notification permission prompt, say) keeps
    /// the app underneath it from ever becoming active, so the launch would never finish.
    private func dismissSystemAlerts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Don’t Allow", "Don't Allow", "Allow", "OK", "Dismiss"] {
            let button = springboard.buttons[label]
            if button.exists {
                button.tap()
            }
        }
    }

    /// The recorded phases, as `name` to milliseconds since process start.
    ///
    /// Polls because the reporter answers with the marks recorded so far: the later phases haven't
    /// happened yet when the app first comes up.
    private func waitForPhases(including phase: String) throws -> [String: Double] {
        let reporter = app.descendants(matching: .any)[LaunchTrace.elementId]
        XCTAssertTrue(reporter.waitForExistence(timeout: 30), "launch trace reporter not found")

        let deadline = Date().addingTimeInterval(30)
        var phases = [String: Double]()
        repeat {
            phases = Self.parse(reporter.value as? String ?? "")
            if phases[phase] != nil {
                return phases
            }
        } while Date() < deadline

        XCTFail("phase \(phase) was never recorded, got: \(phases.keys.sorted())")
        return phases
    }

    private static func parse(_ summary: String) -> [String: Double] {
        var phases = [String: Double]()
        for entry in summary.split(separator: ",") {
            let parts = entry.split(separator: ":")
            guard parts.count == 2, let value = Double(parts[1]) else { continue }
            phases[String(parts[0])] = value
        }
        return phases
    }
}
