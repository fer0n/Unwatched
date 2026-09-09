//
//  TranscriptAlignment.swift
//  UnwatchedShared
//

import Foundation

/// Maps the timings of a published transcript onto the audio that actually plays.
///
/// A show that has ads inserted after its transcript was written keeps the transcript's text
/// intact but shifts everything after each insertion. The shift is constant between insertions,
/// so the whole correction is a handful of segments plus the spans of audio the transcript
/// doesn't cover at all.
public struct TranscriptAlignment: Codable, Sendable, Equatable {
    /// A stretch of audio whose transcript is off by a constant `offset`, where
    /// `audioTime = transcriptTime + offset`.
    public struct Segment: Codable, Sendable, Equatable {
        public let audioStart: Double
        public let audioEnd: Double
        public let offset: Double

        public init(audioStart: Double, audioEnd: Double, offset: Double) {
            self.audioStart = audioStart
            self.audioEnd = audioEnd
            self.offset = offset
        }

        public var transcriptStart: Double { audioStart - offset }
        public var transcriptEnd: Double { audioEnd - offset }
    }

    /// Audio with no counterpart in the published transcript. What it contains is unknown until
    /// something transcribes it.
    public struct Gap: Codable, Sendable, Equatable, Identifiable {
        public let audioStart: Double
        public let audioEnd: Double

        public init(audioStart: Double, audioEnd: Double) {
            self.audioStart = audioStart
            self.audioEnd = audioEnd
        }

        public var id: String { "\(audioStart)-\(audioEnd)" }
        public var duration: Double { max(0, audioEnd - audioStart) }
    }

    public let segments: [Segment]
    public let gaps: [Gap]

    public init(segments: [Segment], gaps: [Gap]) {
        self.segments = segments
        self.gaps = gaps
    }

    public static let identity = TranscriptAlignment(segments: [], gaps: [])

    /// True when the transcript already matches the audio and nothing needs shifting. An offset
    /// this small is measurement noise from interpolating word times inside a cue, not drift.
    public var isIdentity: Bool {
        gaps.isEmpty && segments.allSatisfy { abs($0.offset) < 1.5 }
    }

    public var totalGapDuration: Double {
        gaps.reduce(0) { $0 + $1.duration }
    }

    /// Shifts each entry by the offset of the segment it falls in. An entry outside every
    /// segment keeps the offset of the nearest one, so the ends of the transcript stay usable.
    public func applied(to entries: [TranscriptEntry]) -> [TranscriptEntry] {
        guard !segments.isEmpty else { return entries }
        return entries.map { entry in
            let offset = offsetForTranscriptTime(entry.start)
            guard offset != 0 else { return entry }
            return TranscriptEntry(
                start: max(0, entry.start + offset),
                duration: entry.duration,
                text: entry.text,
                isParagraphEnd: entry.isParagraphEnd
            )
        }
    }

    private func offsetForTranscriptTime(_ time: Double) -> Double {
        if let containing = segments.first(where: { time >= $0.transcriptStart && time < $0.transcriptEnd }) {
            return containing.offset
        }
        let nearest = segments.min { Self.distance(from: time, to: $0) < Self.distance(from: time, to: $1) }
        return nearest?.offset ?? 0
    }

    private static func distance(from time: Double, to segment: Segment) -> Double {
        max(segment.transcriptStart - time, time - segment.transcriptEnd, 0)
    }
}
