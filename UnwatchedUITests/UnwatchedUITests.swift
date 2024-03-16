//
//  UnwatchedUITests.swift
//  UnwatchedUITests
//

import XCTest

final class UnwatchedUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments =  ["enable-testing"]
        app.launch()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAppStartsEmpty() {
        XCTAssertEqual(app.cells.count, 0, "There should be 0 items when the app is first launched.")
    }

    func test_AddToLibraryView_shouldNotAddSubscription() {
        app.tabBars["Tab Bar"].buttons["Library"].tap()
        let startCount = app.cells.count

        let collectionViewsQuery = app.collectionViews
        let feedOrVideoUrlTextField = collectionViewsQuery.textFields["Feed or video URL"]

        feedOrVideoUrlTextField.tap()
        feedOrVideoUrlTextField.typeText("no url here\n")
        XCTAssertEqual(app.cells.count, startCount, "There should be change in entries when adding a wrong url")
    }

    func test_AddToLibraryView_shouldAddSubscription() {
        app.tabBars["Tab Bar"].buttons["Library"].tap()

        let collectionViewsQuery = app.collectionViews
        let feedOrVideoUrlTextField = collectionViewsQuery.textFields["Feed or video URL"]

        feedOrVideoUrlTextField.tap()
        feedOrVideoUrlTextField.typeText(
            "https://www.youtube.com/feeds/videos.xml?channel_id=UCsmk8NDVMct75j_Bfb9Ah7w\n"
        )
        XCTAssertGreaterThan(app.cells.count, 0, "There should be at least one entry after adding a new subscription")
    }

}
