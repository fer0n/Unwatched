//
//  DataSpeedTests.swift
//  Unwatched
//

import XCTest
import SwiftData
import UnwatchedShared

// swiftlint:disable all
final class DataSpeedTests: XCTestCase {
    func testAsyncVideoLoading() async {
        let data = (try? loadFileData(for: "backup-file.json"))!
        UserDataService.importBackup(data)

        let videoListVM = VideoListVM()
        let sorting = SortDescriptor<Video>(\.publishedDate)
        videoListVM.setSorting([sorting])

        measure {
            let exp = expectation(description: "Async task finished")
            Task {
                await videoListVM.updateData(force: true)
                exp.fulfill()
            }
            wait(for: [exp], timeout: 10.0)
        }
    }

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
        let data = (try? loadFileData(for: "backup-file.json"))!
        UserDataService.importBackup(data)
        return DataProvider.newContext()
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
