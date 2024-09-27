//
//  DataSpeedTests.swift
//  Unwatched
//

import XCTest
import SwiftData

// swiftlint:disable all
final class UrlServiceTests: XCTestCase {

    func testExtractYoutubeId() async {

        // https://youtu.be/dtp6b76pMak
        // https://m.youtube.com/shorts/jH_QIBtX1gY
        // https://www.youtube.com/watch?v=epBbbysk5cU
        // https://piped.video/watch?v=VZIm_2MgdeA
        // https://www.youtube.com/embed/Udl16tb2xv8?t=1414.0486603120037s&enablejsapi=1&color=white&controls=1&iv_load_policy=3
        // youtube.com/watch?v=epBbbysk5cU

        let testValues: [(String, String)] = [
            ("https://youtu.be/dtp6b76pMak", "dtp6b76pMak"),
            ("https://m.youtube.com/shorts/jH_QIBtX1gY", "jH_QIBtX1gY"),
            ("https://www.youtube.com/watch?v=epBbbysk5cU", "epBbbysk5cU"),
            ("https://piped.video/watch?v=VZIm_2MgdeA", "VZIm_2MgdeA"),
            ("https://www.youtube.com/embed/Udl16tb2xv8?t=1414.0486603120037s&enablejsapi=1&color=white&controls=1&iv_load_policy=3", "Udl16tb2xv8"),
            ("youtube.com/watch?v=epBbbysk5cU", "epBbbysk5cU"),
            ("https://youtu.be/jWH8Aztd-zM?si=0GjLAkM5ZeeSsUoH", "jWH8Aztd-zM")
        ]

        for (url, expected) in testValues {
            let youtubeId = UrlService.getYoutubeIdFromUrl(url: URL(string: url)!)
            XCTAssertEqual(youtubeId, expected)
        }
    }
}

// swiftlint:enable all
