//
//  BatteryWriteTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData
import UnwatchedShared

/// Each save is its own CloudKit export.
class CleanupSaveCountTests: XCTestCase {
    override func tearDown() async throws {
        try wipeStore()
    }

    @discardableResult
    private func seedOrphans(_ count: Int) -> PersistentIdentifier {
        let context = DataProvider.newContext()
        let sub = Subscription.getDummy()
        sub.isArchived = true
        context.insert(sub)
        let old = Calendar.current.date(byAdding: .day, value: -400, to: .now)!
        for index in 0..<count {
            let video = Video(
                title: "orphan-\(index)",
                url: URL(string: "https://youtu.be/o\(index)"),
                youtubeId: "o\(index)",
                createdDate: old
            )
            video.subscription = sub
            context.insert(video)
            let chapter = Chapter(title: "c-\(index)", time: 0, endTime: 10)
            context.insert(chapter)
            video.chapters = [chapter]
        }
        try? context.save()
        return sub.persistentModelID
    }

    private func countSaves(_ work: () async -> Void) async -> (saves: Int, ms: Double) {
        let saves = SaveCounter()
        let observer = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: nil, queue: nil
        ) { _ in saves.increment() }
        let start = Date()
        await work()
        let ms = Date().timeIntervalSince(start) * 1000
        NotificationCenter.default.removeObserver(observer)
        return (saves.value, ms)
    }

    private func remainingCounts() throws -> (videos: Int, chapters: Int) {
        let context = DataProvider.newContext()
        return (
            try context.fetchCount(FetchDescriptor<Video>()),
            try context.fetchCount(FetchDescriptor<Chapter>())
        )
    }

    /// The pre-batching behaviour, kept as the baseline the batched run is measured against.
    func testPerVideoDeleteBaseline() async throws {
        seedOrphans(60)
        let result = await countSaves {
            await CleanupActor().deleteEachOrphanForBaseline()
        }
        print("CleanupSaveCount per-video: \(result.saves) saves, \(Int(result.ms)) ms")
        let remaining = try remainingCounts()
        XCTAssertEqual(remaining.videos, 0)
        XCTAssertEqual(remaining.chapters, 0)
        XCTAssertEqual(result.saves, 60)
    }

    func testOrphanCleanupSavesOnce() async throws {
        seedOrphans(60)
        let result = await countSaves {
            await CleanupActor().deleteOrphanedVideos(olderThan: 1)
        }
        print("CleanupSaveCount batched: \(result.saves) saves, \(Int(result.ms)) ms")
        let remaining = try remainingCounts()
        XCTAssertEqual(remaining.videos, 0)
        XCTAssertEqual(remaining.chapters, 0)
        XCTAssertEqual(result.saves, 1)
    }

    func testDeletingSubscriptionSavesOnce() async throws {
        let subId = seedOrphans(60)
        let result = await countSaves {
            try? await SubscriptionActor().deleteSubscriptions([subId])
        }
        let remaining = try remainingCounts()
        XCTAssertEqual(remaining.videos, 0)
        XCTAssertEqual(remaining.chapters, 0)
        XCTAssertEqual(result.saves, 1)
    }
}

class BackupRecompressionCheckTests: XCTestCase {
    func testOnlyUncompressedBackupsNeedRecompression() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let body = Data("{\"videos\":[]}".utf8)
        let compressed = dir.appendingPathComponent("compressed")
        try (Data([0x55, 0x57, 0x5a, 0x31]) + body).write(to: compressed)
        let legacy = dir.appendingPathComponent("legacy")
        try body.write(to: legacy)
        let placeholder = dir.appendingPathComponent(".legacy.icloud")
        try body.write(to: placeholder)
        let empty = dir.appendingPathComponent("empty")
        try Data().write(to: empty)

        XCTAssertFalse(UserDataService.needsRecompression(compressed))
        XCTAssertTrue(UserDataService.needsRecompression(legacy))
        XCTAssertFalse(UserDataService.needsRecompression(placeholder))
        XCTAssertFalse(UserDataService.needsRecompression(empty))
        XCTAssertFalse(UserDataService.needsRecompression(dir.appendingPathComponent("missing")))
    }
}

@MainActor
class StatsPauseFlushTests: XCTestCase {
    private let videoId = "stats-pause-video"

    override func setUp() async throws {
        let context = DataProvider.newContext()
        context.insert(Video(
            title: "stats",
            url: URL(string: "https://youtu.be/\(videoId)"),
            youtubeId: videoId,
            youtubeChannelId: "stats-pause-channel"
        ))
        try context.save()
        await StatsService.shared.flush()?.value
    }

    override func tearDown() async throws {
        let context = DataProvider.newContext()
        try context.delete(model: WatchTimeEntry.self)
        try wipeStore()
    }

    func testShortPausesWaitForTheNextFlush() async throws {
        let stats = StatsService.shared
        var time = 0.0
        for _ in 0..<5 {
            stats.handleVideoTimeUpdate(videoId: videoId, time: time)
            try await Task.sleep(for: .milliseconds(600))
            time += 0.6
            stats.handleVideoTimeUpdate(videoId: videoId, time: time, isPause: true)
            try await Task.sleep(for: .milliseconds(300))
        }
        XCTAssertEqual(try watchTimeEntries().count, 0)

        await stats.flush()?.value
        let entries = try watchTimeEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertGreaterThan(entries.first?.watchTime ?? 0, 0)
    }

    private func watchTimeEntries() throws -> [WatchTimeEntry] {
        try DataProvider.newContext().fetch(FetchDescriptor<WatchTimeEntry>())
    }
}

@MainActor
class DurationToleranceTests: XCTestCase {
    override func tearDown() async throws {
        try wipeStore()
    }

    func testSubSecondDurationDifferencesDontWrite() async throws {
        let context = DataProvider.mainContext
        let video = Video(title: "duration", url: URL(string: "https://youtu.be/dur"), youtubeId: "dur")
        video.duration = 612
        context.insert(video)
        try context.save()

        let saves = SaveCounter()
        let observer = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: context, queue: nil
        ) { _ in saves.increment() }
        defer { NotificationCenter.default.removeObserver(observer) }

        VideoService.updateDuration(video, duration: 612.04)
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(saves.value, 0)
        XCTAssertEqual(video.duration, 612)

        VideoService.updateDuration(video, duration: 640)
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(saves.value, 1)
        XCTAssertEqual(video.duration, 640)
    }
}

class SponsorBlockRecheckTests: XCTestCase {
    override func tearDown() async throws {
        try wipeStore()
    }

    private func recentVideo(checkedMinutesAgo minutes: Double) throws -> PersistentIdentifier {
        let context = DataProvider.newContext()
        let video = Video(
            title: "recent",
            url: URL(string: "https://youtu.be/sb\(Int(minutes))"),
            youtubeId: "sb\(Int(minutes))",
            publishedDate: .now.addingTimeInterval(-60 * 60)
        )
        video.sponserBlockUpdateDate = .now.addingTimeInterval(-minutes * 60)
        context.insert(video)
        try context.save()
        return video.persistentModelID
    }

    func testRecentVideoIsNotRecheckedWithinMinutes() throws {
        XCTAssertFalse(ChapterService.shouldRefreshSponserBlock(try recentVideo(checkedMinutesAgo: 2), false, true))
        XCTAssertTrue(ChapterService.shouldRefreshSponserBlock(try recentVideo(checkedMinutesAgo: 10), false, true))
    }
}

private final class SaveCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int { lock.withLock { count } }

    func increment() {
        lock.withLock { count += 1 }
    }
}

private extension CleanupActor {
    func deleteEachOrphanForBaseline() {
        let videos = (try? modelContext.fetch(FetchDescriptor<Video>())) ?? []
        for video in videos {
            CleanupService.deleteVideo(video, modelContext)
        }
    }
}
