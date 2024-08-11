//
//  ImageServiceTests.swift
//  UnwatchedUITests
//

import Foundation
import XCTest

class ImageServiceTests: XCTestCase {

    func testIsYtShortPerformanceShort() {
        let url = URL(string: "https://i3.ytimg.com/vi/jxmXQcYY1Sw/hqdefault.jpg")!

        guard let data = try? Data(contentsOf: url) else {
            XCTFail("Failed to load image data for testing")
            return
        }

        measure {
            let isShort = ImageService.isYtShort(data)
            XCTAssertEqual(isShort, true)
        }
    }

    func testIsYtShortPerformanceRegular() {
        let url = URL(string: "https://i2.ytimg.com/vi/9pVd8_bjl1o/hqdefault.jpg")!

        guard let data = try? Data(contentsOf: url) else {
            XCTFail("Failed to load image data for testing")
            return
        }

        measure {
            let isShort = ImageService.isYtShort(data)
            XCTAssertEqual(isShort, false)
        }
    }
}
