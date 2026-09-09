//
//  TranscriptAlignmentProbe.swift
//  UnwatchedShared
//

#if !os(tvOS) && !os(watchOS)
import AVFoundation
import Foundation

/// One sampled window of an episode: where it was read from, and what the transcript makes of it.
struct AlignmentProbe {
    enum Outcome {
        case matched(TranscriptMatcher.Match)
        /// Speech was transcribed but it isn't in the transcript.
        case absent
        /// No speech in the window. Music or silence is genuinely not transcript content.
        case silent
        /// The window couldn't be read at all, which is evidence of nothing.
        case failed
    }

    let audioTime: Double
    let outcome: Outcome

    var match: TranscriptMatcher.Match? {
        guard case .matched(let match) = outcome else { return nil }
        return match
    }

    var offset: Double? {
        guard let match else { return nil }
        return audioTime - match.time
    }

    /// Speech that isn't in the transcript, or no speech at all. A read failure is neither.
    var isGapEvidence: Bool {
        switch outcome {
        case .absent, .silent: return true
        case .matched, .failed: return false
        }
    }
}

extension TranscriptAlignmentService {
    /// Holds what every probe of one episode needs: the slicer, the index and the speech model.
    struct Context {
        let reader: AudioSliceReader
        let matcher: TranscriptMatcher
        let locale: Locale
        let duration: Double

        init(fileUrl: URL, entries: [TranscriptEntry], language: String?) async throws {
            let matcher = TranscriptMatcher(entries: entries)
            guard !matcher.isEmpty, let last = entries.last, last.start > 60 else {
                throw TranscriptAlignmentError.transcriptTooShort
            }
            guard let reader = try await AudioSliceReader(source: FileByteSource(url: fileUrl)) else {
                throw TranscriptAlignmentError.unsupportedFile
            }
            self.reader = reader
            self.matcher = matcher
            self.locale = try await SpeechTranscriptService.prepare(language: language)
            self.duration = reader.duration
        }

        /// Samples `time`, stepping aside by a window if that spot can't be read at all, and
        /// reporting where it actually sampled so a search can't stall on one bad offset.
        func probe(at time: Double, window: Double) async throws -> AlignmentProbe {
            for candidate in [time, time + window, time - window] {
                let clamped = max(0, min(candidate, max(0, duration - window)))
                if let probe = try await probeExactly(at: clamped, window: window) {
                    return probe
                }
            }
            Log.warning("probe \(Int(time))s: unreadable")
            return AlignmentProbe(audioTime: time, outcome: .failed)
        }

        private func probeExactly(at clamped: Double, window: Double) async throws -> AlignmentProbe? {
            guard let text = try await transcribeSlice(at: clamped, window: window) else { return nil }

            guard !text.isEmpty else {
                Log.info("probe \(Int(clamped))s: no speech")
                return AlignmentProbe(audioTime: clamped, outcome: .silent)
            }
            let located = matcher.locate(text)
            guard let match = located, match.votes >= TranscriptMatcher.minimumVotes else {
                Log.info("probe \(Int(clamped))s: absent (\(located?.votes ?? 0) votes)")
                return AlignmentProbe(audioTime: clamped, outcome: .absent)
            }
            Log.info("""
                probe \(Int(clamped))s: transcript \(Int(match.time))s \
                offset \(String(format: "%+.1f", clamped - match.time)) votes \(match.votes)
                """)
            return AlignmentProbe(audioTime: clamped, outcome: .matched(match))
        }

        /// One retry, because a window that fails to transcribe would otherwise read as a gap.
        private func transcribeSlice(at time: Double, window: Double) async throws -> String? {
            for attempt in 0..<2 {
                let sliceUrl: URL
                do {
                    sliceUrl = try await reader.slice(at: time, length: window)
                } catch {
                    Log.warning("probe \(Int(time))s: slicing failed, \(error.localizedDescription)")
                    continue
                }
                defer { try? FileManager.default.removeItem(at: sliceUrl) }
                do {
                    return try await SpeechTranscriptService.probeText(fileUrl: sliceUrl, locale: locale)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    Log.warning("probe \(Int(time))s: attempt \(attempt) failed, \(error.localizedDescription)")
                }
            }
            return nil
        }

        /// Narrows down where one offset gives way to the next.
        ///
        /// Every probe feeds the same two bounds, so a window that happens not to transcribe can't
        /// strand the search on the wrong side of the edit. A window straddling the edge matches
        /// only its covered part, so its matched span pins the boundary tighter than bisection.
        func findBoundary(
            after before: (time: Double, offset: Double),
            before after: (time: Double, offset: Double)
        ) async throws -> Boundary {
            var lastBefore = before.time
            var beforeSpanEnd: Double?
            var firstAfter = after.time
            var afterSpanStart: Double?
            var insideGap: Double?

            func isBeforeSide(_ probe: AlignmentProbe) -> Bool {
                guard let offset = probe.offset else { return false }
                return abs(offset - before.offset) <= offsetTolerance
            }

            func isAfterSide(_ probe: AlignmentProbe) -> Bool {
                guard let offset = probe.offset else { return false }
                return abs(offset - after.offset) <= offsetTolerance
            }

            func consider(_ probe: AlignmentProbe) {
                if isBeforeSide(probe), probe.audioTime >= lastBefore {
                    lastBefore = probe.audioTime
                    beforeSpanEnd = probe.match?.spanEnd
                } else if isAfterSide(probe), probe.audioTime <= firstAfter {
                    firstAfter = probe.audioTime
                    afterSpanStart = probe.match?.spanStart
                } else if insideGap == nil, probe.isGapEvidence {
                    insideGap = probe.audioTime
                }
            }

            var steps = 0
            while firstAfter - lastBefore > boundaryPrecision,
                  steps < maximumBisectionSteps,
                  insideGap == nil {
                steps += 1
                let probe = try await probe(at: (lastBefore + firstAfter) / 2, window: fineWindow)
                if case .failed = probe.outcome { break }
                consider(probe)
            }

            if let insideGap {
                try await bisect(from: lastBefore, to: insideGap, advancingWhile: isBeforeSide,
                                 consider: consider)
                try await bisect(from: insideGap, to: firstAfter, advancingWhile: { !isAfterSide($0) },
                                 consider: consider)
            }

            let gapStart = min(beforeSpanEnd.map { $0 + before.offset } ?? lastBefore + fineWindow, firstAfter)
            let gapEnd = afterSpanStart.map { $0 + after.offset } ?? firstAfter
            return Boundary(gapStart: gapStart, gapEnd: max(gapStart, gapEnd), offsetAfter: after.offset)
        }

        /// Bisects `start..<end`, moving the lower bound up while `advancingWhile` holds.
        private func bisect(
            from start: Double,
            to end: Double,
            advancingWhile advance: (AlignmentProbe) -> Bool,
            consider: (AlignmentProbe) -> Void
        ) async throws {
            var low = start
            var high = end
            var steps = 0
            while high - low > boundaryPrecision, steps < maximumBisectionSteps {
                steps += 1
                let middle = (low + high) / 2
                let probe = try await probe(at: middle, window: fineWindow)
                if case .failed = probe.outcome { return }
                consider(probe)
                if advance(probe) {
                    low = middle
                } else {
                    high = middle
                }
            }
        }
    }
}
#endif
