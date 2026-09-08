//
//  PodcastAudioEngine.swift
//  UnwatchedShared
//

import AVFoundation
import OSLog

// No `AVSampleBufferAudioRenderer` on watchOS; the watch plays its own downloads.
#if !os(watchOS)

/// Plays a downloaded episode with its pauses dropped, on the episode's own clock.
public final class PodcastAudioEngine: @unchecked Sendable {
    private struct Piece {
        let output: AVAudioFramePosition
        let fileStart: AVAudioFramePosition
        let frames: AVAudioFrameCount

        var outputEnd: AVAudioFramePosition { output + AVAudioFramePosition(frames) }
    }

    private static let readChunk: Double = 1
    /// Audio landing behind the playhead is never heard, so a recovery starts ahead of it.
    private static let flushLead: Double = 0.1

    private let renderer = AVSampleBufferAudioRenderer()
    private let synchronizer = AVSampleBufferRenderSynchronizer()
    private let queue = DispatchQueue(label: Const.bundleId + ".podcastAudioEngine")

    private var file: AVAudioFile?
    private var remover: SilenceRemover?
    private var readBuffer: AVAudioPCMBuffer?
    private var outputFormat: AVAudioFormat?
    private var interleaver: AVAudioConverter?
    private var formatDescription: CMAudioFormatDescription?
    private var flushObserver: NSObjectProtocol?
    private var endObserver: Any?

    /// Guards what a caller reads off its own thread; everything else is serialized on `queue`.
    private let lock = NSLock()
    private var pieces: [Piece] = []
    private var scheduledOutput: AVAudioFramePosition = 0
    private var startFileFrame: AVAudioFramePosition = 0
    private var pendingSeek: AVAudioFramePosition?
    private var seekToken = 0
    private var endOutput: AVAudioFramePosition?
    private var generation = 0
    private var sampleRate: Double = 44_100
    private var length: AVAudioFramePosition = 0

    private var rate: Double = 1
    private var wantsPlayback = false
    private var loaded = false

    public var onEnded: (@Sendable () -> Void)?

    public init() {
        renderer.audioTimePitchAlgorithm = .timeDomain
        synchronizer.addRenderer(renderer)
    }

    deinit {
        // undefined behavior without this
        renderer.stopRequestingMediaData()
        if let flushObserver {
            NotificationCenter.default.removeObserver(flushObserver)
        }
        if let endObserver {
            synchronizer.removeTimeObserver(endObserver)
        }
    }

    // MARK: - Loading

    /// Throws when the file won't decode: the caller's signal to fall back to ordinary playback.
    public func load(url: URL, tier: TrimSilenceTier, startAt: Double) throws {
        try queue.sync {
            teardown()
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            guard format.channelCount > 0, file.length > 0 else {
                throw PodcastAudioEngineError.emptyFile
            }
            guard let output = Self.rendererFormat(for: format),
                  let description = Self.formatDescription(of: output) else {
                throw PodcastAudioEngineError.unsupportedFormat
            }
            self.file = file
            outputFormat = output
            interleaver = AVAudioConverter(from: format, to: output)
            formatDescription = description
            readBuffer = AVAudioPCMBuffer(
                pcmFormat: format, frameCapacity: AVAudioFrameCount(format.sampleRate * Self.readChunk)
            )
            lock.withLock {
                sampleRate = format.sampleRate
                length = file.length
                loaded = true
            }
            observeFlushes()
            let frame = clampedFrame(startAt)
            file.framePosition = frame
            remover = SilenceRemover(format: format, tier: tier, startingAt: frame)
            move(to: frame, playingFrom: nil)
            Log.info("podcast engine: \(Int(self.duration))s at \(Int(format.sampleRate))Hz, from \(Int(startAt))s")
        }
    }

    public func unload() {
        queue.sync { teardown() }
    }

    // MARK: - Transport

    // The transport takes a rate from any thread, so it never waits on `queue` behind a `flush()`.
    public func play(rate: Double) {
        let rate = clamped(rate)
        let ready = lock.withLock { () -> Bool in
            guard loaded else { return false }
            wantsPlayback = true
            self.rate = rate
            return true
        }
        guard ready else { return }
        synchronizer.rate = Float(rate)
    }

    public func pause() {
        guard lock.withLock({ wantsPlayback = false; return loaded }) else { return }
        synchronizer.rate = 0
    }

    public var isPlaying: Bool {
        synchronizer.rate != 0
    }

    /// On `queue` so it is ordered against the flush a rate change causes.
    public func setRate(_ rate: Double) {
        let rate = clamped(rate)
        queue.async {
            guard self.lock.withLock({ self.rate = rate; return self.wantsPlayback }) else { return }
            self.synchronizer.rate = Float(rate)
        }
    }

    /// What `timeDomain` will play.
    private func clamped(_ rate: Double) -> Double {
        Swift.max(1 / 32, Swift.min(32, rate))
    }

    /// The position moves before this returns; the renderer hears about it on `queue`, where
    /// `flush()` can block for 60ms and a scrub's worth of seeks collapses to one.
    public func seek(to seconds: Double) {
        let frame = clampedFrame(seconds)
        let token = lock.withLock {
            pendingSeek = frame
            seekToken += 1
            return seekToken
        }
        queue.async { [weak self] in
            guard let self else { return }
            defer { self.lock.withLock { if self.seekToken == token { self.pendingSeek = nil } } }
            guard self.lock.withLock({ self.seekToken == token }),
                  let file = self.file, let remover = self.remover else {
                return
            }
            file.framePosition = frame
            remover.reset(startingAt: frame)
            self.move(to: frame, playingFrom: nil)
        }
    }

    // MARK: - Clocks

    public var duration: Double {
        lock.withLock { sampleRate > 0 ? Double(length) / sampleRate : 0 }
    }

    public var currentTime: Double {
        let played = playedFrames
        return lock.withLock {
            guard sampleRate > 0 else { return 0 }
            if let pendingSeek { return Double(pendingSeek) / sampleRate }
            guard let piece = pieces.last(where: { $0.output <= played }) else {
                return Double(startFileFrame) / sampleRate
            }
            let into = min(AVAudioFramePosition(piece.frames), played - piece.output)
            return Double(piece.fileStart + into) / sampleRate
        }
    }

    /// Audio actually rendered since the last seek.
    public var playedTime: Double {
        let seconds = synchronizer.currentTime().seconds
        return seconds.isFinite ? Swift.max(0, seconds) : 0
    }

    private var playedFrames: AVAudioFramePosition {
        let seconds = playedTime
        return lock.withLock { AVAudioFramePosition((seconds * sampleRate).rounded()) }
    }

    // MARK: - Feeding

    private func feed() {
        guard let file, let remover, let readBuffer, let formatDescription else { return }
        let generation = lock.withLock { self.generation }
        while renderer.isReadyForMoreMediaData {
            guard lock.withLock({ endOutput == nil }) else { return }
            // reading past the end throws rather than returning nothing
            if file.framePosition < file.length {
                do {
                    try file.read(into: readBuffer, frameCount: readBuffer.frameCapacity)
                } catch {
                    Log.error("podcast engine: read failed — \(error.localizedDescription)")
                    readBuffer.frameLength = 0
                }
            } else {
                readBuffer.frameLength = 0
            }
            let ended = readBuffer.frameLength == 0
            for chunk in ended ? remover.finish() : remover.process(readBuffer) {
                enqueue(chunk, formatDescription: formatDescription)
            }
            if ended {
                endAfterWhatIsEnqueued(generation: generation)
                return
            }
        }
        prunePieces()
    }

    private func enqueue(_ chunk: TrimmedChunk, formatDescription: CMAudioFormatDescription) {
        let (start, rate) = lock.withLock { (scheduledOutput, sampleRate) }
        guard let interleaved = interleaved(chunk.buffer), let sample = Self.sampleBuffer(
            interleaved, at: CMTime(value: start, timescale: CMTimeScale(rate.rounded())),
            formatDescription: formatDescription
        ) else {
            Log.error("podcast engine: a chunk could not be wrapped for the renderer")
            return
        }
        lock.withLock {
            pieces.append(Piece(output: start, fileStart: chunk.fileStart, frames: chunk.frameLength))
            scheduledOutput += AVAudioFramePosition(chunk.frameLength)
        }
        renderer.enqueue(sample)
    }

    private func interleaved(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let interleaver, let format = outputFormat,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: source.frameLength) else {
            return nil
        }
        do {
            try interleaver.convert(to: buffer, from: source)
        } catch {
            Log.error("podcast engine: interleaving failed — \(error.localizedDescription)")
            return nil
        }
        return buffer
    }

    /// The renderer says nothing when it runs out, so the end is a point on the timeline.
    private func endAfterWhatIsEnqueued(generation: Int) {
        renderer.stopRequestingMediaData()
        let (end, rate) = lock.withLock { (scheduledOutput, sampleRate) }
        lock.withLock { endOutput = end }
        let time = CMTime(value: end, timescale: CMTimeScale(rate.rounded()))
        guard synchronizer.currentTime() < time else {
            finishNow(generation: generation)
            return
        }
        endObserver = synchronizer.addBoundaryTimeObserver(
            forTimes: [NSValue(time: time)], queue: queue
        ) { [weak self] in
            self?.finishNow(generation: generation)
        }
    }

    private func finishNow(generation: Int) {
        guard lock.withLock({ self.generation == generation }) else { return }
        lock.withLock { wantsPlayback = false }
        synchronizer.rate = 0
        removeEndObserver()
        let ended = onEnded
        DispatchQueue.main.async { ended?() }
    }

    private func prunePieces() {
        let played = playedFrames
        lock.withLock {
            if let index = pieces.lastIndex(where: { $0.outputEnd <= played }), index > 0 {
                pieces.removeFirst(index)
            }
        }
    }

    // MARK: - Position

    /// `playingFrom` is nil for a fresh timeline at zero, or a point on the running one after a
    /// flush. Only ever called on `queue`.
    private func move(to frame: AVAudioFramePosition, playingFrom output: AVAudioFramePosition?) {
        renderer.stopRequestingMediaData()
        renderer.flush()
        removeEndObserver()
        lock.withLock {
            generation += 1
            pieces.removeAll(keepingCapacity: true)
            scheduledOutput = output ?? 0
            startFileFrame = frame
            endOutput = nil
        }
        if output == nil {
            let (playing, rate) = lock.withLock { (wantsPlayback, self.rate) }
            synchronizer.setRate(Float(playing ? rate : 0), time: .zero)
        }
        // re-arming is what starts the reading: the renderer calls this straight back while it wants data
        renderer.requestMediaDataWhenReady(on: queue) { [weak self] in self?.feed() }
    }

    /// A route or rate change empties the renderer while its timeline keeps running.
    private func recoverFromFlush() {
        guard let file, let remover else { return }
        let (rate, lead) = lock.withLock { (sampleRate, AVAudioFramePosition(sampleRate * Self.flushLead)) }
        let output = playedFrames + lead
        let episode = fileFrame(atOutput: output)
        Log.info("podcast engine: renderer flushed, resuming at \(Int(Double(episode) / max(rate, 1)))s")
        file.framePosition = min(episode, lock.withLock { length })
        remover.reset(startingAt: episode)
        move(to: episode, playingFrom: output)
    }

    private func fileFrame(atOutput output: AVAudioFramePosition) -> AVAudioFramePosition {
        lock.withLock {
            guard let piece = pieces.last(where: { $0.output <= output }) else { return startFileFrame }
            return piece.fileStart + min(AVAudioFramePosition(piece.frames), output - piece.output)
        }
    }

    private func clampedFrame(_ seconds: Double) -> AVAudioFramePosition {
        let (rate, length) = lock.withLock { (sampleRate, self.length) }
        guard seconds.isFinite, seconds > 0 else { return 0 }
        return min(length, AVAudioFramePosition(seconds * rate))
    }

    // MARK: - Teardown

    private func observeFlushes() {
        guard flushObserver == nil else { return }
        flushObserver = NotificationCenter.default.addObserver(
            forName: .AVSampleBufferAudioRendererWasFlushedAutomatically, object: renderer, queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            queue.async { self.recoverFromFlush() }
        }
    }

    private func removeEndObserver() {
        guard let endObserver else { return }
        synchronizer.removeTimeObserver(endObserver)
        self.endObserver = nil
    }

    private func teardown() {
        renderer.stopRequestingMediaData()
        synchronizer.rate = 0
        renderer.flush()
        removeEndObserver()
        if let flushObserver {
            NotificationCenter.default.removeObserver(flushObserver)
            self.flushObserver = nil
        }
        file = nil
        remover = nil
        readBuffer = nil
        outputFormat = nil
        interleaver = nil
        formatDescription = nil
        lock.withLock {
            wantsPlayback = false
            rate = 1
            loaded = false
            generation += 1
            seekToken += 1
            pendingSeek = nil
            pieces.removeAll()
            scheduledOutput = 0
            startFileFrame = 0
            endOutput = nil
            length = 0
        }
    }
}

public enum PodcastAudioEngineError: Error {
    case emptyFile
    case unsupportedFormat
}
#endif
