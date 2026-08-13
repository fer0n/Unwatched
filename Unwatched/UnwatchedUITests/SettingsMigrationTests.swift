//
//  SettingsMigrationTests.swift
//  UnwatchedUITests
//

import XCTest
import UnwatchedShared

private final class MemoryStore: SettingsStore {
    private var values: [String: Any] = [:]

    init(_ values: [String: Any] = [:]) {
        self.values = values
    }

    func object(forKey key: String) -> Any? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
    func removeObject(forKey key: String) { values[key] = nil }
}

/// `SettingsMigration` runs on every launch, so the thing worth proving is that it stays a no-op
/// once it has done its work — an unguarded step would reset a setting the user has since changed.
///
/// Uses in-memory stores rather than the real ones: `NSUbiquitousKeyValueStore` drops writes
/// without the iCloud entitlement, and the tests would otherwise mutate the developer's own
/// settings.
final class SettingsMigrationTests: XCTestCase {

    /// A fresh install has nothing to convert and has to keep the registered default.
    func testFreshInstallIsUntouched() {
        let defaults = MemoryStore()
        let cloud = MemoryStore()

        SettingsMigration.run(defaults: defaults, cloud: cloud)

        XCTAssertNil(defaults.object(forKey: Const.defaultShortsSetting))
        XCTAssertNil(cloud.object(forKey: Const.defaultShortsSetting))
    }

    func testHideShortsBecomesShortsSetting() {
        let defaults = MemoryStore([Const.hideShorts: true])
        let cloud = MemoryStore()

        SettingsMigration.run(defaults: defaults, cloud: cloud)

        XCTAssertEqual(cloud.object(forKey: Const.defaultShortsSetting) as? Int, ShortsSetting.hide.rawValue)
        XCTAssertNil(defaults.object(forKey: Const.hideShorts), "legacy key should be cleared")
    }

    func testHideShortsFalseBecomesShow() {
        let defaults = MemoryStore([Const.hideShorts: false])
        let cloud = MemoryStore()

        SettingsMigration.run(defaults: defaults, cloud: cloud)

        XCTAssertEqual(cloud.object(forKey: Const.defaultShortsSetting) as? Int, ShortsSetting.show.rawValue)
    }

    /// An install that already has the setting keeps it — the legacy value must not win.
    func testExistingShortsSettingIsNotOverwritten() {
        let defaults = MemoryStore([Const.hideShorts: true])
        let cloud = MemoryStore([Const.defaultShortsSetting: ShortsSetting.show.rawValue])

        SettingsMigration.run(defaults: defaults, cloud: cloud)

        XCTAssertEqual(cloud.object(forKey: Const.defaultShortsSetting) as? Int, ShortsSetting.show.rawValue)
    }

    func testSyncedSettingsMoveToKeyValueStore() {
        let defaults = MemoryStore([
            Const.skipChapterText: "skip me",
            Const.youtubePremium: true
        ])
        let cloud = MemoryStore()

        SettingsMigration.run(defaults: defaults, cloud: cloud)

        XCTAssertEqual(cloud.object(forKey: Const.skipChapterText) as? String, "skip me")
        XCTAssertEqual(cloud.object(forKey: Const.youtubePremium) as? Bool, true)
        XCTAssertNil(defaults.object(forKey: Const.skipChapterText))
        XCTAssertNil(defaults.object(forKey: Const.youtubePremium))
    }

    /// The step that most needs a guard: without one, a stale `UserDefaults` value would
    /// overwrite the synced setting on every launch.
    func testSyncedSettingsAreNotOverwrittenOnLaterRuns() {
        let defaults = MemoryStore([Const.skipChapterText: "original"])
        let cloud = MemoryStore()
        SettingsMigration.run(defaults: defaults, cloud: cloud)

        cloud.set("changed by user", forKey: Const.skipChapterText)
        defaults.set("stale", forKey: Const.skipChapterText)
        SettingsMigration.run(defaults: defaults, cloud: cloud)

        XCTAssertEqual(cloud.object(forKey: Const.skipChapterText) as? String, "changed by user")
    }

    /// Repeated launches must not undo the first run's work.
    func testRepeatedRunsAreStable() {
        let defaults = MemoryStore([Const.hideShorts: true, Const.skipChapterText: "keep"])
        let cloud = MemoryStore()

        for _ in 0..<3 {
            SettingsMigration.run(defaults: defaults, cloud: cloud)
        }

        XCTAssertEqual(cloud.object(forKey: Const.defaultShortsSetting) as? Int, ShortsSetting.hide.rawValue)
        XCTAssertEqual(cloud.object(forKey: Const.skipChapterText) as? String, "keep")
        XCTAssertNil(defaults.object(forKey: Const.defaultShortsSetting))
    }
}

final class QueueOrderTests: XCTestCase {
    private let step = QueueOrder.step

    func testInsertIntoEmptyQueue() {
        XCTAssertEqual(QueueOrder.insert(count: 1, at: 0, into: []), [0])
        XCTAssertEqual(QueueOrder.insert(count: 3, at: 0, into: []), [0, step, 2 * step])
    }

    func testInsertAtTopGoesBelowTheHead() {
        XCTAssertEqual(QueueOrder.insert(count: 1, at: 0, into: [0, step]), [-step])
        XCTAssertEqual(QueueOrder.insert(count: 1, at: -1, into: [0, step]), [-step])
        XCTAssertEqual(QueueOrder.insert(count: 2, at: 0, into: [0]), [-2 * step, -step])
    }

    func testInsertAtBottom() {
        XCTAssertEqual(QueueOrder.insert(count: 1, at: 2, into: [0, step]), [2 * step])
        XCTAssertEqual(QueueOrder.insert(count: 2, at: 99, into: [0, step]), [2 * step, 3 * step])
    }

    func testInsertInTheMiddleSplitsTheGap() {
        XCTAssertEqual(QueueOrder.insert(count: 1, at: 1, into: [0, step]), [step / 2])
        XCTAssertEqual(
            QueueOrder.insert(count: 3, at: 1, into: [0, step]),
            [step / 4, step / 2, 3 * step / 4]
        )
        XCTAssertEqual(QueueOrder.insert(count: 1, at: 1, into: [0, 2]), [1], "smallest usable gap")
    }

    func testExhaustedGapAsksForARenumber() {
        XCTAssertNil(QueueOrder.insert(count: 1, at: 1, into: [0, 1]))
        XCTAssertNil(QueueOrder.insert(count: 3, at: 1, into: [0, 3]))
    }

    /// `QueueEntry.order` defaults to `Int.max` and a sync merge can leave anything behind, so
    /// stepping past an existing order must not trap.
    func testExtremeOrdersAskForARenumber() {
        XCTAssertNil(QueueOrder.insert(count: 1, at: 1, into: [Int.max]))
        XCTAssertNil(QueueOrder.insert(count: 1, at: 0, into: [Int.min]))
        XCTAssertEqual(QueueOrder.insert(count: 1, at: 1, into: [0, Int.max]), [Int.max / 2])
        XCTAssertNil(QueueOrder.insert(count: 1, at: 1, into: [Int.min, Int.max]), "gap overflows")
    }

    func testInsertKeepsOrdersStrictlyIncreasing() {
        for existingCount in 1...6 {
            for position in -1...(existingCount + 1) {
                for count in 1...3 {
                    let existing = QueueOrder.renumbered(count: existingCount)
                    guard let orders = QueueOrder.insert(count: count, at: position, into: existing) else {
                        XCTFail("unexpected renumber for \(existingCount)/\(position)/\(count)")
                        continue
                    }
                    XCTAssertTrue(
                        QueueOrder.isValid((existing + orders).sorted()),
                        "insert \(count) at \(position) into \(existing) gave \(orders)"
                    )
                }
            }
        }
    }

    func testInsertPutsEntriesAtTheRequestedPosition() {
        for existingCount in 1...6 {
            for position in -1...(existingCount + 1) {
                for count in 1...3 {
                    let existing = QueueOrder.renumbered(count: existingCount)
                    guard let orders = QueueOrder.insert(count: count, at: position, into: existing) else {
                        XCTFail("unexpected renumber for \(existingCount)/\(position)/\(count)")
                        continue
                    }
                    var expected = (0..<existingCount).map { "old\($0)" }
                    expected.insert(
                        contentsOf: (0..<count).map { "new\($0)" },
                        at: max(0, min(position, existingCount))
                    )
                    let actual = (existing.enumerated().map { (order: $0.element, label: "old\($0.offset)") }
                                    + orders.enumerated().map { (order: $0.element, label: "new\($0.offset)") })
                        .sorted { $0.order < $1.order }
                        .map(\.label)
                    XCTAssertEqual(actual, expected, "insert \(count) at \(position)")
                }
            }
        }
    }

    /// Random inserts, deletions and reorders must never scramble the queue, and must keep the
    /// number of rewritten rows near one per placed entry — the point of sparse ordering.
    func testRandomOperationsPreserveTheQueue() {
        var entries = [(id: Int, order: Int)]()
        var expected = [Int]()
        var nextId = 0
        var writes = 0
        var renumbers = 0

        func place(_ ids: [Int], at requested: Int) {
            entries.removeAll { ids.contains($0.id) }
            let position = requested < 0 ? entries.count : min(requested, entries.count)
            if let orders = QueueOrder.insert(count: ids.count, at: position, into: entries.map(\.order)) {
                writes += orders.count
                entries.append(contentsOf: zip(ids, orders).map { (id: $0, order: $1) })
                entries.sort { $0.order < $1.order }
            } else {
                renumbers += 1
                var ids2 = entries.map(\.id)
                ids2.insert(contentsOf: ids, at: position)
                entries = zip(ids2, QueueOrder.renumbered(count: ids2.count)).map { (id: $0, order: $1) }
                writes += entries.count
            }
            expected.removeAll { ids.contains($0) }
            expected.insert(contentsOf: ids, at: position)
        }

        for iteration in 0..<3000 {
            switch Int.random(in: 0..<10) {
            case 0...1:  // play now
                place([nextId], at: 0)
                nextId += 1
            case 2...3:  // queue next
                place([nextId], at: 1)
                nextId += 1
            case 4...5:  // queue last
                place([nextId], at: -1)
                nextId += 1
            case 6:  // bulk insert
                let ids = (0..<Int.random(in: 1...3)).map { _ -> Int in
                    defer { nextId += 1 }
                    return nextId
                }
                place(ids, at: expected.isEmpty ? 0 : Int.random(in: 0..<expected.count))
            case 7...8:  // mark watched / clear — deleting never renumbers
                guard !expected.isEmpty else { continue }
                let index = Int.random(in: 0..<expected.count)
                entries.removeAll { $0.id == expected[index] }
                expected.remove(at: index)
            default:  // drag to reorder
                guard expected.count > 1 else { continue }
                let source = Int.random(in: 0..<expected.count)
                let destination = Int.random(in: 0..<expected.count)
                let moved = expected[source]
                var remaining = expected
                remaining.remove(at: source)
                let target = destination > source ? destination - 1 : destination
                place([moved], at: min(target, remaining.count))
            }

            XCTAssertTrue(
                QueueOrder.isValid(entries.map(\.order)),
                "not strictly increasing at iteration \(iteration)"
            )
            XCTAssertEqual(entries.map(\.id), expected, "queue scrambled at iteration \(iteration)")
        }

        XCTAssertLessThan(renumbers, 20, "renumbering should stay rare: \(renumbers) in 3000 ops")
        XCTAssertLessThan(writes, 3000 * 5, "writes per operation should stay small: \(writes)")
    }
}
