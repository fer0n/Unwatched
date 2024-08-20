//
//  ChapterServiceTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData

// swiftlint:disable all
final class ChapterServiceTests: XCTestCase {

    func testCleanupMergedChapters() {
        let chapters = [
            SendableChapter(
                title: "1",
                startTime: 0,
                endTime: 10,
                isActive: false
            ),
            SendableChapter(
                title: "sponsor end 1",
                startTime: 5,
                endTime: 10,
                isActive: false,
                category: .sponsor
            ),
            SendableChapter(
                title: "2",
                startTime: 10,
                endTime: 20,
                isActive: false
            ),
            SendableChapter(
                title: "3",
                startTime: 20,
                endTime: 30,
                isActive: false
            ),
            SendableChapter(
                title: "sponsor start 3",
                startTime: 20,
                endTime: 23,
                isActive: false
            ),
            SendableChapter(
                title: "4",
                startTime: 30,
                endTime: 40,
                isActive: false
            ),
            SendableChapter(
                title: "5",
                startTime: 40,
                endTime: 60,
                isActive: false
            ),
            SendableChapter(
                title: "sponsor mid 5",
                startTime: 45,
                endTime: 55,
                isActive: false
            )
        ]
        let newChapters = ChapterService.cleanupMergedChapters(chapters)
        print("newChapters: \(newChapters)")

        // correct order
        XCTAssertEqual(newChapters[0].title, "1")
        XCTAssertEqual(newChapters[1].title, "sponsor end 1")
        XCTAssertEqual(newChapters[2].title, "2")
        XCTAssertEqual(newChapters[3].title, "sponsor start 3")
        XCTAssertEqual(newChapters[4].title, "3")
        XCTAssertEqual(newChapters[5].title, "4")
        XCTAssertEqual(newChapters[6].title, "5")
        XCTAssertEqual(newChapters[7].title, "sponsor mid 5")
        XCTAssertEqual(newChapters[8].title, "5")
        XCTAssertEqual(newChapters.count, 9)

        // start/end time of neighbors has to be within 2s tolerance
        let tolerance = Const.chapterTimeTolerance
        for index in 0..<newChapters.count - 1 {
            let currentChapter = newChapters[index]
            let nextChapter = newChapters[index + 1]

            // Ensure both chapters have endTime and startTime
            guard let currentEndTime = currentChapter.endTime else {
                XCTFail("Chapters \(currentChapter.description) or \(nextChapter.description) do not have valid end/start times.")
                continue
            }
            let nextStartTime = nextChapter.startTime

            // Check if the end time of the current chapter and the start time of the next chapter are within tolerance
            let timeDifference = abs(nextStartTime - currentEndTime)
            XCTAssertLessThanOrEqual(
                timeDifference,
                tolerance,
                "Time difference between \(currentChapter.description) and \(nextChapter.description)"
                    + "exceeds \(tolerance) seconds: \(timeDifference)"
            )
        }

        // make sure isActive stays correct
        XCTAssertEqual(newChapters[0].isActive, false)
        XCTAssertEqual(newChapters[1].isActive, false)
        XCTAssertEqual(newChapters[2].isActive, false)
        XCTAssertEqual(newChapters[3].isActive, false)
        XCTAssertEqual(newChapters[4].isActive, false)
        XCTAssertEqual(newChapters[5].isActive, false)
        XCTAssertEqual(newChapters[6].isActive, false)
        XCTAssertEqual(newChapters[7].isActive, false)
        XCTAssertEqual(newChapters[8].isActive, false)
    }

    func testSponsorBlock() async {
        let container = await DataController.previewContainer
        let modelContext = ModelContext(container)

        let video = ChapterServiceTestData.getSponsoredVideo()
        modelContext.insert(video)

        guard let videoDescription = video.videoDescription else {
            XCTFail("video description is nil")
            return
        }
        let realChapters = ChapterService.extractChapters(from: videoDescription, videoDuration: nil)

        do {
            let chapters = try await ChapterService.mergeSponsorSegments(
                youtubeId: video.youtubeId,
                videoId: video.persistentModelID,
                videoChapters: realChapters,
                container: container
            )
            print("chapters with duration: \(String(describing: chapters))")
        } catch {
            print("error: \(error)")
        }
    }

    func testNoRegularChapters() {
        let chapters = [
            SendableChapter(
                title: nil,
                startTime: 10,
                endTime: 20,
                isActive: false,
                category: .sponsor
            ),
            SendableChapter(
                title: nil,
                startTime: 40,
                endTime: 50,
                isActive: false,
                category: .sponsor
            )
        ]

        let newChapters = ChapterService.generateChapters(from: chapters, videoDuration: 60)
        print("newChapters: \(newChapters)")

        XCTAssertEqual(newChapters[0].startTime, 0)
        XCTAssertEqual(newChapters[0].endTime, 10)
        XCTAssertEqual(newChapters[0].category, .filler)

        XCTAssertEqual(newChapters[1].startTime, 10)
        XCTAssertEqual(newChapters[1].endTime, 20)
        XCTAssertEqual(newChapters[1].category, .sponsor)

        XCTAssertEqual(newChapters[2].startTime, 20)
        XCTAssertEqual(newChapters[2].endTime, 40)
        XCTAssertEqual(newChapters[2].category, .filler)

        XCTAssertEqual(newChapters[3].startTime, 40)
        XCTAssertEqual(newChapters[3].endTime, 50)
        XCTAssertEqual(newChapters[3].category, .sponsor)

        XCTAssertEqual(newChapters[4].startTime, 50)
        XCTAssertEqual(newChapters[4].endTime, 60)
        XCTAssertEqual(newChapters[4].category, .filler)
    }
}

struct ChapterServiceTestData {

    static func getSponsoredVideo() -> Video {
        let videoDescription = """
CHAPTERS
---------------------------------------------------
0:00 Intro
1:16 Cables not Included
2:44 Keep it Basic
4:43 An Old Workhorse
5:45 Too Soon?
6:37 But Now!
7:18 Hehe
7:52 Linus Mad.
9:02 TUF one
10:20 Some Light Gaming
11:15 Let's go to Spain
11:59 They know what they have.
12:42 Linus-plaining water cooling
13:59 Linus Knows French?
15:23 He didn't just say that...
17:10 Just a GPU?
17:49 So Much Room for Activities!
18:44 Rainbow Road
20:23 Credits
"""
        return Video(
            title: "I Can’t Believe These are Real - Reacting to Ridiculous PCs on Craigslist",
            url: URL(string: "https://www.youtube.com/watch?v=gIMOtNzjHL4"),
            youtubeId: "gIMOtNzjHL4",
            thumbnailUrl: nil,
            publishedDate: nil,
            updatedDate: nil,
            youtubeChannelId: nil,
            duration: nil,
            elapsedSeconds: nil,
            videoDescription: videoDescription,
            chapters: [],
            watched: false,
            isYtShort: false,
            bookmarkedDate: nil,
            clearedInboxDate: nil,
            createdDate: nil
        )
    }
}
// swiftlint:enable all
