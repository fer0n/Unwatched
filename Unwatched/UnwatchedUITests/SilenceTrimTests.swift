//
//  SilenceTrimTests.swift
//  Unwatched
//

import AVFoundation
import XCTest
import UnwatchedShared

/// Covers the offline half of "trim silence": finding the pauses in a file, shortening them in a composition, and
/// translating between that composition's clock and the episode's.
final class SilenceTrimTests: XCTestCase {

    private struct Pause {
        let start: Double
        let length: Double
        var end: Double { start + length }
    }

    /// One generated episode: how loud its speech is, and what sits under its pauses.
    private struct Mix {
        let name: String
        let speechLevel: Float
        /// Room tone under the pauses, relative to speech; nil for digital silence.
        let roomToneDb: Float?
    }

    /// A scan keeps what `TrimSilenceTier.mostPermissive` would trim, so the two short ones here separate the tiers
    /// rather than being thrown away: `.max` reaches both, `.medium` neither.
    private static let pauses = [
        Pause(start: 2.0, length: 1.0),
        Pause(start: 5.0, length: 0.6),
        Pause(start: 8.0, length: 3.0),
        Pause(start: 13.0, length: 0.45),
        Pause(start: 16.0, length: 2.0),
        Pause(start: 20.0, length: 0.4)
    ]
    private static let trimmableCount = 6
    private static let episodeLength: Double = 24

    // MARK: - Tests

    func testFindsThePausesWorthTrimming() async throws {
        for mix in Self.mixes {
            let scan = try await scan(mix)
            XCTAssertEqual(scan.pauses.count, Self.trimmableCount, "wrong pause count on \(mix.name)")
            XCTAssertEqual(scan.fileDuration, Self.episodeLength, accuracy: 0.1, mix.name)
        }
    }

    /// The edges of a detected pause are only as precise as the window it was measured in.
    func testNothingOutsideAPauseIsEverScaled() async throws {
        let guardBand = TrimSilenceTier.allCases.map(\.settings.guardBand).min() ?? Const.silenceGuardBand
        for mix in Self.mixes {
            let scan = try await scan(mix)
            for found in scan.pauses {
                let interiorStart = found.start + guardBand
                let interiorEnd = found.end - guardBand
                let real = try XCTUnwrap(
                    Self.pauses.min { abs($0.start - found.start) < abs($1.start - found.start) }
                )
                XCTAssertGreaterThanOrEqual(interiorStart, real.start, "\(mix.name): scaled into speech")
                XCTAssertLessThanOrEqual(interiorEnd, real.end, "\(mix.name): scaled into speech")
            }
        }
    }

    func testCompositionIsShorterAndMatchesItsMap() async throws {
        let built = try await composed(Self.mixes[1])
        let played = try await built.composition.load(.duration).seconds

        XCTAssertEqual(built.map.playerDuration, played, accuracy: 0.01, "the map disagrees with the asset")
        XCTAssertEqual(built.map.fileDuration, built.scan.fileDuration, accuracy: 0.1)
        XCTAssertLessThan(played, built.scan.fileDuration - 3, "the pauses were not shortened")
        // every pause keeps both guard bands, so it can never come out shorter than those
        for pause in built.scan.pauses {
            XCTAssertGreaterThanOrEqual(
                SilenceScan.playedLength(of: pause.duration), 2 * Const.silenceGuardBand
            )
        }
    }

    func testTheMapRoundTripsAndNeverRunsBackwards() async throws {
        let built = try await composed(Self.mixes[0])
        let map = built.map
        let played = try await built.composition.load(.duration).seconds

        var previous = -1.0
        for step in stride(from: 0.0, to: played, by: 0.02) {
            let inEpisode = map.fileTime(step)
            XCTAssertEqual(map.playerTime(inEpisode), step, accuracy: 0.02, "round trip at \(step)")
            XCTAssertGreaterThanOrEqual(inEpisode, previous, "the episode ran backwards at \(step)")
            previous = inEpisode
        }
        // out of range on either side is clamped rather than extrapolated
        XCTAssertEqual(map.fileTime(-5), 0, accuracy: 0.05)
        XCTAssertEqual(map.playerTime(-5), 0, accuracy: 0.05)
        XCTAssertLessThanOrEqual(map.fileTime(played + 100), map.fileDuration + 0.05)
        XCTAssertLessThanOrEqual(map.playerTime(map.fileDuration + 100), map.playerDuration + 0.05)
    }

    /// The reason for the whole offline approach: the speech that surrounds a shortened pause has to come out
    /// untouched.
    func testSpeechComesOutUnattenuated() async throws {
        let built = try await composed(Self.mixes[1])
        let levels = try await render(built.composition)
        XCTAssertFalse(levels.isEmpty)

        // every window is either speech or silence; only the ones straddling an edge sit between
        let partway = levels.filter { $0 > 0.02 && $0 <= 0.5 }.count
        XCTAssertLessThanOrEqual(partway, levels.count / 40, "speech is being faded at the edges")
        XCTAssertGreaterThan(levels.filter { $0 > 0.5 }.count, levels.count / 2)
    }

    /// `.max` is the tier that gives up guard band to reach the short gaps, so it's the one whose speech is worth
    /// checking separately — this is the cost the tier is trading for.
    func testSpeechComesOutUnattenuatedAtTheMostAggressiveTier() async throws {
        let built = try await composed(Self.mixes[1], tier: .max)
        let levels = try await render(built.composition)
        XCTAssertFalse(levels.isEmpty)

        let partway = levels.filter { $0 > 0.02 && $0 <= 0.5 }.count
        XCTAssertLessThanOrEqual(partway, levels.count / 40, "speech is being faded at the edges")
        XCTAssertGreaterThan(levels.filter { $0 > 0.5 }.count, levels.count / 2)
    }

    /// The point of the tiers: each one has to actually shorten the episode more than the last.
    func testEachTierSavesMoreThanTheOneBelowIt() async throws {
        let scan = try await scan(Self.mixes[1])
        let savings = TrimSilenceTier.allCases.map { scan.saving(tier: $0) }
        for (tier, saving) in zip(TrimSilenceTier.allCases, savings) {
            XCTAssertGreaterThan(saving, 0, "\(tier) trims nothing at all")
        }
        XCTAssertEqual(savings, savings.sorted(), "the tiers are not ordered by how much they trim")
        XCTAssertGreaterThan(
            savings[2], savings[1] * 1.2, "max is not meaningfully more aggressive than medium"
        )
    }

    // MARK: - Helpers

    /// The combinations a threshold has to survive.
    private static let mixes = [
        Mix(name: "digital silence", speechLevel: 0.30, roomToneDb: nil),
        Mix(name: "room tone at -45 dB", speechLevel: 0.30, roomToneDb: -45),
        Mix(name: "room tone at -38 dB", speechLevel: 0.30, roomToneDb: -38),
        Mix(name: "a quietly mixed episode", speechLevel: 0.03, roomToneDb: -45)
    ]

    private func scan(_ mix: Mix) async throws -> SilenceScan {
        let url = try Self.makeEpisode(mix)
        defer { try? FileManager.default.removeItem(at: url) }
        return try await SilenceScanner.scan(url: url)
    }

    private struct Composed {
        let scan: SilenceScan
        let composition: AVMutableComposition
        let map: SilenceMap
    }

    private func composed(_ mix: Mix, tier: TrimSilenceTier = .medium) async throws -> Composed {
        let url = try Self.makeEpisode(mix)
        let scan = try await SilenceScanner.scan(url: url)
        let made = await SilenceComposition.make(url: url, scan: scan, tier: tier)
        let built = try XCTUnwrap(made, "nothing was built")
        return Composed(scan: scan, composition: built.0, map: built.1)
    }

    /// Speech is a wobbling low tone with noise on it rather than a pure sine, so the level of a window isn't the
    /// same for every window of it.
    private static func makeEpisode(_ mix: Mix) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "silence-\(UUID().uuidString).wav")
        let sampleRate = 44_100.0
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        let speechLevel = mix.speechLevel
        let roomTone = mix.roomToneDb.map { speechLevel * powf(10, $0 / 20) } ?? 0

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let chunk = 0.05
        var time = 0.0
        var phase: Float = 0
        var seed: UInt64 = 12345
        while time < episodeLength {
            let frames = AVAudioFrameCount(sampleRate * chunk)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
            buffer.frameLength = frames
            let data = try XCTUnwrap(buffer.floatChannelData?[0])
            let quiet = pauses.contains { time >= $0.start && time < $0.end }
            for index in 0..<Int(frames) {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                let noise = Float(Int64(bitPattern: seed >> 11)) / Float(1 << 52) - 1
                if quiet {
                    data[index] = roomTone * noise
                } else {
                    phase += Float(2.0 * .pi * (180 + 60 * sin(time * 3)) / sampleRate)
                    data[index] = speechLevel * (sinf(phase) * 0.8 + noise * 0.2)
                }
            }
            try file.write(from: buffer)
            time += chunk
        }
        return url
    }

    /// Each 25 ms of the composition as a fraction of its loudest window.
    private func render(_ composition: AVMutableComposition) async throws -> [Double] {
        let tracks = try await composition.loadTracks(withMediaType: .audio)
        let track = try XCTUnwrap(tracks.first)
        let reader = try AVAssetReader(asset: composition)
        let output = AVAssetReaderAudioMixOutput(audioTracks: [track], audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1
        ])
        output.audioTimePitchAlgorithm = .spectral
        reader.add(output)
        reader.startReading()

        var levels: [Double] = []
        var sum = 0.0
        var count = 0
        while let sample = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(sample) else { continue }
            var length = 0
            var pointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(
                block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &pointer
            )
            guard let pointer else { continue }
            pointer.withMemoryRebound(to: Float.self, capacity: length / MemoryLayout<Float>.size) { samples in
                for index in 0..<(length / MemoryLayout<Float>.size) {
                    sum += Double(samples[index]) * Double(samples[index])
                    count += 1
                    if count == 1102 {
                        levels.append((sum / Double(count)).squareRoot())
                        sum = 0
                        count = 0
                    }
                }
            }
        }
        let peak = levels.max() ?? 1
        return levels.map { $0 / peak }
    }
}
