//
//  DataSpeedTests.swift
//  Unwatched
//

import XCTest
import SwiftData

// swiftlint:disable all
final class UrlServiceTests: XCTestCase {

    func testExtractYoutubeId() async {
        let testValues: [(String, String)] = [
            // youtu.be short links
            ("https://youtu.be/dtp6b76pMak", "dtp6b76pMak"),
            ("https://youtu.be/jWH8Aztd-zM?si=0GjLAkM5ZeeSsUoH", "jWH8Aztd-zM"),

            // shorts
            ("https://m.youtube.com/shorts/jH_QIBtX1gY", "jH_QIBtX1gY"),

            // watch?v= variants
            ("https://www.youtube.com/watch?v=epBbbysk5cU", "epBbbysk5cU"),
            ("https://www.youtube.com/watch/?v=epBbbysk5cU", "epBbbysk5cU"),
            ("https://m.youtube.com/watch?v=Sa-FI9exq8o&pp=ygUTRGV2aWwgR2VvcmdpYSBjb3Zlcg%3D%3D", "Sa-FI9exq8o"),
            ("youtube.com/watch?v=epBbbysk5cU", "epBbbysk5cU"),

            // `v` is not the first query parameter
            ("https://www.youtube.com/watch?app=desktop&v=Gm_TfuohxkU", "Gm_TfuohxkU"),
            ("https://m.youtube.com/watch?app=desktop&v=Gm_TfuohxkU", "Gm_TfuohxkU"),
            ("https://www.youtube.com/watch?feature=shared&v=Gm_TfuohxkU", "Gm_TfuohxkU"),
            ("https://www.youtube.com/watch/?app=desktop&v=Gm_TfuohxkU", "Gm_TfuohxkU"),

            // third-party (piped)
            ("https://piped.video/watch?v=VZIm_2MgdeA", "VZIm_2MgdeA"),
            ("https://piped.video/watch?quality=hd&v=VZIm_2MgdeA", "VZIm_2MgdeA"),

            // embed
            ("https://www.youtube.com/embed/Udl16tb2xv8?t=1414.0486603120037s&enablejsapi=1&color=white&controls=1&iv_load_policy=3", "Udl16tb2xv8"),

            // live
            ("https://www.youtube.com/live/l6p4bWw_oEk?t=1h54m11s", "l6p4bWw_oEk"),

            // google redirect URL
            ("https://www.google.com/url?sa=t&source=web&rct=j&opi=89978449&url=https://www.youtube.com/watch%3Fv%3D1K5oDtVAYzk&ved=2ahUKEwjTwKmPx6SLAxUHTDABHQ0WDRsQwqsBegQIYxAG&usg=AOvVaw2wqHdPMbGG4kUgVDx4nR-w", "1K5oDtVAYzk")
        ]

        for (url, expected) in testValues {
            let youtubeId = UrlService.getYoutubeIdFromUrl(url: URL(string: url)!)
            XCTAssertEqual(youtubeId, expected, "Failed for URL: \(url)")
        }
    }
}

// swiftlint:enable all
