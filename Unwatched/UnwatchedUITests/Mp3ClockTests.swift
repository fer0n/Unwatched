//
//  Mp3ClockTests.swift
//  UnwatchedUITests
//

import XCTest
import UnwatchedShared

final class Mp3ClockTests: XCTestCase {

    /// MPEG1 Layer3, 128 kbit/s, 44.1 kHz, no padding: 144 * 128000 / 44100 = 417 bytes a frame.
    private static let frameLength = 417

    private func cbrMp3(frames: Int, id3Bytes: Int = 0, xing: Bool = false) -> Data {
        var data = Data()
        if id3Bytes > 0 {
            let size = id3Bytes - 10
            data.append(contentsOf: [0x49, 0x44, 0x33, 0x03, 0x00, 0x00])
            data.append(contentsOf: [
                UInt8((size >> 21) & 0x7F), UInt8((size >> 14) & 0x7F),
                UInt8((size >> 7) & 0x7F), UInt8(size & 0x7F)
            ])
            data.append(Data(repeating: 0, count: size))
        }
        for index in 0..<frames {
            var frame = Data([0xFF, 0xFB, 0x90, 0x00])
            if xing, index == 0 {
                frame.append(Data(repeating: 0, count: 32))
                frame.append(Data("Xing".utf8))
            }
            frame.append(Data(repeating: 0, count: Self.frameLength - frame.count))
            data.append(frame)
        }
        return data
    }

    func testTheClockReadsBitrateAndDurationOfACbrFile() async throws {
        let frames = 1000
        let clock = try await Mp3Clock.read(from: DataByteSource(data: cbrMp3(frames: frames)))
        let unwrapped = try XCTUnwrap(clock)

        XCTAssertEqual(unwrapped.audioStart, 0)
        XCTAssertEqual(unwrapped.bytesPerSecond, 16000, accuracy: 0.001)
        XCTAssertEqual(unwrapped.duration, Double(frames * Self.frameLength) / 16000, accuracy: 0.01)
    }

    func testTheClockSkipsAnId3TagAndCountsTimeFromTheFirstFrame() async throws {
        let tag = 4096
        let source = DataByteSource(data: cbrMp3(frames: 1000, id3Bytes: tag))
        let read = try await Mp3Clock.read(from: source)
        let clock = try XCTUnwrap(read)

        XCTAssertEqual(clock.audioStart, tag, "the tag isn't audio and must not count as time")
        XCTAssertEqual(clock.byteOffset(for: 0), tag)
        XCTAssertEqual(clock.byteOffset(for: 10), tag + 160_000)
    }

    func testAVariableBitrateFileHasNoUsableClock() async throws {
        let source = DataByteSource(data: cbrMp3(frames: 1000, xing: true))
        let clock = try await Mp3Clock.read(from: source)
        XCTAssertNil(clock, "byte offsets say nothing about time in a VBR file")
    }

    func testATinyFileHasNoUsableClock() async throws {
        let empty = try await Mp3Clock.read(from: DataByteSource(data: Data()))
        XCTAssertNil(empty)

        let noFrames = try await Mp3Clock.read(from: DataByteSource(data: Data(repeating: 0, count: 4096)))
        XCTAssertNil(noFrames)
    }

    func testASliceStartsOnAFrameBoundaryAtTheRequestedTime() async throws {
        let source = DataByteSource(data: cbrMp3(frames: 2000, id3Bytes: 2048))
        let opened = try await AudioSliceReader(source: source)
        let reader = try XCTUnwrap(opened)

        let url = try await reader.slice(at: 10, length: 8)
        defer { try? FileManager.default.removeItem(at: url) }
        let slice = try Data(contentsOf: url)

        XCTAssertEqual(Array(slice.prefix(2)), [0xFF, 0xFB], "a slice has to decode from its own start")
        XCTAssertGreaterThanOrEqual(slice.count, 8 * 16000)
        XCTAssertLessThan(slice.count, 8 * 16000 + Self.frameLength + 2048)
    }
}

/// Stands in for a downloaded episode, so the byte-level parsing can be checked without one.
private struct DataByteSource: AudioByteSource {
    let data: Data

    func length() async throws -> Int { data.count }

    func bytes(in range: Range<Int>) async throws -> Data {
        let clamped = range.clamped(to: 0..<data.count)
        return data.subdata(in: clamped)
    }
}
