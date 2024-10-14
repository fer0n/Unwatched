//
//  DataSpeedTests.swift
//  Unwatched
//

import XCTest
import SwiftData
import UnwatchedShared

// swiftlint:disable all
final class DataSpeedTests: XCTestCase {

    func testFilterShorts() async {
        let modelContext = await getModelContext()
        let sort = SortDescriptor<Video>(\.clearedInboxDate, order: .reverse)
        let filter = VideoListView.getVideoFilter(showShorts: true, nil)
        let fetch = FetchDescriptor<Video>(predicate: filter, sortBy: [sort])

        measure {
            guard let videos = try? modelContext.fetch(fetch) else {
                XCTFail("Failed to fetch videos")
                return
            }

            print("Videos: \(videos.count)")
        }
    }

    // MARK: Helpers

    func getModelContext() async -> ModelContext {
        let container = await DataController.previewContainer
        let data = (try? loadFileData(for: "backup-file.json"))!
        UserDataService.importBackup(data, container: container)
        return ModelContext(container)
    }

    func loadFileData(for fixture: String) throws -> Data {
        let url = testDataDirectory().appendingPathComponent(fixture)
        return try Data(contentsOf: url)
    }

    func testDataDirectory(path: String = #file) -> URL {
        let url = URL(fileURLWithPath: path)
        let testsDir = url.deletingLastPathComponent()
        let res = testsDir.appendingPathComponent("TestData")
        return res
    }

}

// swiftlint:enable all
