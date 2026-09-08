//
//  SilenceRemover.swift
//  UnwatchedShared
//

import Accelerate
import AVFoundation
import OSLog

/// A stretch of the file that survived trimming.
public struct TrimmedChunk {
    public let buffer: AVAudioPCMBuffer
    /// The file frame the first sample was read from.
    public let fileStart: AVAudioFramePosition

    public var frameLength: AVAudioFrameCount { buffer.frameLength }
}

/// Shortens pauses by dropping samples out of them as the episode plays: a run of quiet is held
/// until the speech after it arrives, and its own length says how much to keep.
public final class SilenceRemover {
    private let format: AVAudioFormat
    private let tier: TrimSilenceTier

    private let window: Int
    private let fade: Int
    private let maximumHeld: Int
    private let warmupWindows: Int

    /// The audio not yet handed out, one array per channel.
    private var channels: [[Float]]
    /// The file frame `channels[.][0]` was read from.
    private var base: AVAudioFramePosition = 0
    /// How much of `channels` has been measured.
    private var cursor = 0
    private var pieceStart = 0
    /// Where the pause being held started, nil while what's accumulating is audible.
    private var run: Int?

    private var windowsSeen = 0
    private var primed = false
    private var noiseFloorDb: Double = 0
    private var speechLevelDb: Double = 0

    public init(format: AVAudioFormat, tier: TrimSilenceTier, startingAt fileFrame: AVAudioFramePosition = 0) {
        self.format = format
        self.tier = tier
        window = max(1, Int(format.sampleRate * Const.silenceWindow))
        fade = max(1, Int(format.sampleRate * Const.silenceSpliceFade))
        maximumHeld = Int(format.sampleRate * Const.silenceMaximumHeldPause)
        warmupWindows = Int(Const.silenceWarmup / Const.silenceWindow)
        channels = Array(repeating: [], count: Int(format.channelCount))
        base = fileFrame
    }

    /// What a seek needs: the audio either side of it is no longer adjacent.
    public func reset(startingAt fileFrame: AVAudioFramePosition) {
        for index in channels.indices { channels[index].removeAll(keepingCapacity: true) }
        base = fileFrame
        cursor = 0
        pieceStart = 0
        run = nil
        windowsSeen = 0
        primed = false
    }

    // MARK: - Feeding

    /// Returns what should play, in order — several pieces, one, or none while a pause is held.
    public func process(_ buffer: AVAudioPCMBuffer) -> [TrimmedChunk] {
        append(buffer)
        var out: [TrimmedChunk] = []

        while cursor + window <= channels[0].count {
            if isSilent(level(at: cursor, count: window)) {
                if run == nil {
                    if cursor > pieceStart, let piece = chunk(pieceStart..<cursor) { out.append(piece) }
                    pieceStart = cursor
                    run = cursor
                }
                cursor += window
                if let start = run, cursor - start >= maximumHeld {
                    out += close(run: start..<cursor)
                }
            } else {
                if let start = run {
                    out += close(run: start..<cursor)
                }
                cursor += window
            }
        }

        if run == nil, cursor > pieceStart, let piece = chunk(pieceStart..<cursor) {
            out.append(piece)
            pieceStart = cursor
        }
        compact()
        return out
    }

    /// Hands out what is left, including samples that never filled a window.
    public func finish() -> [TrimmedChunk] {
        let end = channels[0].count
        var out: [TrimmedChunk] = []
        if let start = run {
            out += close(run: start..<end)
        } else if end > pieceStart, let piece = chunk(pieceStart..<end) {
            out.append(piece)
        }
        cursor = end
        pieceStart = end
        compact()
        return out
    }

    // MARK: - Splicing

    /// A held pause either plays whole, or its two ends play and its middle never does.
    private func close(run range: Range<Int>) -> [TrimmedChunk] {
        defer {
            run = nil
            pieceStart = range.upperBound
        }
        let frames = range.count
        let seconds = Double(frames) / format.sampleRate
        guard tier.isWorthTrimming(pauseLength: seconds) else {
            return chunk(range).map { [$0] } ?? []
        }
        let kept = Int((tier.playedLength(ofPause: seconds) * format.sampleRate).rounded())
        // the fades come out of what is kept
        guard kept > 2 * fade, kept + 2 * fade < frames else {
            return chunk(range).map { [$0] } ?? []
        }

        let head = kept / 2
        let tail = kept - head
        return [
            chunk(range.lowerBound..<(range.lowerBound + head), fadeOutLast: fade),
            chunk((range.upperBound - tail)..<range.upperBound, fadeInFirst: fade)
        ].compactMap { $0 }
    }

    // MARK: - Level

    /// dBFS over `count` frames.
    private func level(at index: Int, count: Int) -> Double {
        var total: Float = 0
        for channel in channels {
            var meanSquare: Float = 0
            channel.withUnsafeBufferPointer { pointer in
                guard let start = pointer.baseAddress else { return }
                vDSP_measqv(start + index, 1, &meanSquare, vDSP_Length(count))
            }
            total += meanSquare
        }
        let mean = total / Float(channels.count)
        guard mean > 0 else { return Const.silenceAnalysisFloorDb }
        return max(Const.silenceAnalysisFloorDb, 10 * log10(Double(mean)))
    }

    /// Above the running noise floor but never near the speech level, so a quiet show stays intelligible.
    private var threshold: Double {
        let ceiling = min(Const.silenceThresholdCeilingDb, speechLevelDb - Const.silenceSpeechSeparationDb)
        return min(max(noiseFloorDb + Const.silenceNoiseMarginDb, Const.silenceThresholdFloorDb), ceiling)
    }

    private func isSilent(_ db: Double) -> Bool {
        if !primed {
            noiseFloorDb = db
            speechLevelDb = db
            primed = true
        }
        noiseFloorDb += (db - noiseFloorDb) * (db < noiseFloorDb ? Self.floorFall : Self.floorRise)
        speechLevelDb += (db - speechLevelDb) * (db > speechLevelDb ? Self.speechRise : Self.speechFall)
        windowsSeen += 1
        guard windowsSeen > warmupWindows else { return false }
        return db < threshold
    }

    /// One window's share of an exponential move, for a time constant in seconds.
    private static func coefficient(_ seconds: Double) -> Double {
        1 - exp(-Const.silenceWindow / seconds)
    }

    // the floor falls fast and rises slowly so speech can't drag it up; the speech level does the opposite
    private static let floorFall = coefficient(0.15)
    private static let floorRise = coefficient(6)
    private static let speechRise = coefficient(0.05)
    private static let speechFall = coefficient(4)

    // MARK: - Buffers

    private func append(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }
        let sourceChannels = Int(buffer.format.channelCount)
        for index in channels.indices {
            let source = data[min(index, sourceChannels - 1)]
            channels[index].append(contentsOf: UnsafeBufferPointer(start: source, count: frames))
        }
    }

    private func chunk(_ range: Range<Int>, fadeOutLast: Int = 0, fadeInFirst: Int = 0) -> TrimmedChunk? {
        let frames = AVAudioFrameCount(range.count)
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buffer.floatChannelData else {
            return nil
        }
        buffer.frameLength = frames
        for index in channels.indices {
            channels[index].withUnsafeBufferPointer { pointer in
                guard let start = pointer.baseAddress else { return }
                data[index].update(from: start + range.lowerBound, count: range.count)
            }
            if fadeOutLast > 0 {
                ramp(data[index] + (range.count - fadeOutLast), count: fadeOutLast, from: 1, to: 0)
            }
            if fadeInFirst > 0 {
                ramp(data[index], count: fadeInFirst, from: 0, to: 1)
            }
        }
        return TrimmedChunk(buffer: buffer, fileStart: base + AVAudioFramePosition(range.lowerBound))
    }

    private func ramp(_ samples: UnsafeMutablePointer<Float>, count: Int, from: Float, to: Float) {
        var value = from
        var step = (to - from) / Float(count)
        vDSP_vrampmul(samples, 1, &value, &step, samples, 1, vDSP_Length(count))
    }

    private func compact() {
        guard pieceStart > 0 else { return }
        for index in channels.indices { channels[index].removeFirst(pieceStart) }
        base += AVAudioFramePosition(pieceStart)
        cursor -= pieceStart
        run = run.map { $0 - pieceStart }
        pieceStart = 0
    }
}
