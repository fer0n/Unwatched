//
//  SpeedControlViewModelTests.swift
//  UnwatchedUITests
//

import XCTest

class SpeedControlViewModelTests: XCTestCase {
    var viewModel: SpeedControlViewModel!

    override func setUp() {
        super.setUp()
        viewModel = SpeedControlViewModel()
        viewModel.width = 100
        viewModel.itemWidth = 10
    }

    func testGetSpeedFromPos() {
        let speed = viewModel.getSpeedFromPos(50)
        XCTAssertEqual(speed, 1.5, "Expected speed to be 1.5 for position 50")
    }

    func testGetSpeedFromPosInfinity() {
        let speed = viewModel.getSpeedFromPos(.infinity)
        XCTAssertEqual(speed, 1.0, "Expected speed to be 1.0 for position .infinity")
    }

    func testGetSpeedFromPosNaN() {
        let speed = viewModel.getSpeedFromPos(.nan)
        XCTAssertEqual(speed, 1.0, "Expected speed to be 1.0 for position .nan")
    }

    func testGetSpeedFromWidthPosNaN() {
        viewModel.width = .nan
        let speed = viewModel.getSpeedFromPos(0)
        XCTAssertEqual(speed, 1.0, "Expected speed to be 1.0 for position .nan")
    }

    func testGetXPos() {
        let xPos = viewModel.getXPos(100, 1.5)
        XCTAssertEqual(xPos, 55, "Expected x position to be 55 for speed 1.5")
    }

    func testFormatSpeed() {
        let formattedSpeed = SpeedControlViewModel.formatSpeed(1.5)
        XCTAssertEqual(formattedSpeed, "1.5", "Expected formatted speed to be '1.5' for speed 1.5")

        let formattedSpeed2 = SpeedControlViewModel.formatSpeed(2.0)
        XCTAssertEqual(formattedSpeed2, "2", "Expected formatted speed to be '2' for speed 2.0")
    }
}
