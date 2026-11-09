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
}
