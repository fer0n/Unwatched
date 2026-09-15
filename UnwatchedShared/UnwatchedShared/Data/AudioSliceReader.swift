//
//  AudioSliceReader.swift
//  UnwatchedShared
//

import Foundation

/// Hands out short windows of an episode as standalone files the speech model can read.
///
/// A window is a byte range copied out verbatim and trimmed to the next frame boundary, so it
/// decodes from its own start and needs no seeking. When the episode plays is derived from the
/// byte offset instead.
public struct AudioSliceReader: Sendable {
    private let source: AudioByteSource
    private let clock: Mp3Clock
    private let totalLength: Int

    public var duration: Double { clock.duration }

    public init?(source: AudioByteSource) async throws {
        guard let clock = try await Mp3Clock.read(from: source) else { return nil }
        self.source = source
        self.clock = clock
        self.totalLength = try await source.length()
    }

    /// The window starting at `time`, written to a temporary file the caller has to delete.
    public func slice(at time: Double, length: Double) async throws -> URL {
        let start = clock.byteOffset(for: time)
        let end = min(totalLength, clock.byteOffset(for: time + length) + 2048)
        guard start < end else { throw AudioByteSourceError.unreadable }

        let data = try await source.bytes(in: start..<end)
        guard let aligned = Self.trimmedToFrameBoundary(data) else {
            throw AudioByteSourceError.unreadable
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("probe-\(UUID().uuidString)")
            .appendingPathExtension("mp3")
        try aligned.write(to: url)
        return url
    }

    /// Drops the partial frame the range started in the middle of. It's shorter than a single
    /// frame, so the window's start time is unaffected at the resolution this measures.
    private static func trimmedToFrameBoundary(_ data: Data) -> Data? {
        guard let offset = Mp3Clock.firstFrameOffset(in: data.prefix(8192)) else { return nil }
        return data.subdata(in: offset..<data.count)
    }
}
