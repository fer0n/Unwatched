//
//  WatchAudioPlayer.swift
//  UnwatchedWatch
//

import AVFoundation
import MediaPlayer
import Observation
import SwiftData
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

    /// Read once per item: `sortedChapterData` re-derives and re-sorts on every access.
    private(set) var chapters: [SendableChapter] = []

    /// How far the seek controls move in the current item. Resolved per item rather than per read:
    /// the tag lookup fetches, and the controls read this once a second while playing.
    private(set) var seekIntervals = WatchSeek.default

    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    /// Remaining stream URLs for the current video, in preference order.
    @ObservationIgnored private var candidates: [URL] = []
    @ObservationIgnored private var startSeconds: Double = 0
    /// The tag continuous play was last set from, see `applyTagContinuousPlay`.
    @ObservationIgnored private var continuousPlayTagId: PersistentIdentifier?

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
        chapters = video.sortedChapterData
        seekIntervals = WatchSeek(tagSeconds: Tag.seekSecondsTag(for: video)?.seekSeconds)
        applySeekIntervals()
        applyTagContinuousPlay(for: video)
        lastPersisted = 0
        lastReported = 0
        // What's playing heads the download window; moving on frees the one behind it.
        PodcastDownloadManager.shared.playingYoutubeId = video.youtubeId
        PodcastDownloadManager.shared.scheduleSync(planning: video.modelContext)
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
            persistProgress(force: true)
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

    /// The channel's or tag's own speed if there is one, otherwise this device's default speed. The default
    /// is a per-device setting: `UserDefaults` doesn't sync, so the phone's value doesn't apply here.
    var playbackSpeed: Double {
        _ = speedRevision
        if let custom = video?.customPlaybackSpeed, custom > 0 {
            return custom
        }
        let stored = UserDefaults.standard.double(forKey: Const.playbackSpeed)
        return stored > 0 ? stored : 1
    }

    /// Writes to whichever source is currently in effect, mirroring the phone: a channel or tag with its
    /// own speed keeps that override, everything else falls back to the shared per-device default.
    func setPlaybackSpeed(_ value: Double) {
        if video?.updateCustomPlaybackSpeed(value) != true {
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

    var currentChapterTitle: String? {
        chapters.last { $0.startTime <= currentTime }?.title
    }

    /// Where the current chapter ends, or the item.
    var currentEndTime: Double? {
        chapters.first { $0.startTime > currentTime }?.startTime ?? duration
    }

    var hasNextChapter: Bool {
        chapters.contains { $0.startTime > currentTime + Self.chapterSkipBack }
    }

    func goToNextChapter() {
        guard let next = chapters.first(where: { $0.startTime > currentTime + Self.chapterSkipBack }) else {
            return
        }
        seek(to: next.startTime)
    }

    func goToPreviousChapter() {
        let starts = chapters.map(\.startTime)
        guard let current = starts.last(where: { $0 <= currentTime }) else {
            seek(to: 0)
            return
        }
        if currentTime - current > Self.chapterSkipBack {
            seek(to: current)
        } else {
            seek(to: starts.last(where: { $0 < current }) ?? 0)
        }
    }

    private static let chapterSkipBack: Double = 3

    func seek(to seconds: Double) {
        guard let player else { return }
        let target = max(0, seconds)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        currentTime = target
        updateNowPlaying()
    }

    func seek(by seconds: Double) {
        guard let player else { return }
        let target = max(0, currentTime + seconds)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        currentTime = target
        updateNowPlaying()
    }

    func stop() {
        loadTask?.cancel()
        PodcastDownloadManager.shared.playingYoutubeId = nil
        candidates = []
        teardownPlayer()
        video = nil
        chapters = []
        seekIntervals = .default
        isPlaying = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    /// The next entry of the tag the wearer is looking at, so continuous play stays in the filter.
    @MainActor
    func nextInQueue(in context: ModelContext? = nil) -> Video? {
        guard let context = context ?? video?.modelContext else { return nil }
        let tags = (try? context.fetch(FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.order)]))) ?? []
        let name = UserDefaults.standard.string(forKey: Const.watchSelectedTagName) ?? ""
        let filter = QueueFilter(tag: tags.first { $0.name == name }, in: tags)
        let videos = ((try? context.fetch(filter.descriptor())) ?? []).compactMap(\.video)

        guard let current = video?.youtubeId else { return videos.first }
        guard let index = videos.firstIndex(where: { $0.youtubeId == current }) else {
            return videos.first
        }
        return index + 1 < videos.count ? videos[index + 1] : nil
    }

    /// Continuous play follows the tag, on the terms `PlayerManager` sets it on the phone: only
    /// where playback moves into a different tag than the one that last set it, so a manual flip
    /// stands for the rest of that tag.
    private func applyTagContinuousPlay(for video: Video) {
        guard let tag = Tag.continuousPlayTag(for: video),
              let continuousPlay = tag.continuousPlay else {
            continuousPlayTagId = nil
            return
        }
        guard tag.persistentModelID != continuousPlayTagId else { return }
        continuousPlayTagId = tag.persistentModelID
        UserDefaults.standard.set(continuousPlay, forKey: Const.continuousPlay)
    }

    /// Nothing here marks anything watched — that stays the phone's call.
    private func finish() {
        isPlaying = false
        guard UserDefaults.standard.bool(forKey: Const.continuousPlay),
              let next = nextInQueue() else { return }
        play(next)
    }

    private func teardownPlayer() {
        persistProgress(force: true)
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

    /// The position, for the phone to pick the item up where the wrist left it.
    func reportProgress() {
        persistProgress(force: true)
    }

    /// Every few seconds rather than every tick: each write dirties the context and may export.
    private func persistProgress(force: Bool = false) {
        guard let video, currentTime > 0 else { return }
        guard force || abs(currentTime - lastPersisted) >= Self.persistInterval else { return }
        lastPersisted = currentTime
        video.elapsedSeconds = currentTime

        guard force, currentTime != lastReported else { return }
        lastReported = currentTime
        WatchQueueClient.shared.report(.setProgress(youtubeId: video.youtubeId, seconds: currentTime))
    }

    @ObservationIgnored private var lastPersisted: Double = 0
    @ObservationIgnored private var lastReported: Double = 0
    private static let persistInterval: Double = 5

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
}
