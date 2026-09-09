//
//  Mp3Clock.swift
//  UnwatchedShared
//

import Foundation

/// Converts between time and byte offset in a constant-bitrate MP3.
///
/// Probing an episode means reading short windows from arbitrary places in it, and each window's
/// byte offset is what says when it plays. That only holds for constant bitrate: a variable-rate
/// file has no such mapping and has to be decoded instead.
public struct Mp3Clock: Sendable {
    public let audioStart: Int
    public let bytesPerSecond: Double
    public let duration: Double

    private static let mpeg1Layer3Bitrates = [
        0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0
    ]
    private static let mpeg2Layer3Bitrates = [
        0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0
    ]
    private static let sampleRates = [
        [44100, 48000, 32000],
        [22050, 24000, 16000],
        [11025, 12000, 8000]
    ]

    /// Reads enough of the head of the file to find the first frame, then checks frames further in
    /// to confirm the bitrate really is constant.
    public static func read(from source: AudioByteSource) async throws -> Mp3Clock? {
        let totalLength = try await source.length()
        guard totalLength > 0 else { return nil }

        let head = try await source.bytes(in: 0..<min(totalLength, 10))
        var audioStart = 0
        if head.count == 10, head[0] == 0x49, head[1] == 0x44, head[2] == 0x33 {
            let size = (Int(head[6]) << 21) | (Int(head[7]) << 14) | (Int(head[8]) << 7) | Int(head[9])
            audioStart = size + 10
            if head[5] & 0x10 != 0 {
                audioStart += 10
            }
        }
        guard audioStart < totalLength else { return nil }

        let firstFrameWindow = try await source.bytes(in: audioStart..<min(totalLength, audioStart + 8192))
        guard let first = frame(in: firstFrameWindow) else { return nil }
        guard !hasVariableBitrateHeader(firstFrameWindow, frameOffset: first.offset) else { return nil }

        let frameStart = audioStart + first.offset
        let audioLength = totalLength - frameStart
        guard audioLength > 0 else { return nil }

        for fraction in [0.35, 0.7] {
            let probeOffset = frameStart + Int(Double(audioLength) * fraction)
            let window = try await source.bytes(in: probeOffset..<min(totalLength, probeOffset + 8192))
            guard let sample = frame(in: window), sample.bitrate == first.bitrate else { return nil }
        }

        let bytesPerSecond = Double(first.bitrate * 1000) / 8
        return Mp3Clock(
            audioStart: frameStart,
            bytesPerSecond: bytesPerSecond,
            duration: Double(audioLength) / bytesPerSecond
        )
    }

    /// Offset of the first byte that starts a real frame, for trimming a byte range so it decodes
    /// on its own. A bare sync word isn't enough: the pattern occurs inside audio data too.
    public static func firstFrameOffset(in data: Data) -> Int? {
        frame(in: data)?.offset
    }

    public func byteOffset(for time: Double) -> Int {
        audioStart + Int((max(0, time) * bytesPerSecond).rounded())
    }

    private struct Frame {
        let offset: Int
        let bitrate: Int
        let length: Int
    }

    /// The first position where two consecutive valid frame headers sit, which is what makes a
    /// sync word a real frame rather than a byte pattern inside other data.
    private static func frame(in data: Data) -> Frame? {
        let bytes = [UInt8](data)
        guard bytes.count > 4 else { return nil }
        for offset in 0..<(bytes.count - 4) {
            guard let candidate = header(bytes, offset) else { continue }
            let next = offset + candidate.length
            guard next + 4 <= bytes.count else { return candidate }
            guard let following = header(bytes, next), following.bitrate == candidate.bitrate else { continue }
            return candidate
        }
        return nil
    }

    private static func header(_ bytes: [UInt8], _ offset: Int) -> Frame? {
        guard offset + 4 <= bytes.count, bytes[offset] == 0xFF, bytes[offset + 1] & 0xE0 == 0xE0 else {
            return nil
        }
        let versionBits = (bytes[offset + 1] >> 3) & 0x03
        let layerBits = (bytes[offset + 1] >> 1) & 0x03
        guard layerBits == 0x01 else { return nil }

        let versionIndex: Int
        switch versionBits {
        case 0x03: versionIndex = 0
        case 0x02: versionIndex = 1
        case 0x00: versionIndex = 2
        default: return nil
        }

        let bitrateIndex = Int((bytes[offset + 2] >> 4) & 0x0F)
        let sampleRateIndex = Int((bytes[offset + 2] >> 2) & 0x03)
        guard bitrateIndex > 0, bitrateIndex < 15, sampleRateIndex < 3 else { return nil }

        let bitrate = versionIndex == 0
            ? mpeg1Layer3Bitrates[bitrateIndex]
            : mpeg2Layer3Bitrates[bitrateIndex]
        let sampleRate = sampleRates[versionIndex][sampleRateIndex]
        guard bitrate > 0, sampleRate > 0 else { return nil }

        let padding = Int((bytes[offset + 2] >> 1) & 0x01)
        let samplesPerFrame = versionIndex == 0 ? 144 : 72
        let length = samplesPerFrame * bitrate * 1000 / sampleRate + padding
        guard length > 4 else { return nil }
        return Frame(offset: offset, bitrate: bitrate, length: length)
    }

    /// A `Xing` header marks a variable-rate file; `Info` is the same structure written by
    /// constant-rate encoders and doesn't disqualify it.
    private static func hasVariableBitrateHeader(_ data: Data, frameOffset: Int) -> Bool {
        let bytes = [UInt8](data)
        let searchEnd = min(bytes.count, frameOffset + 200)
        guard frameOffset + 4 < searchEnd else { return false }
        for offset in frameOffset..<(searchEnd - 4) {
            if bytes[offset] == 0x58, bytes[offset + 1] == 0x69,
               bytes[offset + 2] == 0x6E, bytes[offset + 3] == 0x67 {
                return true
            }
        }
        return false
    }
}
