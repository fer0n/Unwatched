//
//  AudioByteSource.swift
//  UnwatchedShared
//

import Foundation

/// Random access to an episode's bytes.
///
/// Deliberately local-only: shows that insert ads do it per request, so the bytes one fetch
/// returns are not the bytes another one gets. Offsets are only meaningful for the file that
/// actually plays, which is the downloaded one.
public protocol AudioByteSource: Sendable {
    func length() async throws -> Int
    func bytes(in range: Range<Int>) async throws -> Data
}

public enum AudioByteSourceError: LocalizedError {
    case unreadable

    public var errorDescription: String? {
        String(localized: "transcriptAlignmentUnsupportedFile")
    }
}

public struct FileByteSource: AudioByteSource {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func length() async throws -> Int {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let size = values.fileSize else { throw AudioByteSourceError.unreadable }
        return size
    }

    public func bytes(in range: Range<Int>) async throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(range.lowerBound))
        return try handle.read(upToCount: range.count) ?? Data()
    }
}
