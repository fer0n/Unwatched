//
//  MigrationTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData
import UnwatchedShared

/// Cover for the SwiftData migration chain.
///
/// The failure this guards against isn't a crash in one stage, it's the chain failing to resolve
/// at all: a historical `VersionedSchema` whose shape no longer matches what shipped can't be
/// matched to the store's stamped version, so every user still on that version hits a hard
/// failure at launch. `UnwatchedSchemaV1p13` did exactly that — it had no model definitions of
/// its own, so it silently tracked whatever the live models happened to be.
///
/// Each test opens real stores on disk in a temp directory; nothing here touches the app's store.
final class MigrationTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL.temporaryDirectory.appending(path: "migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        directory = nil
    }

    // MARK: - Helpers

    private func storeURL(_ name: String = "store") -> URL {
        directory.appending(path: "\(name).sqlite")
    }

    private func container(
        _ version: any VersionedSchema.Type,
        at url: URL
    ) throws -> ModelContainer {
        let schema = Schema(versionedSchema: version)
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)]
        )
    }

    /// Opens `url` the way the app does: current schema, full migration plan, no CloudKit.
    private func migrate(_ url: URL) throws -> ModelContainer {
        try ModelContainer(
            for: DataProvider.schema,
            migrationPlan: UnwatchedMigrationPlan.self,
            configurations: [
                ModelConfiguration(schema: DataProvider.schema, url: url, cloudKitDatabase: .none)
            ]
        )
    }

    /// `name: [propertyName]` for every entity, order-independent so property reordering
    /// (which doesn't change the store) doesn't fail the test.
    private func shape(of version: any VersionedSchema.Type) -> [String: [String]] {
        Dictionary(
            uniqueKeysWithValues: Schema(versionedSchema: version).entities.map {
                ($0.name, $0.properties.map(\.name).sorted())
            }
        )
    }

    // MARK: - Schema shape

    private func assertShapesUnchanged(
        _ schemas: [any VersionedSchema.Type],
        against recorded: [String: [String: [String]]],
        line: UInt = #line
    ) {
        for version in schemas {
            let identifier = "\(Schema(versionedSchema: version).version)"
            guard let expected = recorded[identifier] else {
                XCTFail("No recorded shape for schema \(identifier)", line: line)
                continue
            }
            XCTAssertEqual(shape(of: version), expected, "schema \(identifier) changed shape", line: line)
        }
    }

    /// A historical version's shape is a fact about stores already on disk, so it must never
    /// change once shipped. Anything that edits a legacy schema — including editing a live model
    /// that a legacy schema still points at — fails here.
    func testHistoricSchemaShapesAreUnchanged() {
        assertShapesUnchanged(UnwatchedMigrationPlan.schemas, against: Self.expectedShapes)
    }

    func testHistoricCacheSchemaShapesAreUnchanged() {
        assertShapesUnchanged(CachedImageMigrationPlan.schemas, against: Self.expectedCacheShapes)
    }

    /// The current models and the newest versioned schema are the same thing by definition; if
    /// they drift, new stores are stamped with a version whose shape doesn't describe them.
    func testNewestSchemaMatchesLiveModels() throws {
        let newest = try XCTUnwrap(UnwatchedMigrationPlan.schemas.last)
        let live = Dictionary(
            uniqueKeysWithValues: DataProvider.schema.entities.map {
                ($0.name, $0.properties.map(\.name).sorted())
            }
        )
        XCTAssertEqual(shape(of: newest), live, "newest versioned schema is out of sync with the live models")
    }

    func testVersionsAreOrderedAndUnique() {
        let versions = UnwatchedMigrationPlan.schemas.map { Schema(versionedSchema: $0).version }
        XCTAssertEqual(versions, versions.sorted(), "schemas must be listed oldest first")
        XCTAssertEqual(Set(versions).count, versions.count, "duplicate schema version identifier")
    }

    // MARK: - Chain

    /// The real regression test: a store stamped at any shipped version still opens. Runs the
    /// whole chain from every starting point, which is what an old install actually does.
    func testMigratesFromEveryHistoricVersion() throws {
        for version in UnwatchedMigrationPlan.schemas {
            let identifier = "\(Schema(versionedSchema: version).version)"
            let url = storeURL(identifier)
            try autoreleasepool {
                _ = try container(version, at: url)
            }
            try autoreleasepool {
                let migrated = try migrate(url)
                let context = ModelContext(migrated)
                XCTAssertNoThrow(
                    try context.fetch(FetchDescriptor<Video>()),
                    "store from \(identifier) migrated but is not queryable"
                )
            }
        }
    }

    /// Migrating an already-current store must be a no-op rather than an error.
    func testMigratingCurrentStoreIsIdempotent() throws {
        let url = storeURL()
        try autoreleasepool {
            let context = ModelContext(try migrate(url))
            context.insert(Video(title: "kept", url: nil, youtubeId: "kept-id"))
            try context.save()
        }
        for _ in 0..<2 {
            try autoreleasepool {
                let context = ModelContext(try migrate(url))
                XCTAssertEqual(try context.fetch(FetchDescriptor<Video>()).count, 1)
            }
        }
    }

    // MARK: - Data-carrying stages

    /// V1 -> current with a populated store: the rows themselves have to come through, not just
    /// the schema. V1's `CachedImage` is dropped on purpose by the first stage.
    func testDataSurvivesMigrationFromV1() throws {
        let url = storeURL()
        try autoreleasepool {
            let context = ModelContext(try container(UnwatchedSchemaV1.self, at: url))
            let subscription = UnwatchedSchemaV1.Subscription(
                link: URL(string: "https://youtube.com/feed"),
                title: "Channel",
                youtubeChannelId: "channel-1"
            )
            context.insert(subscription)

            let video = UnwatchedSchemaV1.Video(
                title: "Video",
                url: URL(string: "https://youtu.be/abc"),
                youtubeId: "abc",
                duration: 120
            )
            video.subscription = subscription
            context.insert(video)

            context.insert(UnwatchedSchemaV1.QueueEntry(video: video, order: 0))
            context.insert(UnwatchedSchemaV1.Chapter(title: "Intro", time: 0))
            context.insert(UnwatchedSchemaV1.CachedImage(
                URL(string: "https://img.example/1")!,
                imageData: Data([0x01])
            ))
            try context.save()
        }

        try autoreleasepool {
            let context = ModelContext(try migrate(url))
            let videos = try context.fetch(FetchDescriptor<Video>())
            XCTAssertEqual(videos.count, 1)
            XCTAssertEqual(videos.first?.title, "Video")
            XCTAssertEqual(videos.first?.youtubeId, "abc")
            XCTAssertEqual(videos.first?.duration, 120)
            XCTAssertEqual(videos.first?.subscription?.title, "Channel")

            XCTAssertEqual(try context.fetch(FetchDescriptor<Subscription>()).count, 1)
            XCTAssertEqual(try context.fetch(FetchDescriptor<QueueEntry>()).count, 1)
            XCTAssertEqual(try context.fetch(FetchDescriptor<Chapter>()).count, 1)
        }
    }

    /// V1p1 -> V1p2 replaces the `WatchEntry` table with a single `watchedDate`, taken from the
    /// most recent entry. Losing this silently marks watched videos unwatched.
    func testWatchedDateIsCarriedOverFromWatchEntries() throws {
        let url = storeURL()
        let newest = Date(timeIntervalSince1970: 1_700_000_000)
        let older = newest.addingTimeInterval(-86_400)

        try autoreleasepool {
            let context = ModelContext(try container(UnwatchedSchemaV1p1.self, at: url))
            let watched = UnwatchedSchemaV1p1.Video(title: "Watched", url: nil, youtubeId: "watched")
            watched.watched = true
            context.insert(watched)
            context.insert(UnwatchedSchemaV1p1.WatchEntry(video: watched, date: older))
            context.insert(UnwatchedSchemaV1p1.WatchEntry(video: watched, date: newest))

            let unwatched = UnwatchedSchemaV1p1.Video(title: "Unwatched", url: nil, youtubeId: "unwatched")
            context.insert(unwatched)
            try context.save()
        }

        try autoreleasepool {
            let context = ModelContext(try migrate(url))
            let videos = try context.fetch(FetchDescriptor<Video>())
            XCTAssertEqual(videos.count, 2)
            XCTAssertEqual(videos.first { $0.youtubeId == "watched" }?.watchedDate, newest)
            XCTAssertNil(videos.first { $0.youtubeId == "unwatched" }?.watchedDate)
        }
    }

    /// V1p6 -> V1p7 moves `placeVideosIn` onto the `_videoPlacement` raw column. The stage keys
    /// the carried-over values by channel id, so a subscription without one is the edge case.
    func testVideoPlacementIsCarriedOver() throws {
        let url = storeURL()
        try autoreleasepool {
            let context = ModelContext(try container(UnwatchedSchemaV1p6.self, at: url))
            context.insert(UnwatchedSchemaV1p6.Subscription(
                link: nil,
                title: "Queued",
                placeVideosIn: .queueNext,
                youtubeChannelId: "queued-channel"
            ))
            context.insert(UnwatchedSchemaV1p6.Subscription(
                link: nil,
                title: "Inbox",
                placeVideosIn: .inbox,
                youtubeChannelId: "inbox-channel"
            ))
            try context.save()
        }

        try autoreleasepool {
            let context = ModelContext(try migrate(url))
            let subscriptions = try context.fetch(FetchDescriptor<Subscription>())
            XCTAssertEqual(subscriptions.count, 2)
            XCTAssertEqual(
                subscriptions.first { $0.youtubeChannelId == "queued-channel" }?.videoPlacement,
                .queueNext
            )
            XCTAssertEqual(
                subscriptions.first { $0.youtubeChannelId == "inbox-channel" }?.videoPlacement,
                .inbox
            )
        }
    }

    // MARK: - Image cache store

    func testCachedImageMigratesFromEveryHistoricVersion() throws {
        for version in CachedImageMigrationPlan.schemas {
            let identifier = "\(Schema(versionedSchema: version).version)"
            let url = storeURL("cache-\(identifier)")
            try autoreleasepool {
                _ = try container(version, at: url)
            }
            try autoreleasepool {
                let schema = Schema([CachedImage.self, Transcript.self])
                let migrated = try ModelContainer(
                    for: schema,
                    migrationPlan: CachedImageMigrationPlan.self,
                    configurations: [
                        ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
                    ]
                )
                let context = ModelContext(migrated)
                XCTAssertNoThrow(
                    try context.fetch(FetchDescriptor<CachedImage>()),
                    "image cache from \(identifier) migrated but is not queryable"
                )
            }
        }
    }
}
