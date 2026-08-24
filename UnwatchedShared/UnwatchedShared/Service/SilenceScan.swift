//
//  SilenceScan.swift
//  UnwatchedShared
//

import AVFoundation
import OSLog

/// A pause found in an episode, in the file's own timeline.
public struct SilencePause: Codable, Sendable, Equatable {
    public var start: Double
    public var duration: Double

    public var end: Double { start + duration }

    public init(start: Double, duration: Double) {
        self.start = start
        self.duration = duration
    }
}

/// What a scan of one episode found. This is what's kept on disk next to the download.
public struct SilenceScan: Codable, Sendable, Equatable {
    public var fileDuration: Double
    public var pauses: [SilencePause]
    /// The level the pauses were cut at, in dBFS — logged, and what a re-scan would be compared to.
    public var threshold: Double
    /// What `pauses` was filtered against when it was written (see `Const.silenceScanVersion`).
    public var version: Int

    public init(
        fileDuration: Double,
        pauses: [SilencePause],
        threshold: Double,
        version: Int = Const.silenceScanVersion
    ) {
        self.fileDuration = fileDuration
        self.pauses = pauses
        self.threshold = threshold
        self.version = version
    }

    /// How much shorter the episode plays once every pause worth trimming at `tier` is shortened.
    public func saving(tier: TrimSilenceTier = .medium) -> Double {
        pauses.reduce(0) { total, pause in
            guard SilenceScan.isWorthTrimming(pause, tier: tier) else { return total }
            return total + (pause.duration - SilenceScan.playedLength(of: pause.duration, tier: tier))
        }
    }

    /// What a pause of `duration` is allowed to shrink to.
    public static func playedLength(of duration: Double, tier: TrimSilenceTier = .medium) -> Double {
        let settings = tier.settings
        let target = max(settings.targetPause, duration * settings.keepFraction)
        return max(2 * settings.guardBand + Const.silenceMinimumInterior, min(duration, target))
    }

    /// Whether shortening this pause buys enough to be worth a scaled segment in the composition.
    public static func isWorthTrimming(_ pause: SilencePause, tier: TrimSilenceTier = .medium) -> Bool {
        guard pause.duration >= tier.settings.minimumPause else { return false }
        return pause.duration - playedLength(of: pause.duration, tier: tier) >= tier.settings.minimumSaving
    }
}

/// Reads a downloaded episode once and reports where its pauses are.
public enum SilenceScanner {
    /// Mono, and downsampled: RMS over a 16 kHz window says exactly what it says over 44.1 kHz, for a third of the
    /// samples.
    private static let sampleRate: Double = 16_000
    private static let windowFrames = 256

    /// Lowest level the histogram distinguishes.
    private static let floorDb: Double = -80

    public static func scan(url: URL) async throws -> SilenceScan {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw SilenceScanError.noAudioTrack
        }
        let levels = try levelsPerWindow(asset: asset, track: track)
        guard !levels.isEmpty else {
            throw SilenceScanError.noAudioTrack
        }

        let threshold = silenceThreshold(levels)
        let windowSeconds = Double(windowFrames) / sampleRate
        // Kept against the most permissive tier, not whichever is selected right now: a tier
        // switch later only rebuilds the composition from this same list (see `SilenceComposition
        // .make`), so anything a stricter tier might ever want has to survive this filter. This is
        // also the only place a tier's `minimumPause` costs anything — the shortest one reaches
        // further down into the gaps between words, so the list is longer than it used to be.
        let pauses = runs(below: threshold, in: levels, windowSeconds: windowSeconds)
            .filter { SilenceScan.isWorthTrimming($0, tier: .mostPermissive) }

        let duration = try await asset.load(.duration).seconds
        let scan = SilenceScan(fileDuration: duration, pauses: pauses, threshold: threshold)
        Log.info("""
            silence scan: \(pauses.count) pauses in \(Int(duration))s at \
            \(String(format: "%.0f", threshold)) dBFS, saving \(Int(scan.saving(tier: .mostPermissive)))s
            """)
        return scan
    }

    /// RMS of every window of the file, in dBFS.
    private static func levelsPerWindow(asset: AVAsset, track: AVAssetTrack) throws -> [Double] {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1
        ])
        output.alwaysCopiesSampleData = false
        reader.add(output)
        guard reader.startReading() else {
            throw reader.error ?? SilenceScanError.noAudioTrack
        }

        var levels: [Double] = []
        levels.reserveCapacity(4096)
        var sum: Float = 0
        var count = 0

        while let sample = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(sample) else { continue }
            var length = 0
            var pointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(
                block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &pointer
            )
            guard let pointer else { continue }
            pointer.withMemoryRebound(to: Float.self, capacity: length / MemoryLayout<Float>.size) { samples in
                for index in 0..<(length / MemoryLayout<Float>.size) {
                    let value = samples[index]
                    sum += value * value
                    count += 1
                    if count == windowFrames {
                        levels.append(decibels(sum / Float(windowFrames)))
                        sum = 0
                        count = 0
                    }
                }
            }
        }
        if reader.status == .failed {
            throw reader.error ?? SilenceScanError.noAudioTrack
        }
        return levels
    }

    private static func decibels(_ meanSquare: Float) -> Double {
        guard meanSquare > 0 else { return floorDb }
        return max(floorDb, 10 * log10(Double(meanSquare)))
    }

    /// Where to cut, found from the episode's own level distribution rather than fixed.
    static func silenceThreshold(_ levels: [Double]) -> Double {
        let bins = 160
        let binWidth = -floorDb / Double(bins)
        var histogram = [Int](repeating: 0, count: bins)
        for level in levels {
            let bin = min(bins - 1, max(0, Int((level - floorDb) / binWidth)))
            histogram[bin] += 1
        }

        let total = Double(levels.count)
        let weightedTotal = (0..<bins).reduce(0.0) { $0 + Double($1) * Double(histogram[$1]) }
        var belowCount = 0.0
        var belowWeighted = 0.0
        var bestVariance = -1.0
        var bestBin = 0

        for bin in 0..<bins {
            belowCount += Double(histogram[bin])
            guard belowCount > 0, belowCount < total else { continue }
            belowWeighted += Double(bin) * Double(histogram[bin])
            let aboveCount = total - belowCount
            let belowMean = belowWeighted / belowCount
            let aboveMean = (weightedTotal - belowWeighted) / aboveCount
            let variance = belowCount * aboveCount * (belowMean - aboveMean) * (belowMean - aboveMean)
            if variance > bestVariance {
                bestVariance = variance
                bestBin = bin
            }
        }

        let threshold = floorDb + (Double(bestBin) + 1) * binWidth
        return min(Const.silenceThresholdCeilingDb, max(Const.silenceThresholdFloorDb, threshold))
    }

    private static func runs(below threshold: Double, in levels: [Double], windowSeconds: Double) -> [SilencePause] {
        var pauses: [SilencePause] = []
        var runStart: Int?
        for (index, level) in levels.enumerated() {
            if level < threshold {
                if runStart == nil { runStart = index }
            } else if let start = runStart {
                pauses.append(SilencePause(
                    start: Double(start) * windowSeconds,
                    duration: Double(index - start) * windowSeconds
                ))
                runStart = nil
            }
        }
        // a run reaching the end of the file is left off: there is nothing after it to come back to
        return pauses
    }
}

public enum SilenceScanError: Error {
    case noAudioTrack
}
