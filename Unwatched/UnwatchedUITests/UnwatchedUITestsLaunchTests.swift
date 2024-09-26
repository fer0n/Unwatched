//
//  UnwatchedUITestsLaunchTests.swift
//  UnwatchedUITests
//

import XCTest

final class UnwatchedUITestsLaunchTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments =  ["enable-testing"]
        app.launch()
    }

    func testLaunch() throws {
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    func testScrollPerformance() {
        app.launch()
        let messageList = app.collectionViews.firstMatch

        messageList.cells.firstMatch.tap()
        sleep(4)
        app.buttons["Pause"].firstMatch.tap()
        sleep(1)
        app.buttons["Menu"].tap()

        let measureOptions = XCTMeasureOptions()
        measureOptions.invocationOptions = [.manuallyStop]

        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric],
                options: measureOptions) {
            messageList.swipeUp(velocity: .fast)
            stopMeasuring()
            messageList.swipeDown(velocity: .fast)
        }
    }

    func test_AddToLibraryView_shouldAddSubscription() {
        app.tabBars["Tab Bar"].buttons["Library"].tap()

    }
}
