//
//  ExportableTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData

class ExportableTests: XCTestCase {
    var container: ModelContainer!

    @MainActor override func setUp() {
        super.setUp()
        container = DataController.previewContainer
    }

    func testSubscription() {
        let customAspectRatio: Double = 16/9
        let sub = TestData.subscription(customAspectRatio: customAspectRatio)
        let context = ModelContext(container)
        context.insert(sub)
        try? context.save()

        let exported = sub.toExport
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(exported) else {
            XCTFail("Failed to encode subscription")
            return
        }

        // import
        let importedData = data
        let decoder = JSONDecoder()
        do {
            let sendableSub = try decoder.decode(SendableSubscription.self, from: importedData)
            let importedSub = sendableSub.toModel

            XCTAssertEqual(importedSub.link, sub.link)
            XCTAssertEqual(importedSub.title, sub.title)
            XCTAssertEqual(importedSub.author, sub.author)
            XCTAssertEqual(importedSub.subscribedDate, sub.subscribedDate)
            XCTAssertEqual(importedSub.placeVideosIn, sub.placeVideosIn)
            XCTAssertEqual(importedSub.isArchived, sub.isArchived)
            XCTAssertEqual(importedSub.customSpeedSetting, sub.customSpeedSetting)

            XCTAssertEqual(importedSub.customAspectRatio, sub.customAspectRatio)
            XCTAssertEqual(importedSub.customAspectRatio, customAspectRatio)

            XCTAssertEqual(importedSub.mostRecentVideoDate, sub.mostRecentVideoDate)
            XCTAssertEqual(importedSub.youtubeChannelId, sub.youtubeChannelId)
            XCTAssertEqual(importedSub.youtubePlaylistId, sub.youtubePlaylistId)
            XCTAssertEqual(importedSub.youtubeUserName, sub.youtubeUserName)
            XCTAssertEqual(importedSub.thumbnailUrl, sub.thumbnailUrl)

        } catch {
            XCTFail("Decoding failed with error: \(error)")
        }
    }
}
