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

        // #shorts
        // v basically impossible to detect
        // let url = URL(string: "https://i4.ytimg.com/vi/skdL0ePqErk/hqdefault.jpg")!

        // v has color only on the very edge
        let url2 = URL(string: "https://i.ytimg.com/vi/UXndgq_jEnk/hqdefault.jpg")!
        XCTAssertEqual(isShortThumbnail(url2), true)

        let url3 = URL(string: "https://i4.ytimg.com/vi/wU_81A3-VzA/hqdefault.jpg")!
        XCTAssertEqual(isShortThumbnail(url3), true)

        let url4 = URL(string: "https://i2.ytimg.com/vi/QTIh1CYYKv0/hqdefault.jpg")!
        XCTAssertEqual(isShortThumbnail(url4), true)

        let url5 = URL(string: "https://i3.ytimg.com/vi/r1q3OY8StvU/hqdefault.jpg")!
        XCTAssertEqual(isShortThumbnail(url5), true)

        // no shorts
        let url6 = URL(string: "https://i1.ytimg.com/vi/h3BKjZMGoIw/hqdefault.jpg")!
        XCTAssertEqual(isShortThumbnail(url6), false)

        let url7 = URL(string: "https://i2.ytimg.com/vi/Ir1xi2zeuug/hqdefault.jpg")!
        XCTAssertEqual(isShortThumbnail(url7), false)

        let url8 = URL(string: "https://i4.ytimg.com/vi/WwjHonzRd4E/hqdefault.jpg")!
        XCTAssertEqual(isShortThumbnail(url8), false)

        let url9 = URL(string: "https://i3.ytimg.com/vi/FVwV5BxJ8M4/hqdefault.jpg")!
        XCTAssertEqual(isShortThumbnail(url9), false)

        let url10 = URL(string: "https://i4.ytimg.com/vi/Wx-SSG0RVbY/hqdefault.jpg")!
        XCTAssertEqual(isShortThumbnail(url10), false)
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
