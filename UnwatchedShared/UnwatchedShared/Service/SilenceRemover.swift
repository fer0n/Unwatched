//
//  SilenceRemover.swift
//  UnwatchedShared
//

import Accelerate
import AVFoundation

/// A stretch of the file that survived trimming.
public struct TrimmedChunk {
    public let buffer: AVAudioPCMBuffer
    /// The file frame the first sample was read from.
    public let fileStart: AVAudioFramePosition

    public var frameLength: AVAudioFrameCount { buffer.frameLength }
}

/// Shortens pauses by dropping samples out of them as the episode plays: every block of quiet is cross-faded down
/// to a fraction of itself, so a pause keeps the same share of its length however long it is.
public final class SilenceRemover {
    private let format: AVAudioFormat
    private let threshold: Float
    private let block = Const.silenceBlockFrames
    private let kept = Const.silenceKeptFrames
    private let segment = Const.silenceSegmentFrames
    private let fadeOut: [Float]
    private let fadeIn: [Float]

    /// The audio not yet handed out, one array per channel.
    private var channels: [[Float]]
    /// The file frame `channels[.][0]` was read from.
    private var base: AVAudioFramePosition = 0
    /// Where playback started from, which the segments are counted from.
    private var origin: AVAudioFramePosition = 0
    /// Where the next block would start.
    private var cursor = 0
    /// The first sample not yet copied into `output`.
    private var pieceStart = 0

    /// What plays next, gathered until it's handed out.
    private var output: [[Float]]
    private var outputFileStart: AVAudioFramePosition = 0
    /// Audio after a shortened block can't share its piece: the piece's clock would run on from the wrong frame.
    private var outputEndsInBlock = false

    public init(format: AVAudioFormat, startingAt fileFrame: AVAudioFramePosition = 0) {
        self.format = format
        threshold = powf(10, Float(Const.silenceThresholdDb) / 20)
        let kept = Const.silenceKeptFrames
        fadeOut = (0..<kept).map { 1 - Float($0) / Float(kept) }
        fadeIn = fadeOut.reversed()
        channels = Array(repeating: [], count: Int(format.channelCount))
        output = channels
        base = fileFrame
        origin = fileFrame
    }

    /// What a seek needs: the audio either side of it is no longer adjacent.
    public func reset(startingAt fileFrame: AVAudioFramePosition) {
        for index in channels.indices {
            channels[index].removeAll(keepingCapacity: true)
            output[index].removeAll(keepingCapacity: true)
        }
        base = fileFrame
        origin = fileFrame
        cursor = 0
        pieceStart = 0
        outputEndsInBlock = false
    }

    // MARK: - Feeding

    /// Returns what should play, in order.
    public func process(_ buffer: AVAudioPCMBuffer) -> [TrimmedChunk] {
        append(buffer)
        var out: [TrimmedChunk] = []

        while cursor + block <= channels[0].count {
            let position = Int(base - origin) + cursor
            let boundary = (position / segment + 1) * segment
            if position + block > boundary {
                cursor += boundary - position
                continue
            }
            if let loud = lastLoudSample(in: cursor..<(cursor + block)) {
                // no block that starts at or before it can be quiet
                cursor = loud + 1
                continue
            }
            if pieceStart < cursor {
                appendRaw(pieceStart..<cursor, into: &out)
            }
            appendShortened(blockAt: cursor)
            cursor += block
            pieceStart = cursor
        }

        appendRaw(pieceStart..<cursor, into: &out)
        pieceStart = cursor
        flush(into: &out)
        compact()
        return out
    }

    /// Hands out what is left, including samples that never filled a block.
    public func finish() -> [TrimmedChunk] {
        var out: [TrimmedChunk] = []
        appendRaw(pieceStart..<channels[0].count, into: &out)
        flush(into: &out)
        cursor = channels[0].count
        pieceStart = cursor
        compact()
        return out
    }

    // MARK: - How much of a pause survives

    /// What a pause of `frames` plays as: every whole block shrinks, the part that doesn't fill one plays as is.
    public static func playedFrames(ofPause frames: Int) -> Int {
        let blocks = frames / Const.silenceBlockFrames
        return blocks * Const.silenceKeptFrames + frames % Const.silenceBlockFrames
    }

    // MARK: - Splicing

    /// The block's start fades out over its end, so the samples between them never play.
    private func appendShortened(blockAt start: Int) {
        if output[0].isEmpty {
            outputFileStart = base + AVAudioFramePosition(start)
        }
        let tail = start + block - kept
        for index in channels.indices {
            var mixed = [Float](repeating: 0, count: kept)
            channels[index].withUnsafeBufferPointer { samples in
                guard let pointer = samples.baseAddress else { return }
                vDSP_vmma(pointer + start, 1, fadeOut, 1, pointer + tail, 1, fadeIn, 1, &mixed, 1, vDSP_Length(kept))
            }
            output[index] += mixed
        }
        outputEndsInBlock = true
    }

    private func appendRaw(_ range: Range<Int>, into out: inout [TrimmedChunk]) {
        guard !range.isEmpty else { return }
        if outputEndsInBlock {
            flush(into: &out)
        }
        if output[0].isEmpty {
            outputFileStart = base + AVAudioFramePosition(range.lowerBound)
        }
        for index in channels.indices {
            output[index] += channels[index][range]
        }
    }

    private func flush(into out: inout [TrimmedChunk]) {
        defer { outputEndsInBlock = false }
        let frames = AVAudioFrameCount(output[0].count)
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buffer.floatChannelData else {
            return
        }
        buffer.frameLength = frames
        for index in output.indices {
            output[index].withUnsafeBufferPointer { samples in
                guard let pointer = samples.baseAddress else { return }
                data[index].update(from: pointer, count: Int(frames))
            }
            output[index].removeAll(keepingCapacity: true)
        }
        out.append(TrimmedChunk(buffer: buffer, fileStart: outputFileStart))
    }

    // MARK: - Level

    /// The last sample in `range` that any channel peaks above the threshold at, nil if the whole range is quiet.
    private func lastLoudSample(in range: Range<Int>) -> Int? {
        var last: Int?
        for channel in channels {
            channel.withUnsafeBufferPointer { samples in
                var index = range.upperBound - 1
                let floor = Swift.max(range.lowerBound, (last ?? -1) + 1)
                while index >= floor {
                    if abs(samples[index]) > threshold {
                        last = index
                        return
                    }
                    index -= 1
                }
            }
        }
        return last
    }

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

    private func compact() {
        guard pieceStart > 0 else { return }
        for index in channels.indices { channels[index].removeFirst(pieceStart) }
        base += AVAudioFramePosition(pieceStart)
        cursor -= pieceStart
        pieceStart = 0
    }
}
