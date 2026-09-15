//
//  PlayerManagerTestCase.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData
import UnwatchedShared

/// Records what it was told instead of playing anything.
final class SpyBackend: PlayerBackend {
    enum Command: Equatable {
        case play
        case pause
        case stop
        case seek(Double)
        case setRate(Double)
        case setPip(Bool)
        case cueVideo
        case setChapterMarkers(force: Bool)
        case setAudioLanguage(String)
        case setVideoQuality(Int)
        case applyTrimSilence
    }

    var commands: [Command] = []

    func play() { commands.append(.play) }
    func pause() { commands.append(.pause) }
    func stop() { commands.append(.stop) }
    func seek(to time: Double) { commands.append(.seek(time)) }
    func setRate(_ rate: Double) { commands.append(.setRate(rate)) }
    func setPip(_ enabled: Bool) { commands.append(.setPip(enabled)) }
    func cueVideo() { commands.append(.cueVideo) }
    func setChapterMarkers(force: Bool) { commands.append(.setChapterMarkers(force: force)) }
    func setAudioLanguage(_ code: String) { commands.append(.setAudioLanguage(code)) }
    func setVideoQuality(_ height: Int) { commands.append(.setVideoQuality(height)) }
    func applyTrimSilence() { commands.append(.applyTrimSilence) }

    /// Commands other than the rate, which several tests trigger incidentally by touching a speed-derived
    /// property.
    var withoutRateChanges: [Command] {
        commands.filter {
            if case .setRate = $0 { return false }
            return true
        }
    }
}

/// A `PlayerManager` on an in-memory store, driving a `SpyBackend`.
@MainActor
class PlayerManagerTestCase: XCTestCase {
    private var container: ModelContainer!
    var context: ModelContext!
    var player: PlayerManager!
    var spy: SpyBackend!

    override func setUpWithError() throws {
        let schema = DataProvider.schema
        container = try ModelContainer(
            for: schema,
            configurations: [
                ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            ]
        )
        context = ModelContext(container)

        spy = SpyBackend()
        player = PlayerManager()
        player.backendOverride = spy
        // nothing is loading, so commands aren't dropped for readiness
        player.isLoading = nil
    }

    override func tearDownWithError() throws {
        player.backendOverride = nil
        player = nil
        spy = nil
        context = nil
        container = nil
    }

    func makeVideo(youtubeId: String = "abc123", duration: Double? = 600) -> Video {
        let video = Video(
            title: "Test",
            url: URL(string: "https://youtube.com/watch?v=\(youtubeId)"),
            youtubeId: youtubeId,
            duration: duration
        )
        context.insert(video)
        return video
    }
}
