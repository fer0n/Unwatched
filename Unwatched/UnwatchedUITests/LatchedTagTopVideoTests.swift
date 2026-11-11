//
//  LatchedTagTopVideoTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData
import UnwatchedShared

/// A video played from search goes to the top of the whole queue but not into the latched tag. A sync
/// finishing while it's paused (`handlePotentialUpdate`) must not swap it for the tag's top.
@MainActor
final class LatchedTagTopVideoTests: PlayerManagerTestCase {
    private var techTag: Tag!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let tech = Subscription(link: nil, title: "Tech", youtubeChannelId: "tech")
        context.insert(tech)
        techTag = Tag(name: "Tech", order: 0)
        context.insert(techTag)
        techTag.subscriptions = [tech]

        let techVideo = makeVideo(youtubeId: "tech-1")
        techVideo.subscription = tech
        queue(techVideo, order: 100)
        try context.save()
        player.playbackTag = .tag(techTag.persistentModelID)
    }

    private func queue(_ video: Video, order: Int) {
        let entry = QueueEntry(video: video, order: order)
        context.insert(entry)
        video.queueEntry = entry
    }

    /// Spins the run loop so a fade-deferred swap gets the chance to land.
    private func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(1.5))
    }

    func testVideoPlayedFromOutsideTheTagSurvivesAQueueReload() throws {
        let searched = makeVideo(youtubeId: "searched")
        queue(searched, order: 0)
        try context.save()
        player.setVideoWithoutFade(searched, .userInteraction)

        player.loadTopmostVideoFromQueue(modelContext: context)
        settle()

        XCTAssertEqual(player.video?.youtubeId, "searched")
    }

    /// Control: once the video has left the queue, the tag's top still takes over.
    func testVideoNoLongerInTheQueueIsReplacedByTheTagTop() throws {
        let searched = makeVideo(youtubeId: "searched")
        try context.save()
        player.setVideoWithoutFade(searched, .userInteraction)

        player.loadTopmostVideoFromQueue(modelContext: context)
        settle()

        XCTAssertEqual(player.video?.youtubeId, "tech-1")
    }
}
