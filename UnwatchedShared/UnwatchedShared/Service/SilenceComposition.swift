//
//  SilenceComposition.swift
//  UnwatchedShared
//

import AVFoundation
import OSLog

/// Translates between the episode's own timeline and the shortened one the player runs on.
public struct SilenceMap: Sendable, Equatable {
    /// A stretch of the file and the stretch of playback it turned into.
    struct Segment: Sendable, Equatable {
        var fileStart: Double
        var fileDuration: Double
        var playerStart: Double
        var playerDuration: Double

        var fileEnd: Double { fileStart + fileDuration }
        var playerEnd: Double { playerStart + playerDuration }
    }

    private let segments: [Segment]
    public let fileDuration: Double
    public let playerDuration: Double

    init?(track: AVCompositionTrack) {
        var segments: [Segment] = []
        for segment in track.segments where !segment.isEmpty {
            let mapping = segment.timeMapping
            guard mapping.source.duration.seconds > 0, mapping.target.duration.seconds > 0 else { continue }
            segments.append(Segment(
                fileStart: mapping.source.start.seconds,
                fileDuration: mapping.source.duration.seconds,
                playerStart: mapping.target.start.seconds,
                playerDuration: mapping.target.duration.seconds
            ))
        }
        guard let last = segments.last else { return nil }
        self.segments = segments
        fileDuration = last.fileEnd
        playerDuration = last.playerEnd
    }

    /// Where `playerTime` is in the episode.
    public func fileTime(_ playerTime: Double) -> Double {
        guard playerTime.isFinite, let first = segments.first, let last = segments.last else {
            return playerTime
        }
        let clamped = min(max(playerTime, first.playerStart), last.playerEnd)
        guard let segment = segment(containing: clamped, inPlayerTime: true) else {
            return last.fileEnd
        }
        let progress = (clamped - segment.playerStart) / segment.playerDuration
        return segment.fileStart + progress * segment.fileDuration
    }

    /// Where `fileTime` lands once the pauses before it have been shortened.
    public func playerTime(_ fileTime: Double) -> Double {
        guard fileTime.isFinite, let first = segments.first, let last = segments.last else {
            return fileTime
        }
        let clamped = min(max(fileTime, first.fileStart), last.fileEnd)
        guard let segment = segment(containing: clamped, inPlayerTime: false) else {
            return last.playerEnd
        }
        let progress = (clamped - segment.fileStart) / segment.fileDuration
        return segment.playerStart + progress * segment.playerDuration
    }

    /// The segment `time` falls in.
    private func segment(containing time: Double, inPlayerTime: Bool) -> Segment? {
        var low = 0
        var high = segments.count - 1
        while low <= high {
            let middle = (low + high) / 2
            let segment = segments[middle]
            let start = inPlayerTime ? segment.playerStart : segment.fileStart
            let end = inPlayerTime ? segment.playerEnd : segment.fileEnd
            if time < start {
                high = middle - 1
            } else if time >= end {
                low = middle + 1
            } else {
                return segment
            }
        }
        return nil
    }
}

/// Builds the item a trimmed episode plays from.
public enum SilenceComposition {
    /// The composition and the map from it, or nil when the file can't be composed.
    public static func make(
        url: URL, scan: SilenceScan, tier: TrimSilenceTier = .medium
    ) async -> (AVMutableComposition, SilenceMap)? {
        let guardBand = tier.settings.guardBand
        let asset = AVURLAsset(url: url)
        do {
            guard let source = try await asset.loadTracks(withMediaType: .audio).first else {
                return nil
            }
            let duration = try await asset.load(.duration)
            let composition = AVMutableComposition()
            guard let track = composition.addMutableTrack(
                withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                return nil
            }
            try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: source, at: .zero)

            // back to front: scaling a range moves everything after it, but nothing before it
            for pause in scan.pauses.sorted(by: { $0.start > $1.start }) {
                // `scan.pauses` was filtered at the most permissive tier (see `SilenceScanner .scan`); a milder tier
                // still has to skip what it wouldn't itself trim.
                guard SilenceScan.isWorthTrimming(pause, tier: tier) else { continue }
                let interior = pause.duration - 2 * guardBand
                let target = SilenceScan.playedLength(of: pause.duration, tier: tier) - 2 * guardBand
                guard interior > 0, target > 0, target < interior else { continue }
                track.scaleTimeRange(
                    CMTimeRange(
                        start: CMTime(seconds: pause.start + guardBand, preferredTimescale: Const.silenceTimescale),
                        duration: CMTime(seconds: interior, preferredTimescale: Const.silenceTimescale)
                    ),
                    toDuration: CMTime(seconds: target, preferredTimescale: Const.silenceTimescale)
                )
            }

            guard let map = SilenceMap(track: track) else { return nil }
            Log.info("""
                silence composition: \(Int(map.fileDuration))s plays in \(Int(map.playerDuration))s \
                (\(scan.pauses.count) pauses)
                """)
            return (composition, map)
        } catch {
            Log.error("silence composition failed: \(error.localizedDescription)")
            return nil
        }
    }
}
