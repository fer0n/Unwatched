//
//  WatchAudioPlayer.swift
//  UnwatchedWatch
//

import AVFoundation
import MediaPlayer
import Observation
import SwiftUI
import UnwatchedShared

/// Plays one video's audio at a time and keeps the queue position it came from.
///
/// Deliberately a plain `AVPlayer` rather than anything the phone app uses: there is no video layer,
/// no chapters, no silence trimming and no watch-history reporting here. What it does own is the
/// audio session and the Now Playing entry, which is what lets sound keep going once the wrist drops
/// and the screen sleeps.
@MainActor
@Observable
final class WatchAudioPlayer {
    private(set) var video: Video?
    private(set) var isPlaying = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// Seconds, mirrored from the player so views can observe them.
    private(set) var currentTime: Double = 0
    private(set) var duration: Double?

    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    /// Remaining stream URLs for the current video, in preference order.
    @ObservationIgnored private var candidates: [URL] = []
    @ObservationIgnored private var startSeconds: Double = 0

    init() {
        setupRemoteCommands()
    }

    #if DEBUG
    /// What the underlying player is actually doing, for the simulator probe in `DebugSeed`.
    var debugState: String {
        let item = player?.currentItem
        let status = switch item?.status {
        case .readyToPlay: "ready"
        case .failed: "failed"
        case .unknown: "unknown"
        default: "nil"
        }
        let waiting = player?.reasonForWaitingToPlay?.rawValue ?? "-"
        let error = item?.error?.localizedDescription ?? player?.error?.localizedDescription ?? "-"
        return "status=\(status) waiting=\(waiting) rate=\(player?.rate ?? -1) "
            + "empty=\(item?.isPlaybackBufferEmpty ?? false) likelyToKeepUp=\(item?.isPlaybackLikelyToKeepUp ?? false) "
            + "loaded=\(item?.loadedTimeRanges.first?.timeRangeValue.duration.seconds ?? -1) error=\(error)"
    }
    #endif

    // MARK: - Loading

    func play(_ video: Video) {
        guard video.persistentModelID != self.video?.persistentModelID else {
            togglePlay()
            return
        }

        loadTask?.cancel()
        teardownPlayer()

        self.video = video
        errorMessage = nil
        isLoading = true
        currentTime = video.elapsedSeconds ?? 0
        duration = video.duration

        loadTask = Task {
            do {
                let urls = try await WatchStreamResolver.streamCandidates(for: video)
                guard !Task.isCancelled else { return }
                candidates = urls
                startSeconds = video.elapsedSeconds ?? 0
                await playNextCandidate()
            } catch {
                guard !Task.isCancelled else { return }
                isLoading = false
                errorMessage = error.localizedDescription
                Log.error("watch playback failed: \(error)")
            }
        }
    }

    /// Starts the next candidate, or reports that none of them played.
    private func playNextCandidate() async {
        guard !candidates.isEmpty else {
            isLoading = false
            isPlaying = false
            errorMessage = WatchPlaybackError.noStream.localizedDescription
            Log.error("watch playback: no candidate stream played")
            return
        }
        await start(url: candidates.removeFirst(), at: startSeconds)
    }

    private func start(url: URL, at seconds: Double) async {
        // No route, no playback: an AVPlayer told to play without an active session simply sits
        // there, and the failure would show up as a silent, stuck progress bar.
        guard await activateSession() else {
            isLoading = false
            isPlaying = false
            return
        }

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        // Without this the watch pauses playback whenever the stream stalls for a moment on a weak
        // Wi-Fi link, which on a wrist is most of the time.
        player.automaticallyWaitsToMinimizeStalling = true
        self.player = player

        if seconds > 0 {
            // The completion handler is what picks the non-async overload; awaiting the seek would
            // hold playback back until an item that is not ready yet becomes seekable.
            player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600)) { _ in }
        }

        observe(player, item: item)
        Log.info("watch playback started at \(Int(seconds))s: \(url.host() ?? "?")")
        // `defaultRate` rather than plain `play()`: it also applies when the system's own
        // Now Playing controls resume playback, so the speed survives a pause.
        player.defaultRate = Float(playbackSpeed)
        player.play()
        isPlaying = true
        isLoading = false
        updateNowPlaying()
    }

    private func observe(_ player: AVPlayer, item: AVPlayerItem) {
        // A rejected CDN URL fails the item rather than erroring the player, and it does so within
        // a second or so — soon enough to move to the next candidate without the listener noticing.
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            Task { @MainActor [weak self] in
                guard let self, self.player?.currentItem === item else { return }
                Log.info("watch playback: candidate failed (\(item.error?.localizedDescription ?? "unknown"))")
                self.teardownPlayer()
                await self.playNextCandidate()
            }
        }

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.currentTime = time.seconds
                if let itemDuration = self.player?.currentItem?.duration.seconds,
                   itemDuration.isFinite, itemDuration > 0 {
                    self.duration = itemDuration
                }
                self.persistProgress()
                self.updateNowPlayingTime()
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.finish()
            }
        }
    }

    // MARK: - Transport

    func togglePlay() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            updateNowPlaying()
            return
        }
        // Resuming re-activates: the session is deactivated for us whenever something else takes
        // the route over, and the picker may need to come back up.
        isPlaying = true
        updateNowPlaying()
        Task {
            guard await activateSession() else {
                isPlaying = false
                updateNowPlaying()
                return
            }
            player.play()
        }
    }

    // MARK: - Speed

    /// Neither of the two places a speed lives -- `UserDefaults` and a SwiftData property on the
    /// subscription -- notifies Observation when it changes, so a view reading `playbackSpeed`
    /// would never redraw. Reading this in the getter and bumping it on every write is what makes
    /// the computed value publish.
    private var speedRevision = 0

    /// The channel's own speed if it has one, otherwise this device's default speed. The default
    /// is a per-device setting: `UserDefaults` doesn't sync, so the phone's value doesn't apply here.
    var playbackSpeed: Double {
        _ = speedRevision
        if let custom = video?.subscription?.customSpeedSetting, custom > 0 {
            return custom
        }
        let stored = UserDefaults.standard.double(forKey: Const.playbackSpeed)
        return stored > 0 ? stored : 1
    }

    /// Writes to whichever source is currently in effect, mirroring the phone: a channel with its
    /// own speed keeps that override, everything else falls back to the shared per-device default.
    func setPlaybackSpeed(_ value: Double) {
        if video?.subscription?.customSpeedSetting != nil {
            video?.subscription?.customSpeedSetting = value
        } else {
            UserDefaults.standard.set(value, forKey: Const.playbackSpeed)
        }
        speedRevision += 1
        applyPlaybackSpeed()
    }

    func setCustomSpeedEnabled(_ enabled: Bool) {
        guard let subscription = video?.subscription else { return }
        subscription.customSpeedSetting = enabled ? playbackSpeed : nil
        speedRevision += 1
        applyPlaybackSpeed()
    }

    private func applyPlaybackSpeed() {
        let rate = Float(playbackSpeed)
        player?.defaultRate = rate
        if isPlaying {
            player?.rate = rate
        }
        updateNowPlaying()
    }

    func seek(by seconds: Double) {
        guard let player else { return }
        let target = max(0, currentTime + seconds)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        currentTime = target
        updateNowPlayingTime()
    }

    func stop() {
        loadTask?.cancel()
        candidates = []
        persistProgress()
        teardownPlayer()
        video = nil
        isPlaying = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    /// Playback stops at the end of an episode rather than rolling into the next one: continuous
    /// play would mean deciding what "watched" means on a device that cannot undo it, which is the
    /// phone's job.
    private func finish() {
        isPlaying = false
    }

    private func teardownPlayer() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        statusObservation?.invalidate()
        statusObservation = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        player?.pause()
        player = nil
    }

    // MARK: - Progress

    /// Writes the position back to the store so the phone picks the episode up where the watch left
    /// it. CloudKit carries it over on its own schedule; nothing here waits for that.
    private func persistProgress() {
        guard let video, currentTime > 0 else { return }
        video.elapsedSeconds = currentTime
    }

    // MARK: - Audio session

    /// watchOS routes long-form audio itself — to whatever the wearer is listening on, or to the
    /// watch's own speaker — but only through `activate(options:)`. `setActive(true)` is documented
    /// as the wrong call under `.longFormAudio`: it skips the route picker the system puts up when
    /// it cannot choose an output on its own, and background audio is granted on the strength of
    /// that activation, so playing without it means silence as soon as the wrist drops.
    ///
    /// Activation is therefore also a point where the user can say no — by dismissing the picker —
    /// which is why this reports back rather than firing and forgetting.
    private func activateSession() async -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            // `.spokenAudio` is what makes AirPods' Conversation Awareness duck this rather than
            // pause it, and it is the right description of the content either way.
            try session.setCategory(.playback, mode: .spokenAudio, policy: .longFormAudio)
            return try await session.activate()
        } catch {
            Log.error("audio session failed: \(error)")
            errorMessage = String(localized: "watchNoAudioRoute")
            return false
        }
    }

    // MARK: - Now Playing

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isPlaying else { return .commandFailed }
                self.togglePlay()
                return .success
            }
        }
        center.pauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isPlaying else { return .commandFailed }
                self.togglePlay()
                return .success
            }
        }
        center.skipForwardCommand.preferredIntervals = [30]
        center.skipForwardCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                self?.seek(by: 30)
                return .success
            }
        }
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                self?.seek(by: -15)
                return .success
            }
        }
    }

    private func updateNowPlaying() {
        guard let video else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: video.title,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackSpeed : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime
        ]
        if let artist = video.subscription?.title {
            info[MPMediaItemPropertyArtist] = artist
        }
        if let duration {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingTime() {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackSpeed : 0.0
        if let duration {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
