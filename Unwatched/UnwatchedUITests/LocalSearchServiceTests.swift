//
//  LocalSearchServiceTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData
import UnwatchedShared

final class LocalSearchServiceTests: XCTestCase {
    func testUploadDateFiltersBookmarksAndLibrary() async throws {
        let context = DataProvider.newContext()
        let token = "zqxlocalsearch"
        let recent = Date.now.addingTimeInterval(-2 * 86_400)
        let old = Date.now.addingTimeInterval(-60 * 86_400)
        let videos = [
            Video(title: "\(token) recent", url: nil, youtubeId: "\(token)1", publishedDate: recent),
            Video(title: "\(token) old", url: nil, youtubeId: "\(token)2", publishedDate: old),
            Video(title: "\(token) undated", url: nil, youtubeId: "\(token)3"),
            Video(title: "\(token) bookmark", url: nil, youtubeId: "\(token)4", publishedDate: recent, bookmarkedDate: .now),
            Video(title: "\(token) old bookmark", url: nil, youtubeId: "\(token)5", publishedDate: old, bookmarkedDate: .now)
        ]
        videos.forEach(context.insert)
        try context.save()

        let sources: Set<SearchSource> = [.bookmarks, .library]
        let anytime = await LocalSearchService.search(query: token, sources: sources)
        XCTAssertEqual(Set(anytime.bookmarks.map(\.youtubeId)), ["\(token)4", "\(token)5"])
        XCTAssertEqual(Set(anytime.videos.map(\.youtubeId)), ["\(token)1", "\(token)2", "\(token)3"])

        let thisWeek = await LocalSearchService.search(
            query: token,
            sources: sources,
            publishedAfter: SearchFilter.UploadDate.thisWeek.startDate
        )
        XCTAssertEqual(thisWeek.bookmarks.map(\.youtubeId), ["\(token)4"])
        XCTAssertEqual(thisWeek.videos.map(\.youtubeId), ["\(token)1"])

        videos.forEach(context.delete)
        try context.save()
    }
}
