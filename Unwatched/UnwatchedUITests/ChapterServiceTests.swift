//
//  ChapterServiceTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData
import UnwatchedShared

// swiftlint:disable all
final class ChapterServiceTests: XCTestCase {

    func testChapterOverrides() {
        let data: [(
            regular: [SendableChapter],
            external: [SendableChapter],
            exptected: [SendableChapter]
        )] = [
            // empty
            (
                regular: [],
                external: [],
                exptected: []
            ),

            // no overlap
            (
                regular: [
                    .init(0,    to: 30,     category: nil),
                ],
                external: [
                    .init(50,   to: 80,    category: .sponsor)
                ],
                exptected: [
                    .init(0,    to: 30,     category: nil),
                    .init(50,   to: 80,    category: .sponsor)
                ]
            ),

            // continuous
            (
                regular: [
                    .init(0,    to: 30,     category: nil),
                ],
                external: [
                    .init(30,   to: 100,    category: .sponsor)
                ],
                exptected: [
                    .init(0,    to: 30,     category: nil),
                    .init(30,  to: 100,    category: .sponsor)
                ]
            ),

            // overlap
            (
                regular: [
                    .init(0,    to: 50,     category: nil),
                ],
                external: [
                    .init(30,   to: 100,    category: .sponsor)
                ],
                exptected: [
                    .init(0,    to: 30,     category: nil),
                    .init(30,   to: 100,    category: .sponsor)
                ]
            ),

            // overlap 2
            (
                regular: [
                    .init(0,    to: 50,     category: .sponsor),
                ],
                external: [
                    .init(30,   to: 100,    category: nil)
                ],
                exptected: [
                    .init(0,    to: 50,     category: .sponsor),
                    .init(50,   to: 100,    category: nil)
                ]
            ),

            // same start, different end
            (
                regular: [
                    .init(30,    to: 50,     category: nil),
                ],
                external: [
                    .init(30,   to: 100,    category: .sponsor)
                ],
                exptected: [
                    .init(30,  to: 100,    category: .sponsor)
                ]
            ),

            // same start, different end 2
            (
                regular: [
                    .init(30,    to: 50,     category: .sponsor),
                ],
                external: [
                    .init(30,   to: 100,    category: nil)
                ],
                exptected: [
                    .init(30,  to: 50,    category: .sponsor),
                    .init(50,  to: 100,    category: nil)
                ]
            ),

            // different start, same end
            (
                regular: [
                    .init(10,    to: 80,     category: nil),
                ],
                external: [
                    .init(30,   to: 80,    category: .sponsor)
                ],
                exptected: [
                    .init(10,  to: 30,    category: nil),
                    .init(30,  to: 80,    category: .sponsor)
                ]
            ),

            // different start, same end 2
            (
                regular: [
                    .init(10,    to: 80,     category: .sponsor),
                ],
                external: [
                    .init(30,   to: 80,    category: nil)
                ],
                exptected: [
                    .init(10,  to: 80,    category: nil),
                ]
            ),

            // nested
            (
                regular: [
                    .init(10,    to: 80,     category: nil),
                    .init(30,   to: 50,    category: .sponsor)
                ],
                external: [

                ],
                exptected: [
                    .init(10,    to: 30,     category: nil),
                    .init(30,   to: 50,    category: .sponsor),
                    .init(50,    to: 80,     category: nil)
                ]
            ),

            // nested 2
            (
                regular: [
                    .init(30,   to: 50,    category: nil)
                ],
                external: [
                    .init(10,    to: 80,     category: .sponsor)
                ],
                exptected: [
                    .init(10,    to: 80,     category: .sponsor)
                ]
            )
        ]

        for (regular, external, expected) in data {
            let result = ChapterService.mergeSponsorSegments(
                regular,
                sponsorSegments: external,
                duration: nil
            )
            let isEqual = checkChapterEqual(result, expected)
            XCTAssertTrue(isEqual)
            if !isEqual {
                print("input", regular)
                print("expected", expected)
                print("result", result)
                print("\n")
            }
        }
    }

    func testCleanExternalChapters() {
        let data: [(input: [SendableChapter], exptected: [SendableChapter])] = [
            // empty
            (
                input: [],
                exptected: []
            ),

            // no overlap
            (
                input: [
                    .init(0,    to: 30,     category: .sponsor),
                    .init(50,   to: 80,    category: .sponsor)
                ],
                exptected: [
                    .init(0,    to: 30,     category: .sponsor),
                    .init(50,   to: 80,    category: .sponsor)
                ]
            ),

            // continuous
            (
                input: [
                    .init(0,    to: 30,     category: .sponsor),
                    .init(30,   to: 100,    category: .sponsor)
                ],
                exptected: [
                    .init(0,  to: 100,    category: .sponsor)
                ]
            ),

            // overlap
            (
                input: [
                    .init(0,    to: 50,     category: .sponsor),
                    .init(30,   to: 100,    category: .sponsor)
                ],
                exptected: [
                    .init(0,  to: 100,    category: .sponsor)
                ]
            ),

            // same start, different end
            (
                input: [
                    .init(30,    to: 50,     category: .sponsor),
                    .init(30,   to: 100,    category: .sponsor)
                ],
                exptected: [
                    .init(30,  to: 100,    category: .sponsor)
                ]
            ),

            // different start, same end
            (
                input: [
                    .init(10,    to: 80,     category: .sponsor),
                    .init(30,   to: 80,    category: .sponsor)
                ],
                exptected: [
                    .init(10,  to: 80,    category: .sponsor)
                ]
            ),

            // nested
            (
                input: [
                    .init(10,    to: 80,     category: .sponsor),
                    .init(30,   to: 50,    category: .sponsor)
                ],
                exptected: [
                    .init(10,  to: 80,    category: .sponsor)
                ]
            ),

            // different category, stay the same
            (
                input: [
                    .init(10,    to: 80,     category: .sponsor),
                    .init(30,   to: 50,    category: .intro)
                ],
                exptected: [
                    .init(10,    to: 80,     category: .sponsor),
                    .init(30,   to: 50,    category: .intro)
                ]
            )
        ]

        for (input, expected) in data {
            let result = ChapterService.cleanExternalChapters(input)
            let isEqual = checkChapterEqual(result, expected)
            XCTAssertTrue(isEqual)
            if !isEqual {
                print("input", input)
                print("expected", expected)
                print("result", result)
                print("\n")
            }
        }
    }

    func testOverride2() {
        let chapters: [SendableChapter] = [
            .init(0,    to: 81,     "Intro"),
            .init(81,   to: 612,    "Crazy Tundra truck"),
            .init(612,  to: 913,    "Li Auto van"),
            .init(913,  to: 987,    "Trivia"),
            .init(987,  to: 1038,   "AT&T (Sponsored)"),
            .init(1038, to: 2434,   "New Mac Mini"),
            .init(2434, to: 4000,   "Apps that we love/hate"),
            .init(4000, to: 4052,   "AT&T (Sponsored)"),
            .init(4052, to: 6384,   "Overrated or Underrated?"),
            .init(6384, to: 6687,   "Trivia answers"),
            .init(6687, to: nil,    "Outro")
        ]

        let sponsorSegments: [SendableChapter] = [
            .init(975, to: 1038.257, category: .sponsor),
            .init(3987.255, to: 4051.21, category: .sponsor),
            .init(3989.648, to: 3991.064, category: .sponsor)
        ]

        let expected: [SendableChapter] = [
            .init(0,    to: 81,     "Intro"),
            .init(81,   to: 612,    "Crazy Tundra truck"),
            .init(612,  to: 913,    "Li Auto van"),
            .init(913,  to: 975,    "Trivia"),

            .init(975, to: 1038.257, category: .sponsor),

            .init(1038.257, to: 2434,   "New Mac Mini"),
            .init(2434, to: 3987.255,   "Apps that we love/hate"),

            .init(3987.255, to: 4051.21, category: .sponsor),

            .init(4051.21, to: 6384,   "Overrated or Underrated?"),
            .init(6384, to: 6687,   "Trivia answers"),
            .init(6687, to: nil,    "Outro")
        ]

        doChapterMergeTest(
            chapters: chapters,
            sponsorSegments: sponsorSegments,
            duration: nil,
            expected: expected
        )
    }

    func testNestedChapter() {
        let chapters: [SendableChapter] = [
            .init(0,    "ch1"),
            .init(30,   "ch2"),
            .init(100,  "ch3"),
            .init(150,  "ch4")
        ]

        let sponsorSegments: [SendableChapter] = [
            .init(startTime: 20, endTime: 110, category: .sponsor),
        ]

        let expected: [SendableChapter] = [
            .init(0, to: 20, "ch1"),

            .init(20, to: 110, category: .sponsor),

            .init(120, to: 150,  "ch3"),
            .init(150,  "ch4")
        ]

        doChapterMergeTest(
            chapters: chapters,
            sponsorSegments: sponsorSegments,
            duration: nil,
            expected: expected
        )
    }

    func testOverlappingChapter() {
        let chapters: [SendableChapter] = [
            .init(0,    "Intro"),
            .init(165,  "New rumored Apple accessories"),
            .init(361,  "Snapdragon X Elite"),
            .init(791,  "Apple's hearing test"),
            .init(1474, "Samsung Tri-fold rumors"),
            .init(1679, "Trivia question"),
            .init(1750, "AT&T (Sponsored)"),
            .init(1810, "Orion Vs Spectacles discussion"),
            .init(4330, "BOOX Palma 2 announced"),
            .init(4494, "Trivia question"),
            .init(4586, "AT&T (Sponsored)"),
            .init(4655, "Marques interviews Boz from Meta"),
            .init(5537, "Trivia answers")
        ]

        let sponsorSegments: [SendableChapter] = [
            .init(startTime: 1753.645, endTime: 1810.567, category: .sponsor),
            .init(startTime: 4586.197, endTime: 4655.412, category: .sponsor)
        ]

        let expected: [SendableChapter] = [
            .init(0,        to: 165,        "Intro"),
            .init(165,      to: 361,        "New rumored Apple accessories"),
            .init(361,      to: 791,        "Snapdragon X Elite"),
            .init(791,      to: 1474,       "Apple's hearing test"),
            .init(1474,     to: 1679,       "Samsung Tri-fold rumors"),
            .init(1679,     to: 1750,       "Trivia question"),
            .init(1750,     to: 1753.645,   "AT&T (Sponsored)"),

            .init(1753.645, to: 1810.567, category: .sponsor),

            .init(1810.567, to: 4330,       "Orion Vs Spectacles discussion"),
            .init(4330,     to: 4494,       "BOOX Palma 2 announced"),
            .init(4494,     to: 4586.197,   "Trivia question"),

            .init(4586.197, to: 4655.412, category: .sponsor),

            .init(4655.412, to: 5537,       "Marques interviews Boz from Meta"),
            .init(5537,                     "Trivia answers")
        ]

        doChapterMergeTest(
            chapters: chapters,
            sponsorSegments: sponsorSegments,
            duration: nil,
            expected: expected
        )
    }

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
        let modelContext = DataProvider.newContext()

        let video = ChapterServiceTestData.getSponsoredVideo()
        modelContext.insert(video)
        try? modelContext.save()

        guard let videoDescription = video.videoDescription else {
            XCTFail("video description is nil")
            return
        }
        let realChapters = ChapterService.extractChapters(from: videoDescription, videoDuration: nil)

        do {
            let chapters = try await ChapterService.mergeOrGenerateChapters(
                youtubeId: video.youtubeId,
                videoId: video.persistentModelID,
                videoChapters: realChapters
            )
            print("chapters with duration: \(String(describing: chapters))")
            XCTAssertGreaterThan(chapters?.count ?? 0, 0)
        } catch {
            XCTFail("error: \(error)")
        }
    }

    func testSponsorBlockChapters() async {
        let modelContext = DataProvider.newContext()
        let video = ChapterServiceTestData.getSponsoredVideo()
        modelContext.insert(video)
        try? modelContext.save()

        do {
            let chapters = try await ChapterService.mergeOrGenerateChapters(
                youtubeId: "Fbphhg9ArXw", // video.youtubeId,
                videoId: video.persistentModelID,
                videoChapters: []
            )
            print("chapters with duration: \(String(describing: chapters))")
        } catch {
            print("error: \(error)")
        }
    }

    func testSponsorOverlap() {
        let chapters: [SendableChapter] = [
            .init(0,    "Intro"),
            .init(64,   "Premise"),
            .init(132,  "Nene"),
            .init(461,  "Alyssa"),
            .init(639,  "Michael"),
            .init(796,  "Skosche"),
            .init(923,  "The Leader"),
            .init(1458, "Conclusion"),
            .init(1539, "Outro")
        ]

        let sponsorSegments: [SendableChapter] = [
            .init(startTime: 36.293, endTime: 54.267, category: .sponsor),
            .init(startTime: 1539.968, endTime: 1618.18, category: .sponsor)
        ]

        let expected: [SendableChapter] = [
            .init(0,        to: 36.293,    "Intro"),
            .init(36.293,   to: 54.267,    category: .sponsor),
            .init(54.267,   to: 64,        "Intro"),
            .init(64,       to: 132,       "Premise"),
            .init(132,      to: 461,       "Nene"),
            .init(461,      to: 639,       "Alyssa"),
            .init(639,      to: 796,       "Michael"),
            .init(796,      to: 923,       "Skosche"),
            .init(923,      to: 1458,      "The Leader"),
            .init(1458,     to: 1539,  "Conclusion"),
            .init(1539,                 "Outro"),
            .init(1539.968, to: 1618.18,  category: .sponsor)
        ]

        doChapterMergeTest(
            chapters: chapters,
            sponsorSegments: sponsorSegments,
            duration: nil,
            expected: expected
        )
    }

    func testOverrideRegularChapter() async {

        let chapters: [SendableChapter] = [
            .init(0,    "Intro"),
            .init(20,   "Sponsored Ad"),
            .init(50,   "Quest Plus Games"),
            .init(147,  "Heroes Battle: Dark Sword"),
            .init(168,  "Dumb Ways Feel for All"),
            .init(186,  "Living room")
        ]

        let sponsorSegments: [SendableChapter] = [
            .init(startTime: 20.07, endTime: 49.616, category: .sponsor)
        ]

        let expected: [SendableChapter] = [
            .init(0,        to: 20.07,  "Intro"),
            .init(20.07,    to: 49.616, category: .sponsor),
            .init(49.616,   to: 147,    "Quest Plus Games"),
            .init(147,      to: 168,    "Heroes Battle: Dark Sword"),
            .init(168,      to: 186,    "Dumb Ways Feel for All"),
            .init(186,                  "Living room")
        ]

        doChapterMergeTest(
            chapters: chapters,
            sponsorSegments: sponsorSegments,
            duration: nil,
            expected: expected
        )
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
        let modelContext = DataProvider.newContext()

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

        ChapterService.fillOutEmptyEndTimes(chapters: &chapters, duration: 70, context: modelContext)

        XCTAssertEqual(chapters[1].endTime, 20)
        XCTAssertEqual(chapters[3].endTime, 40)
        XCTAssertEqual(chapters[5].endTime, 70)
    }

    func testUpdateDurationOneChapter() async {
        let context = DataProvider.newContext()
        var chapters = [Chapter(title: "0", time: 0, endTime: 10, category: nil)]
        ChapterService.fillOutEmptyEndTimes(chapters: &chapters, duration: 40, context: context)

        XCTAssertEqual(chapters[0].endTime, 10)
        XCTAssertEqual(chapters[1].endTime, 40)
    }

    func testMergeThenDuration() async {
        // params
        let chapters = [
            Chapter(title: "0", time: 0, endTime: 10, category: nil),
            Chapter(title: "1", time: 10, endTime: nil, category: nil),
            Chapter(title: "2", time: 20, endTime: 30, category: nil),
            Chapter(title: "3", time: 30, endTime: nil, category: nil),
            Chapter(title: "4", time: 40, endTime: nil, category: nil)
        ]
        let externalChapters = [
            SendableChapter(title: "ad", startTime: 50, endTime: 60, category: .sponsor)
        ]
        let duration: Double = 70


        // -- Setup original chapters
        let modelContext = DataProvider.newContext()

        chapters.forEach(modelContext.insert)

        let video = Video(title: "My Video", url: nil, youtubeId: "1234")
        modelContext.insert(video)

        video.chapters = chapters

        print("chapters before: \(chapters)")
        try? modelContext.save()


        // -- Add sponsor chapter
        let sendableChapters = chapters.map { $0.toExport }


        // add merged chapters
        var newChapters = ChapterService.updateDurationAndEndTime(in: sendableChapters, videoDuration: nil)
        newChapters.append(contentsOf: externalChapters)
        newChapters.sort(by: { $0.startTime < $1.startTime})

        // update end time/duration correctly
        newChapters = ChapterService.cleanupMergedChapters(newChapters)
        print("chapters time update & merged: \(newChapters)")


        // -- Update duration after merged chapters are complete
        let result = ChapterService.updateDuration(in: newChapters)
        print("chapters duration: \(result)")

        let modelChapters = result.map(\.getChapter)
        for chapter in modelChapters {
            modelContext.insert(chapter)
        }

        guard let loadedVideo = try? modelContext.fetch(FetchDescriptor<Video>()).first else {
            XCTFail("no video")
            return
        }

        loadedVideo.mergedChapters = modelChapters
        print("modelChapters: \(modelChapters)")

        // add duration afterwards
        VideoService.updateDuration(loadedVideo, duration: duration)
        ChapterService.updateDuration(loadedVideo, duration: duration)
        try? modelContext.save()


        guard let finalVideo = try? modelContext.fetch(FetchDescriptor<Video>()).first else {
            XCTFail("no video")
            return
        }

        print("finalVideo mergedChapters: \(finalVideo.mergedChapters?.sorted(by: { $0.startTime < $1.startTime }))")
        print("finalVideo chapters: \(finalVideo.chapters?.sorted(by: { $0.startTime < $1.startTime }))")
        print("finalVideo sortedChapters: \(finalVideo.sortedChapters)")

        let final = Video.getSortedChapters(finalVideo.mergedChapters, finalVideo.mergedChapters)

        print("chapters sorted: \(final)")

        // TODO:
        // - problem: final chapter duration doesn't get updated, because .sponsor is placed after and has an end date
        // -> update both "chapters" and last regular "mergedChapter" duration with final stop time
        // -> re-run chapter cleanup for merged chapters afterwards to adjust chapters & end time accordingly
        //
        // - problem: unticking a merged chapter never updates the regular chapter
        // -> add uuid for regular chapters, link them in merged chapter (or maybe via persistentId)
        // -> update regular chapter when merged chapter is unticked/ticked?
        //
        // maybe: re-extract chapters from description when switching back to non-merged chapters? (reindex every single chapter? probably not)
        // ask marco?


        XCTAssertEqual(final[1].endTime, 20)
        XCTAssertEqual(final[3].endTime, 40)

        XCTAssertEqual(final[4].endTime, 50)
        XCTAssertEqual(final[4].title, "4")

        XCTAssertEqual(final[5].startTime, 50)
        XCTAssertEqual(final[5].endTime, 60)
        XCTAssertEqual(final[5].title, "ad")

        // XCTAssertEqual(final[6].title, "4") generated chapter
        XCTAssertEqual(final[6].startTime, 60)
        XCTAssertEqual(final[6].endTime, 70)
    }

    func testChapterRecognition() {
        let testValues = [
            // no chapters
            (
                """
                Fleischmann, M., and S. Pons. 1989. Electrochemically induced nuclear fusion of deuterium. Journal of Electroanalytical Chemistry 261:301–308.
                Fleischmann, M., and S. Pons et. al. 1990. Calorimetry of the palladium-deuterium-heavy water system. Journal of Electroanalytical Chemistry 287:293–348.
                Jones, S.E, E.P Palmer, J.B Czirr, D.L Decker, G.L Jensen, J.M Thorne, S.F Taylor, and J Rafelski. 1989. Observation of cold nuclear fusion in condensed matter. Nature 388:737–740.
                """,
                []
            ),

            // title then time
            (
                """
                CHAPTERS

                Chapter 1: 10:13
                Chapter 2: 20:45
                Chapter 3: 30:22
                """,
                [
                    SendableChapter(title: "Chapter 1", startTime: 10 * 60 + 13, endTime: 20 * 60 + 45),
                    SendableChapter(title: "Chapter 2", startTime: 20 * 60 + 45, endTime: 30 * 60 + 22),
                    SendableChapter(title: "Chapter 3", startTime: 30 * 60 + 22, endTime: nil)
                ]
            ),

            // time then title
            (
                """
                No Leading Zeroes

                0:00 Intro,
                1:30 Overview,
                03:45 Topic 1,
                05:10 Topic 2,
                07:25 Conclusion
                """,
                [
                    SendableChapter(title: "Intro", startTime: 0, endTime: 1 * 60 + 30),
                    SendableChapter(title: "Overview", startTime: 1 * 60 + 30, endTime: 3 * 60 + 45),
                    SendableChapter(title: "Topic 1", startTime: 3 * 60 + 45, endTime: 5 * 60 + 10),
                    SendableChapter(title: "Topic 2", startTime: 5 * 60 + 10, endTime: 7 * 60 + 25),
                    SendableChapter(title: "Conclusion", startTime: 7 * 60 + 25, endTime: nil)
                ]
            ),
            (
                """
                0:00 Intro
                1:30 Overview
                3:45 Topic 1
                5:10 Topic 2
                7:25 Conclusion
                """,
                [
                    SendableChapter(title: "Intro", startTime: 0, endTime: 1 * 60 + 30),
                    SendableChapter(title: "Overview", startTime: 1 * 60 + 30, endTime: 3 * 60 + 45),
                    SendableChapter(title: "Topic 1", startTime: 3 * 60 + 45, endTime: 5 * 60 + 10),
                    SendableChapter(title: "Topic 2", startTime: 5 * 60 + 10, endTime: 7 * 60 + 25),
                    SendableChapter(title: "Conclusion", startTime: 7 * 60 + 25, endTime: nil)
                ]
            ),
            (
                """
                00:00 - Introduction;
                01:30 - Overview;
                03:45 - Topic 1,
                05:10 - Topic 2,
                07:25 - Conclusion
                """,
                [
                    SendableChapter(title: "Introduction", startTime: 0, endTime: 1 * 60 + 30),
                    SendableChapter(title: "Overview", startTime: 1 * 60 + 30, endTime: 3 * 60 + 45),
                    SendableChapter(title: "Topic 1", startTime: 3 * 60 + 45, endTime: 5 * 60 + 10),
                    SendableChapter(title: "Topic 2", startTime: 5 * 60 + 10, endTime: 7 * 60 + 25),
                    SendableChapter(title: "Conclusion", startTime: 7 * 60 + 25, endTime: nil)
                ]
            ),
            (
                """
                • 00:00 Intro
                • 01:30 Overview
                • 03:45 Topic 1
                - 05:10 Topic 2
                - 07:25 Conclusion
                """,
                [
                    SendableChapter(title: "Intro", startTime: 0, endTime: 1 * 60 + 30),
                    SendableChapter(title: "Overview", startTime: 1 * 60 + 30, endTime: 3 * 60 + 45),
                    SendableChapter(title: "Topic 1", startTime: 3 * 60 + 45, endTime: 5 * 60 + 10),
                    SendableChapter(title: "Topic 2", startTime: 5 * 60 + 10, endTime: 7 * 60 + 25),
                    SendableChapter(title: "Conclusion", startTime: 7 * 60 + 25, endTime: nil)
                ]
            ),
            (
                """
                Chapters:
                Intro 00:00
                Crazy Tundra truck 01:21
                Li Auto van 10:12
                Trivia 15:13
                AT&T (Sponsored) 16:27
                New Mac Mini 17:18
                Apps that we love/hate 40:34
                AT&T (Sponsored) 01:06:40
                Overrated or Underrated? 01:07:32
                Trivia answers 01:46:24
                Outro 01:51:27
                """,
                [
                    SendableChapter(title: "Intro", startTime: 0, endTime: 1 * 60 + 21),
                    SendableChapter(title: "Crazy Tundra truck", startTime: 1 * 60 + 21, endTime: 10 * 60 + 12),
                    SendableChapter(title: "Li Auto van", startTime: 10 * 60 + 12, endTime: 15 * 60 + 13),
                    SendableChapter(title: "Trivia", startTime: 15 * 60 + 13, endTime: 16 * 60 + 27),
                    SendableChapter(title: "AT&T (Sponsored)", startTime: 16 * 60 + 27, endTime: 17 * 60 + 18),
                    SendableChapter(title: "New Mac Mini", startTime: 17 * 60 + 18, endTime: 40 * 60 + 34),
                    SendableChapter(title: "Apps that we love/hate", startTime: 40 * 60 + 34, endTime: 3600 + 6 * 60 + 40),
                    SendableChapter(title: "AT&T (Sponsored)", startTime: 3600 + 6 * 60 + 40, endTime: 3600 + 7 * 60 + 32),
                    SendableChapter(title: "Overrated or Underrated?", startTime: 1 * 3600 + 7 * 60 + 32, endTime: 3600 + 46 * 60 + 24),
                    SendableChapter(title: "Trivia answers", startTime: 3600 + 46 * 60 + 24, endTime: 3600 + 51 * 60 + 27),
                    SendableChapter(title: "Outro", startTime: 3600 + 51 * 60 + 27, endTime: nil)
                ]
            ),
            (
                """
                Chapters:
                00:00 Intro
                01:21 Crazy Tundra truck
                10:12 Li Auto van
                15:13 Trivia
                16:27 AT&T (Sponsored)
                17:18 New Mac Mini
                40:34 Apps that we love/hate
                01:06:40 AT&T (Sponsored)
                01:07:32 Overrated or Underrated?
                01:46:24 Trivia answers
                01:51:27 Outro
                """,
                [
                    SendableChapter(title: "Intro", startTime: 0, endTime: 1 * 60 + 21),
                    SendableChapter(title: "Crazy Tundra truck", startTime: 1 * 60 + 21, endTime: 10 * 60 + 12),
                    SendableChapter(title: "Li Auto van", startTime: 10 * 60 + 12, endTime: 15 * 60 + 13),
                    SendableChapter(title: "Trivia", startTime: 15 * 60 + 13, endTime: 16 * 60 + 27),
                    SendableChapter(title: "AT&T (Sponsored)", startTime: 16 * 60 + 27, endTime: 17 * 60 + 18),
                    SendableChapter(title: "New Mac Mini", startTime: 17 * 60 + 18, endTime: 40 * 60 + 34),
                    SendableChapter(title: "Apps that we love/hate", startTime: 40 * 60 + 34, endTime: 3600 + 6 * 60 + 40),
                    SendableChapter(title: "AT&T (Sponsored)", startTime: 3600 + 6 * 60 + 40, endTime: 3600 + 7 * 60 + 32),
                    SendableChapter(title: "Overrated or Underrated?", startTime: 1 * 3600 + 7 * 60 + 32, endTime: 3600 + 46 * 60 + 24),
                    SendableChapter(title: "Trivia answers", startTime: 3600 + 46 * 60 + 24, endTime: 3600 + 51 * 60 + 27),
                    SendableChapter(title: "Outro", startTime: 3600 + 51 * 60 + 27, endTime: nil)
                ]
            ),
        ]

        for (description, expected) in testValues {
            let chapters = ChapterService.extractChapters(from: description, videoDuration: nil)
            let isEqual = checkChapterEqual(chapters, expected)
            if !isEqual {
                print("chapters", chapters)
                print("expected", expected)
                print("\n")
            }
            XCTAssertTrue(isEqual)
        }
    }

    // MARK: Helper functions

    func doChapterMergeTest(
        chapters: [SendableChapter],
        sponsorSegments: [SendableChapter],
        duration: Double? = nil,
        expected: [SendableChapter]
    ) {

        let cleanSponsorSegments = ChapterService.cleanExternalChapters(sponsorSegments)
        let result = ChapterService.mergeSponsorSegments(
            chapters,
            sponsorSegments: cleanSponsorSegments,
            duration: duration
        )

        print("result: \(result)")

        checkChapterStartEndTimes(result)
        let isEqual = checkChapterEqual(result, expected)
        if !isEqual {
            print("chapters", result)
            print("expected", expected)
            print("\n")
        }
        XCTAssertTrue(isEqual)
    }

    /// Makes sure title, times, and category are the same
    func checkChapterEqual(_ lhs: [SendableChapter], _ rhs: [SendableChapter]) -> Bool {
        XCTAssertEqual(lhs.count, rhs.count)

        for (index, chapter) in lhs.enumerated() {
            if chapter.title != rhs[index].title {
                print("title mismatch: \(chapter.title) != \(rhs[index].title)")
                return false
            }

            if chapter.startTime != rhs[index].startTime {
                print("start time mismatch: \(chapter.startTime) != \(rhs[index].startTime)")
                return false
            }

            if chapter.endTime != rhs[index].endTime {
                print("end time mismatch: \(chapter.endTime) != \(rhs[index].endTime)")
                return false
            }

            if chapter.category != rhs[index].category {
                print("category mismatch: \(chapter.category) != \(rhs[index].category)")
                return false
            }
        }

        return true
    }

    /// Check that each end of the previous chapter matches the start of the next chapter
    func checkChapterStartEndTimes(_ chapters: [SendableChapter]) {
        for index in 0..<chapters.count - 1 {
            let currentChapter = chapters[index]
            let nextChapter = chapters[index + 1]

            // Ensure both chapters have endTime and startTime
            guard let currentEndTime = currentChapter.endTime else {
                print("Chapters \(currentChapter.description) or \(nextChapter.description) do not have valid end/start times.")
                continue
            }
            let nextStartTime = nextChapter.startTime

            // Check if the end time of the current chapter and the start time of the next chapter are within tolerance
            let timeDifference = abs(nextStartTime - currentEndTime)
            XCTAssertEqual(
                timeDifference,
                0,
                "Time difference between \(currentChapter.description) and \(nextChapter.description)"
                    + " exceeds \(Const.chapterTimeTolerance) seconds: \(timeDifference)"
            )
        }
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
