//
//  Transcript.swift
//  UnwatchedShared
//

import SwiftData


@Model public final class Transcript {
    @Attribute(.unique) public var youtubeId: String
    public var data: Data

    public init(_ youtubeId: String, data: Data) {
        self.youtubeId = youtubeId
        self.data = data
    }
}


public struct TranscriptEntry: Sendable, Identifiable, Codable {
    public let id = UUID()
    
    public let start: Double
    public let duration: Double
    public let text: String
    public var isParagraphEnd: Bool
    
    public init(start: Double, duration: Double, text: String, isParagraphEnd: Bool = false) {
        self.start = start
        self.duration = duration
        self.text = text
        self.isParagraphEnd = isParagraphEnd
    }
    
    public var minimalTextRepresentation: String {
        "\(Int(start)): \(text)"
    }
    
    private enum CodingKeys: String, CodingKey {
        case start,
             duration,
             text,
             isParagraphEnd
    }
}

/// Where a cached transcript came from, which decides whether restoring the show's own is on offer.
public enum TranscriptOrigin: String, Sendable, Codable {
    /// From YouTube's captions or published by the podcast itself.
    case published
    /// Transcribed on device.
    case generated
}

/// What's stored in `Transcript.data`. A cache written before the origin existed is a bare array
/// of entries and still decodes, see `TranscriptActor`.
public struct TranscriptPayload: Sendable, Codable {
    public let entries: [TranscriptEntry]
    public let origin: TranscriptOrigin

    public init(entries: [TranscriptEntry], origin: TranscriptOrigin) {
        self.entries = entries
        self.origin = origin
    }

    public static let empty = TranscriptPayload(entries: [], origin: .published)
}
