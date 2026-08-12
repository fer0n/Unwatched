//
//  TvPlayerViewModel.swift
//  UnwatchedTV
//

import AVFoundation
import AVKit
import SwiftData
import SwiftUI
import UnwatchedShared

/// Drives in-app playback of a single video: resolves its stream, restores the watch position
/// and writes progress back to the queue while it plays.
@MainActor
@Observable
final class TvPlayerViewModel {
    enum State: Equatable {
        case loading
        case playing
        /// Played to the end; the end overlay takes over and the viewer decides what happens next.
        case ended
        case failed(String)
    }

    private(set) var state: State = .loading
    let player = AVPlayer()

    private let video: Video
    private let modelContext: ModelContext
    /// Last position written to the video; keeps writes down to one per
    /// `Const.updateTimeMinimum` seconds instead of one per tick.
    private var savedTime: Double = 0
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?

    init(video: Video, modelContext: ModelContext) {
        self.video = video
        self.modelContext = modelContext
    }

    func start() async {
        do {
            let url = try await TvStreamResolver.streamURL(for: video.youtubeId)
            guard !Task.isCancelled else { return }
            play(AVPlayerItem(url: url))
        } catch {
            Log.error("Playback failed for \(video.youtubeId): \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
        }
    }

    /// Stops playback and stores where the viewer left off. Called when the player goes away,
    /// however it goes away.
    func stop() {
        // A video that ran to the end has no position left to remember — saving here would
        // put the last frame back as its resume point.
        if state != .ended {
            saveProgress()
        }
        player.pause()
        player.replaceCurrentItem(with: nil)
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil
    }

    func markWatched() {
        VideoService.setVideoWatched(video, modelContext: modelContext)
    }

    // MARK: - Playback

    private func play(_ item: AVPlayerItem) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        item.externalMetadata = [titleMetadata()]
        item.navigationMarkerGroups = TvChapters.markerGroups(for: video)
        player.replaceCurrentItem(with: item)
        // `defaultRate` rather than `rate`: it also applies when the system player's own play
        // button resumes playback, so the speed survives a pause.
        player.defaultRate = Float(playbackSpeed)
        observeStatus(of: item)
        observeEnd(of: item)
        observeTime()

        // Watching a finished video again starts over rather than sitting on the last frame.
        if let elapsed = video.elapsedSeconds, elapsed > 0, video.hasFinished != true {
            savedTime = elapsed
            player.seek(to: CMTime(seconds: elapsed, preferredTimescale: 1000))
        }
        player.play()
    }

    /// The stream URL can resolve and still not play — the CDN rejects it, or the manifest has
    /// gone stale. The player view stays on the spinner until the item is actually ready, so a
    /// stream that never starts ends up on the error screen instead of a black rectangle.
    private func observeStatus(of item: AVPlayerItem) {
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            let status = item.status
            let message = item.error?.localizedDescription
            Task { @MainActor [weak self] in
                self?.handleStatusChange(status, message: message)
            }
        }
    }

    private func handleStatusChange(_ status: AVPlayerItem.Status, message: String?) {
        switch status {
        case .readyToPlay:
            if state == .loading {
                state = .playing
            }
        case .failed:
            Log.error("Playback failed for \(video.youtubeId): \(message ?? "unknown reason")")
            state = .failed(message ?? String(localized: "videoNoStream"))
        default:
            break
        }
    }

    /// The channel's own speed if it has one, otherwise this device's default speed. The default
    /// is a per-device setting: UserDefaults doesn't sync, so the iPhone's value doesn't apply here.
    var playbackSpeed: Double {
        if let custom = video.subscription?.customSpeedSetting, custom > 0 {
            return custom
        }
        let stored = UserDefaults.standard.double(forKey: Const.playbackSpeed)
        return stored > 0 ? stored : 1
    }

    /// Title for the system player's info panel.
    private func titleMetadata() -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = .commonIdentifierTitle
        item.value = video.title as NSString
        item.extendedLanguageTag = "und"
        return item
    }

    private func observeTime() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            let seconds = time.seconds
            guard seconds.isFinite else { return }
            Task { @MainActor [weak self] in
                self?.handleTimeUpdate(seconds)
            }
        }
    }

    private func handleTimeUpdate(_ seconds: Double) {
        backfillDuration()
        guard abs(seconds - savedTime) >= Const.updateTimeMinimum else { return }
        savedTime = seconds
        video.elapsedSeconds = seconds
        try? modelContext.save()
    }

    /// Videos synced from an iOS device that never played them have no duration, which leaves
    /// the queue thumbnail without a progress bar. The player knows it, so fill it in.
    private func backfillDuration() {
        guard video.duration == nil,
              let duration = player.currentItem?.duration.seconds,
              duration.isFinite, duration > 0 else { return }
        video.duration = duration
    }

    private func saveProgress() {
        let seconds = player.currentTime().seconds
        guard seconds.isFinite, seconds > 0 else { return }
        video.elapsedSeconds = seconds
        try? modelContext.save()
    }

    private func observeEnd(of item: AVPlayerItem) {
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handlePlaybackEnded()
            }
        }
    }

    /// The viewer decides what happens to a finished video (watched, restart, close), so the only
    /// thing settled here is the watch position: a video that ran to the end has none left.
    private func handlePlaybackEnded() {
        player.pause()
        savedTime = 0
        video.elapsedSeconds = nil
        try? modelContext.save()
        state = .ended
    }

    /// Plays the finished video again from the start.
    func restart() {
        savedTime = 0
        state = .playing
        player.seek(to: .zero)
        player.play()
    }
}
