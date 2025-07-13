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
    
    private enum CodingKeys: String, CodingKey {
        case start,
             duration,
             text,
             isParagraphEnd
    }
}
