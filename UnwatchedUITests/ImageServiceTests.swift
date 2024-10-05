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

    func testThumbnails() {
        let testData: [(String, Bool)] = [
            // basically impossible to detect
            // ("https://i4.ytimg.com/vi/skdL0ePqErk/hqdefault.jpg", true),

            // v has color only on the very edge
            ("https://i.ytimg.com/vi/UXndgq_jEnk/hqdefault.jpg", true),

            ("https://i4.ytimg.com/vi/wU_81A3-VzA/hqdefault.jpg", true),
            ("https://i2.ytimg.com/vi/QTIh1CYYKv0/hqdefault.jpg", true),
            ("https://i3.ytimg.com/vi/r1q3OY8StvU/hqdefault.jpg", true),
            ("https://i1.ytimg.com/vi/xM563h8tKuU/hqdefault.jpg", true),
            ("https://i1.ytimg.com/vi/4HF3njpOSsA/hqdefault.jpg", true),
            ("https://i1.ytimg.com/vi/h3BKjZMGoIw/hqdefault.jpg", false),
            ("https://i2.ytimg.com/vi/Ir1xi2zeuug/hqdefault.jpg", false),
            ("https://i4.ytimg.com/vi/WwjHonzRd4E/hqdefault.jpg", false),
            ("https://i3.ytimg.com/vi/FVwV5BxJ8M4/hqdefault.jpg", false),
            ("https://i4.ytimg.com/vi/Wx-SSG0RVbY/hqdefault.jpg", false)
        ]

        for (url, expected) in testData {
            let url = URL(string: url)!
            XCTAssertEqual(isShortThumbnail(url), expected, "Failed for \(url)")
        }
    }

    func isShortThumbnail(_ url: URL) -> Bool? {
        guard let data = try? Data(contentsOf: url) else {
            XCTFail("Failed to load image data for testing")
            fatalError("no data loaded")
        }

        return ImageService.isYtShort(data)
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
