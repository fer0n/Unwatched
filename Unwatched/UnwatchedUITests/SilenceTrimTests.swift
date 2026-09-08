//
//  SilenceTrimTests.swift
//  Unwatched
//

import AVFoundation
import XCTest
import UnwatchedShared

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

    /// The two short ones separate the tiers: `.max` reaches both, `.medium` neither.
    private static let pauses = [
        Pause(start: 2.0, length: 1.0),
        Pause(start: 5.0, length: 0.6),
        Pause(start: 8.0, length: 3.0),
        Pause(start: 13.0, length: 0.45),
        Pause(start: 16.0, length: 2.0),
        Pause(start: 20.0, length: 0.4)
    ]
    private static let episodeLength: Double = 24

    private struct Piece {
        let start: Double
        let length: Double
        var end: Double { start + length }
    }

    // MARK: - Tests

    func testNothingOutsideAPauseIsEverDropped() throws {
        for mix in Self.mixes {
            for tier in TrimSilenceTier.allCases {
                let pieces = try trim(mix, tier: tier)
                var previousEnd = 0.0
                for piece in pieces {
                    if piece.start - previousEnd > 0.001 {
                        let real = Self.pauses.contains {
                            previousEnd >= $0.start - Self.edge && piece.start <= $0.end + Self.edge
                        }
                        XCTAssertTrue(real, "\(mix.name)/\(tier): dropped \(previousEnd)–\(piece.start)")
                    }
                    previousEnd = piece.end
                }
            }
        }
    }

    func testPlaybackCoversTheFileFromStartToEnd() throws {
        for mix in Self.mixes {
            let pieces = try trim(mix, tier: .max)
            XCTAssertEqual(pieces.first?.start ?? -1, 0, accuracy: 0.001, mix.name)
            XCTAssertEqual(pieces.last?.end ?? -1, Self.episodeLength, accuracy: 0.05, mix.name)
        }
    }

    /// The counter and the remaining length are both read off the tier's arithmetic.
    func testSavingMatchesWhatTheTierPromises() throws {
        for mix in Self.mixes {
            for tier in TrimSilenceTier.allCases {
                let played = try trim(mix, tier: tier).reduce(0) { $0 + $1.length }
                let promised = Self.pauses.reduce(0.0) { total, pause in
                    guard tier.isWorthTrimming(pauseLength: pause.length) else { return total }
                    return total + (pause.length - tier.playedLength(ofPause: pause.length))
                }
                XCTAssertEqual(
                    Self.episodeLength - played, promised, accuracy: 0.35, "\(mix.name)/\(tier)"
                )
            }
        }
    }

    func testEachTierTrimsMoreThanTheOneBelowIt() throws {
        let played = try TrimSilenceTier.allCases.map { tier in
            try trim(Self.mixes[1], tier: tier).reduce(0) { $0 + $1.length }
        }
        XCTAssertEqual(played, played.sorted(by: >), "the tiers are not ordered by how much they trim")
        XCTAssertLessThan(played[2], Self.episodeLength - 4, "max barely trims anything")
    }

    func testSpeechComesOutUnattenuated() throws {
        for mix in Self.mixes {
            for tier in TrimSilenceTier.allCases {
                let peak = try trim(mix, tier: tier, peak: true).1
                XCTAssertGreaterThan(peak, mix.speechLevel * 0.9, "\(mix.name)/\(tier)")
            }
        }
    }

    func testAResetStartsOverAtTheNewPosition() throws {
        let url = try Self.makeEpisode(Self.mixes[1])
        defer { try? FileManager.default.removeItem(at: url) }
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let remover = SilenceRemover(format: format, tier: .max)

        _ = try Self.feed(file, into: remover, seconds: 4)
        let frame = AVAudioFramePosition(12 * format.sampleRate)
        file.framePosition = frame
        remover.reset(startingAt: frame)
        let after = try Self.feed(file, into: remover, seconds: 4)

        XCTAssertEqual(after.first?.start ?? -1, 12, accuracy: 0.001, "the first piece is not where the seek went")
        XCTAssertTrue(after.allSatisfy { $0.start >= 12 }, "a piece from before the seek was still held")
    }

    func testTheEngineReportsTheEpisodesOwnClock() throws {
        let url = try Self.makeEpisode(Self.mixes[1])
        defer { try? FileManager.default.removeItem(at: url) }
        let engine = PodcastAudioEngine()
        defer { engine.unload() }

        try engine.load(url: url, tier: .medium, startAt: 5)
        XCTAssertEqual(engine.duration, Self.episodeLength, accuracy: 0.05, "the file's length, not the played one")
        XCTAssertEqual(engine.currentTime, 5, accuracy: 0.05, "loaded away from where it was asked to start")
        XCTAssertEqual(engine.playedTime, 0, accuracy: 0.001, "nothing has been rendered yet")

        engine.seek(to: 15)
        XCTAssertEqual(engine.currentTime, 15, accuracy: 0.05)
    }

    /// `flush()` blocks for tens of milliseconds and every caller is on the main actor.
    func testSeekingDoesNotBlockTheCaller() throws {
        let url = try Self.makeEpisode(Self.mixes[1])
        defer { try? FileManager.default.removeItem(at: url) }
        let engine = PodcastAudioEngine()
        defer { engine.unload() }

        try engine.load(url: url, tier: .medium, startAt: 0)
        engine.play(rate: 1)
        var worst: Double = 0
        var last: Double = 0
        for step in 0..<40 {
            last = 4 + Double(step) * 0.4
            let started = Date()
            engine.seek(to: last)
            worst = max(worst, Date().timeIntervalSince(started))
            XCTAssertEqual(engine.currentTime, last, accuracy: 0.05, "the position lagged behind the seek")
        }
        XCTAssertLessThan(worst, 0.02, "a seek held its caller up for \(Int(worst * 1000))ms")

        // and the last of them is the one that plays: a scrub leaves the renderer where the finger stopped
        let playing = expectation(description: "playback carried on from the last seek")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { playing.fulfill() }
        wait(for: [playing], timeout: 5)
        XCTAssertGreaterThan(engine.currentTime, last, "playback never resumed after the scrub")
        XCTAssertLessThan(engine.currentTime, last + 3, "playback carried on from somewhere else entirely")
    }

    /// What the offline checks can't see: that the graph actually renders.
    func testTheEngineRendersAndTrimsWhatItPlays() throws {
        let url = try Self.makeEpisode(Self.mixes[1])
        defer { try? FileManager.default.removeItem(at: url) }
        let engine = PodcastAudioEngine()
        defer { engine.unload() }

        try engine.load(url: url, tier: .max, startAt: 0)
        // four times over, so six seconds of episode takes a second and a half of test
        engine.play(rate: 4)
        let deadline = Date().addingTimeInterval(20)
        while engine.playedTime < 6, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        XCTAssertGreaterThan(engine.playedTime, 5, "the engine rendered nothing")
        XCTAssertTrue(engine.isPlaying)
        // the pauses at 2s and 5s are inside what has played, and are worth about a second between them
        XCTAssertGreaterThan(
            engine.currentTime, engine.playedTime + 0.5, "the episode's clock never pulled ahead of the audio"
        )
    }

    /// The renderer's clock runs on past the last sample enqueued.
    func testPlaybackEndsAtTheEndOfTheEpisode() throws {
        let url = try Self.makeEpisode(Self.mixes[1])
        defer { try? FileManager.default.removeItem(at: url) }
        let engine = PodcastAudioEngine()
        defer { engine.unload() }

        let ended = expectation(description: "the episode ended")
        engine.onEnded = { ended.fulfill() }
        try engine.load(url: url, tier: .medium, startAt: Self.episodeLength - 4)
        engine.play(rate: 3)

        wait(for: [ended], timeout: 20)
        XCTAssertFalse(engine.isPlaying, "playback was left running past the end")
        // loading four seconds from the end and reading the file from the top instead played the whole episode
        // again, under a clock that said otherwise
        XCTAssertLessThan(engine.playedTime, 6, "the whole episode played, not the last few seconds of it")
        XCTAssertEqual(engine.currentTime, Self.episodeLength, accuracy: 1.5)
    }

    /// Fed per-channel buffers the renderer reports `.rendering` and puts out digital silence.
    func testTheRendererIsFedInterleavedAudio() throws {
        for channels in [1, 2] as [AVAudioChannelCount] {
            let decoded = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: channels))
            XCTAssertFalse(decoded.isInterleaved, "a decoded file is one buffer per channel")

            let fed = try XCTUnwrap(PodcastAudioEngine.rendererFormat(for: decoded))
            XCTAssertTrue(fed.isInterleaved, "\(channels) channel(s) would reach the renderer deinterleaved")
            XCTAssertEqual(fed.sampleRate, decoded.sampleRate)
            XCTAssertEqual(fed.channelCount, decoded.channelCount)
            XCTAssertEqual(fed.commonFormat, .pcmFormatFloat32)
        }
    }

    // MARK: - The readout

    func testTheMultiplierIsWhatTrimmingAddsToPlayback() {
        // an hour of listening that gave back six minutes plays 1.1x faster than the rate that was set
        let stats = TrimSilenceStats(saved: 360, played: 3600)
        XCTAssertEqual(stats.multiplier, 1.1, accuracy: 0.001)
        XCTAssertEqual(stats.effectiveSpeed(at: 1), 1.1, accuracy: 0.001)
        XCTAssertEqual(stats.effectiveSpeed(at: 1.5), 1.65, accuracy: 0.001)
    }

    func testTheMultiplierIsOneUntilThereIsSomethingToDivide() {
        XCTAssertEqual(TrimSilenceStats(saved: 0, played: 0).multiplier, 1)
        XCTAssertEqual(TrimSilenceStats(saved: 12, played: 0).multiplier, 1, "divided by nothing")
        XCTAssertEqual(TrimSilenceStats(saved: 0, played: 900).multiplier, 1, "nothing was trimmed")
        XCTAssertEqual(TrimSilenceStats(saved: 3, played: 0.5).multiplier, 1, "half a second is not a sample")
    }

    /// `played` shipped a release after `saved`, so an old install arrives with only one half.
    func testASavingWithNoListeningBehindItIsNotDivided() {
        let stale = TrimSilenceStats(storedSaved: 4200, storedPlayed: 0)
        XCTAssertEqual(stale.saved, 0, "a total from before the pair existed was carried over")
        XCTAssertEqual(stale.multiplier, 1)
        XCTAssertEqual(stale.effectiveSpeed(at: 1.7), 1.7, accuracy: 0.001)

        let counted = TrimSilenceStats(storedSaved: 60, storedPlayed: 3000)
        XCTAssertEqual(counted.saved, 60, "a pair written together is what it says")
        XCTAssertEqual(counted.multiplier, 1.02, accuracy: 0.001)
    }

    /// The saving accrues in tenths; a whole-second readout sat still for the first minute.
    func testTheSavedTimeKeepsItsThousandths() {
        let stats = TrimSilenceStats(saved: 4.812, played: 60)
        XCTAssertGreaterThan(stats.saved.truncatingRemainder(dividingBy: 1), 0)
        let text = Duration.seconds(stats.saved)
            .formatted(.time(pattern: .minuteSecond(padMinuteToLength: 1, fractionalSecondsLength: 3)))
        XCTAssertTrue(text.contains("812"), "thousandths were rounded away: \(text)")
    }

    // MARK: - Helpers

    /// How far outside a generated pause a detected edge may sit.
    private static let edge: Double = 0.06

    /// The last is the one a fixed threshold gets wrong.
    private static let mixes = [
        Mix(name: "digital silence", speechLevel: 0.30, roomToneDb: nil),
        Mix(name: "room tone at -45 dB", speechLevel: 0.30, roomToneDb: -45),
        Mix(name: "room tone at -38 dB", speechLevel: 0.30, roomToneDb: -38),
        Mix(name: "a quietly mixed episode", speechLevel: 0.03, roomToneDb: -45)
    ]

    private func trim(_ mix: Mix, tier: TrimSilenceTier) throws -> [Piece] {
        try trim(mix, tier: tier, peak: false).0
    }

    private func trim(_ mix: Mix, tier: TrimSilenceTier, peak wantsPeak: Bool) throws -> ([Piece], Float) {
        let url = try Self.makeEpisode(mix)
        defer { try? FileManager.default.removeItem(at: url) }
        let file = try AVAudioFile(forReading: url)
        let remover = SilenceRemover(format: file.processingFormat, tier: tier)
        var peak: Float = 0
        let pieces = try Self.feed(file, into: remover, seconds: nil) { chunk in
            guard wantsPeak, let data = chunk.buffer.floatChannelData?[0] else { return }
            for index in 0..<Int(chunk.frameLength) { peak = Swift.max(peak, abs(data[index])) }
        }
        return (pieces, peak)
    }

    private static func feed(
        _ file: AVAudioFile,
        into remover: SilenceRemover,
        seconds: Double?,
        onChunk: (TrimmedChunk) -> Void = { _ in }
    ) throws -> [Piece] {
        let format = file.processingFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(format.sampleRate))
        else {
            return []
        }
        var pieces: [Piece] = []
        func take(_ chunks: [TrimmedChunk]) {
            for chunk in chunks {
                onChunk(chunk)
                pieces.append(Piece(
                    start: Double(chunk.fileStart) / format.sampleRate,
                    length: Double(chunk.frameLength) / format.sampleRate
                ))
            }
        }
        var read = 0.0
        while file.framePosition < file.length, seconds.map({ read < $0 }) ?? true {
            try file.read(into: buffer, frameCount: buffer.frameCapacity)
            guard buffer.frameLength > 0 else { break }
            read += Double(buffer.frameLength) / format.sampleRate
            take(remover.process(buffer))
        }
        if seconds == nil { take(remover.finish()) }
        return pieces
    }

    /// Speech wobbles rather than being a pure sine, so window levels differ.
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
}
