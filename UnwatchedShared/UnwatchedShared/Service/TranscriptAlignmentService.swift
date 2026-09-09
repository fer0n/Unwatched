//
//  TranscriptAlignmentService.swift
//  UnwatchedShared
//

#if !os(tvOS) && !os(watchOS)
import AVFoundation
import Foundation

public enum TranscriptAlignmentError: LocalizedError {
    case unsupportedFile
    case transcriptTooShort
    case inconclusive

    public var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            return String(localized: "transcriptAlignmentUnsupportedFile")
        case .transcriptTooShort:
            return String(localized: "transcriptAlignmentTooShort")
        case .inconclusive:
            return String(localized: "transcriptAlignmentInconclusive")
        }
    }
}

/// Works out how a published transcript's timings relate to the episode that actually plays, by
/// transcribing a few short windows and looking up where each one sits in the transcript.
///
/// Only the windows are transcribed, not the episode: a drifting transcript is corrected from
/// about 3% of the audio, and the publisher's own text - punctuated, with speaker labels - is
/// kept instead of being replaced by a machine transcript.
public enum TranscriptAlignmentService {
    static let coarseWindow: Double = 15
    static let fineWindow: Double = 8
    static let coarseInterval: Double = 300
    /// Two offsets this close are the same offset; anything more is an edit in between.
    static let offsetTolerance: Double = 4
    static let boundaryPrecision: Double = 4
    static let maximumBisectionSteps = 7
    /// Shorter than this and there's nothing worth transcribing in it.
    static let minimumGapToTranscribe: Double = 5

    /// Checks whether the transcript lines up with the audio, using as few probes as it can.
    /// Cheap enough to run whenever a published transcript is first shown.
    ///
    /// Throws `.inconclusive` when no probe could be placed at all: nothing was learned either
    /// way, and offering a correction that has nothing to work from would only fail later.
    public static func detectDrift(
        fileUrl: URL,
        entries: [TranscriptEntry],
        language: String?
    ) async throws -> Bool {
        let context = try await Context(fileUrl: fileUrl, entries: entries, language: language)
        let times = [0.12, 0.5, 0.85].map { $0 * context.duration }
        var offsets = [Double]()
        for time in times {
            if let offset = try await context.probe(at: time, window: coarseWindow).offset {
                offsets.append(offset)
            }
        }
        guard let first = offsets.first else {
            throw TranscriptAlignmentError.inconclusive
        }
        return offsets.contains { abs($0 - first) > offsetTolerance } || abs(first) > offsetTolerance
    }

    /// The full correction: where the transcript is shifted, and which spans of audio it doesn't
    /// cover at all.
    public static func align(
        fileUrl: URL,
        entries: [TranscriptEntry],
        language: String?,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> TranscriptAlignment {
        let context = try await Context(fileUrl: fileUrl, entries: entries, language: language)
        progress(0.05)

        let start = min(30, context.duration / 2)
        let step = max(coarseInterval, context.duration / 24)
        let times = Array(stride(from: start, to: max(start, context.duration - coarseWindow), by: step))

        var coarse = [AlignmentProbe]()
        for time in times {
            coarse.append(try await context.probe(at: time, window: coarseWindow))
            progress(0.05 + 0.55 * Double(coarse.count) / Double(max(1, times.count)))
        }

        let anchors = coarse.compactMap { probe -> (time: Double, offset: Double)? in
            guard let offset = probe.offset else { return nil }
            return (probe.audioTime, offset)
        }
        guard !anchors.isEmpty else {
            throw TranscriptAlignmentError.inconclusive
        }

        let edits = zip(anchors, anchors.dropFirst()).filter { before, after in
            abs(after.offset - before.offset) > offsetTolerance
        }
        var boundaries = [Boundary]()
        for (before, after) in edits {
            boundaries.append(try await context.findBoundary(after: before, before: after))
            progress(0.6 + 0.35 * Double(boundaries.count) / Double(edits.count))
        }
        progress(0.97)

        return assemble(anchors: anchors, boundaries: boundaries, duration: context.duration)
    }

    /// Transcribes the spans the published transcript doesn't cover, which is the only part of
    /// the episode that has to be machine-transcribed at all.
    ///
    /// A gap with no speech in it - music, a jingle, silence - contributes nothing and is left as
    /// a gap rather than being described.
    public static func transcribeGaps(
        fileUrl: URL,
        alignment: TranscriptAlignment,
        language: String?,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> [TranscriptEntry] {
        let gaps = alignment.gaps.filter { $0.duration >= minimumGapToTranscribe }
        guard !gaps.isEmpty else { return [] }
        guard let reader = try await AudioSliceReader(source: FileByteSource(url: fileUrl)) else {
            throw TranscriptAlignmentError.unsupportedFile
        }
        let locale = try await SpeechTranscriptService.prepare(language: language)

        var entries = [TranscriptEntry]()
        for (index, gap) in gaps.enumerated() {
            let sliceUrl: URL
            do {
                sliceUrl = try await reader.slice(at: gap.audioStart, length: gap.duration)
            } catch {
                Log.warning("gap at \(Int(gap.audioStart))s couldn't be read")
                continue
            }
            defer { try? FileManager.default.removeItem(at: sliceUrl) }

            do {
                let transcribed = try await SpeechTranscriptService.transcribe(
                    fileUrl: sliceUrl,
                    language: locale.identifier
                ) { fraction in
                    progress((Double(index) + fraction) / Double(gaps.count))
                }
                entries.append(contentsOf: transcribed.map {
                    TranscriptEntry(
                        start: gap.audioStart + $0.start,
                        duration: $0.duration,
                        text: $0.text
                    )
                })
            } catch {
                Log.info("gap at \(Int(gap.audioStart))s holds no speech")
            }
            progress(Double(index + 1) / Double(gaps.count))
        }
        return entries
    }

    public struct Boundary {
        public let gapStart: Double
        public let gapEnd: Double
        public let offsetAfter: Double

        public init(gapStart: Double, gapEnd: Double, offsetAfter: Double) {
            self.gapStart = gapStart
            self.gapEnd = gapEnd
            self.offsetAfter = offsetAfter
        }

        public var hasGap: Bool { gapEnd - gapStart > 1 }
    }

    /// Turns the measured offsets and boundaries into contiguous segments over the whole episode.
    public static func assemble(
        anchors: [(time: Double, offset: Double)],
        boundaries: [Boundary],
        duration: Double
    ) -> TranscriptAlignment {
        guard let firstOffset = anchors.first?.offset else { return .identity }

        var segments = [TranscriptAlignment.Segment]()
        var gaps = [TranscriptAlignment.Gap]()
        var segmentStart: Double = 0
        var offset = firstOffset

        for boundary in boundaries {
            segments.append(
                TranscriptAlignment.Segment(
                    audioStart: segmentStart,
                    audioEnd: boundary.gapStart,
                    offset: offset
                )
            )
            if boundary.hasGap {
                gaps.append(
                    TranscriptAlignment.Gap(audioStart: boundary.gapStart, audioEnd: boundary.gapEnd)
                )
            }
            segmentStart = boundary.gapEnd
            offset = boundary.offsetAfter
        }
        segments.append(
            TranscriptAlignment.Segment(audioStart: segmentStart, audioEnd: duration, offset: offset)
        )
        return TranscriptAlignment(segments: segments, gaps: gaps)
    }
}
#endif
