//
//  ChapterServiceTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData
import UnwatchedShared

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
            ),
            SendableChapter(
                title: "6",
                startTime: 60,
                endTime: 626,
                isActive: false
            ),
            SendableChapter(
                title: "7",
                startTime: 600.348,
                endTime: 628.252,
                isActive: false,
                category: .sponsor
            ),
            SendableChapter(
                title: "8",
                startTime: 626.0,
                endTime: 638,
                isActive: false
            )

            // 536.0-626.0: The use Cases,
            // 600.348-628.252: .sponsor,
            // 626.0-638: Outro
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
        XCTAssertEqual(newChapters[9].title, "6")
        XCTAssertEqual(newChapters[10].title, "7")
        XCTAssertEqual(newChapters[11].title, "8")
        XCTAssertEqual(newChapters.count, 12)

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
                    + " exceeds \(tolerance) seconds: \(timeDifference)"
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
        UserDefaults.standard.setValue(true, forKey: Const.mergeSponsorBlockChapters)
        let container = await DataController.previewContainer
        let modelContext = ModelContext(container)

        let video = ChapterServiceTestData.getSponsoredVideo()
        modelContext.insert(video)
        try? modelContext.save()

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
            XCTAssertGreaterThan(chapters?.count ?? 0, 0)
        } catch {
            XCTFail("error: \(error)")
        }
    }

    func testSponsorBlockChapters() async {
        let container = await DataController.previewContainer
        let modelContext = ModelContext(container)

        let video = ChapterServiceTestData.getSponsoredVideo()
        modelContext.insert(video)
        try? modelContext.save()

        do {
            let chapters = try await ChapterService.mergeSponsorSegments(
                youtubeId: "Fbphhg9ArXw", // video.youtubeId,
                videoId: video.persistentModelID,
                videoChapters: [],
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
        XCTAssertEqual(newChapters[0].category, .generated)

        XCTAssertEqual(newChapters[1].startTime, 10)
        XCTAssertEqual(newChapters[1].endTime, 20)
        XCTAssertEqual(newChapters[1].category, .sponsor)

        XCTAssertEqual(newChapters[2].startTime, 20)
        XCTAssertEqual(newChapters[2].endTime, 40)
        XCTAssertEqual(newChapters[2].category, .generated)

        XCTAssertEqual(newChapters[3].startTime, 40)
        XCTAssertEqual(newChapters[3].endTime, 50)
        XCTAssertEqual(newChapters[3].category, .sponsor)

        XCTAssertEqual(newChapters[4].startTime, 50)
        XCTAssertEqual(newChapters[4].endTime, 60)
        XCTAssertEqual(newChapters[4].category, .generated)
    }

    func testUpdateDuration() async {
        let container = await DataController.previewContainer
        let modelContext = ModelContext(container)

        let ch1 = Chapter(title: "0", time: 0, endTime: 10, category: nil)
        let ch2 = Chapter(title: "1", time: 10, endTime: nil, category: nil)
        let ch3 = Chapter(title: "2", time: 20, endTime: 30, category: nil)
        let ch4 = Chapter(title: "3", time: 30, endTime: nil, category: nil)
        let ch5 = Chapter(title: "4", time: 40, endTime: 50, category: nil)

        var chapters = [ch1, ch2, ch3, ch4, ch5]
        modelContext.insert(ch1)
        modelContext.insert(ch2)
        modelContext.insert(ch3)
        modelContext.insert(ch4)
        modelContext.insert(ch5)

        ChapterService.fillOutEmptyEndTimes(chapters: &chapters, duration: 70, container: container)

        XCTAssertEqual(chapters[1].endTime, 20)
        XCTAssertEqual(chapters[3].endTime, 40)
        XCTAssertEqual(chapters[5].endTime, 70)
    }

    func testUpdateDurationOneChapter() async {
        let container = await DataController.previewContainer
        var chapters = [Chapter(title: "0", time: 0, endTime: 10, category: nil)]
        ChapterService.fillOutEmptyEndTimes(chapters: &chapters, duration: 40, container: container)

        XCTAssertEqual(chapters[0].endTime, 10)
        XCTAssertEqual(chapters[1].endTime, 40)
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
            watchedDate: nil,
            isYtShort: false,
            bookmarkedDate: nil,
            clearedInboxDate: nil,
            createdDate: nil
        )
    }
}
// swiftlint:enable all
