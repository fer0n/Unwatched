//
//  PlayerManager+Playback.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

// PlayerManager+Playback
extension PlayerManager {

    @MainActor
    func handleAutoStart() {
        Log.info("handleAutoStart")
        isLoading = false

        guard let source = videoSource else {
            Log.info("no source, stopping")
            return
        }
        Log.info("source: \(String(describing: source))")
        switch source {
        case .continuousPlay:
            let continuousPlay = UserDefaults.standard.bool(forKey: Const.continuousPlay)
            if continuousPlay {
                play()
            }
        case .nextUp:
            break
        case .userInteraction:
            play()
        case .playWhenReady:
            previousState.isPlaying = false
            play()
        case .hotSwap, .errorSwap:
            if previousIsPlaying {
                play()
            }
        @unknown default:
            break
        }
        videoSource = nil
    }

    @MainActor
    func updateElapsedTime(_ time: Double? = nil, videoId: String? = nil) {
        if videoId != nil && videoId != video?.youtubeId {
            // avoid updating the wrong video
            Log.info("updateElapsedTime: wrong video to update")
            return
        }
        Log.info("updateElapsedTime")

        let newTime = time ?? currentTime

        guard let time = newTime,
              video?.elapsedSeconds != time,
              let modelId = video?.persistentModelID else {
            Log.info("updateElapsedTime: no change")
            return
        }

        video?.elapsedSeconds = time
        _ = VideoService.forceUpdateVideo(modelId, elapsedSeconds: time)
    }

    @MainActor
    var currentRemaining: Double? {
        if let end = currentEndTime ?? video?.duration,
           let current = currentTime {
            return max(end - current, 0)
        }
        return nil
    }

    @MainActor
    var currentRemainingText: String? {
        currentRemaining?.formatTimeMinimal
    }

    @MainActor
    func playVideo(_ video: Video) {
        self.videoSource = .userInteraction
        if self.video?.youtubeId != video.youtubeId {
            self.video = video
        } else {
            Log.info("playVideo: video already playing")
            play()
        }
    }

    @MainActor
    func play() {
        if self.isLoading {
            self.videoSource = .playWhenReady
        }
        if !self.isPlaying {
            self.isPlaying = true
        }
        updateVideoEnded()
        handleRotateOnPlay()
        handlePreciseChapterChangePlay()
    }

    @MainActor
    func pause() {
        if self.isPlaying {
            self.isPlaying = false
        }
        updateVideoEnded()
        changeChapterTask?.cancel()
    }

    /// Restarts, pauses or plays the current video
    @MainActor
    func handlePlayButton() {
        if videoEnded {
            restartVideo()
        } else if isPlaying {
            pause()
        } else {
            play()
        }
    }

    @MainActor
    func restartVideo() {
        seek(to: 0)
        play()
    }

    @MainActor
    func seekForward(_ seconds: Double? = nil) -> Bool {
        seek(backward: false, seconds ?? Const.seekSeconds)
    }

    @MainActor
    func seekBackward(_ seconds: Double? = nil) -> Bool {
        seek(backward: true, seconds ?? Const.seekSeconds)
    }

    @MainActor
    func seek(backward: Bool, _ seconds: Double) -> Bool {
        if video != nil {
            let seek = backward ? -seconds : seconds
            seekRelative = seek
            if !isPlaying {
                currentTime? += seek
            }
            return true
        }
        return false
    }

    @MainActor
    func seek(to time: CGFloat) {
        if let duration = video?.duration, time >= duration {
            seekAbsolute = duration - Const.seekToEndBuffer
        } else {
            seekAbsolute = time
        }
        updateElapsedTime(time, videoId: video?.youtubeId)
    }

    @MainActor
    var playbackSpeed: Double {
        get {
            temporaryPlaybackSpeed ?? unmodifiedPlaybackSpeed
        }
        set {
            setPlaybackSpeed(newValue)
        }
    }

    @MainActor
    var debouncedPlaybackSpeed: Double {
        get {
            _debouncedPlaybackSpeed ?? playbackSpeed
        }
        set {
            setPlaybackSpeed(newValue)
        }
    }

    @MainActor
    func setPlaybackSpeedDebounced(_ value: Double) {
        if temporaryPlaybackSpeed != nil {
            return
        }
        _debouncedPlaybackSpeed = value
        playbackSpeedTask?.cancel()
        playbackSpeedTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(400))
                setPlaybackSpeed(value)
                _debouncedPlaybackSpeed = nil
            } catch { }
        }
    }

    @MainActor
    var unmodifiedPlaybackSpeed: Double {
        video?.subscription?.customSpeedSetting ?? defaultPlaybackSpeed
    }

    @MainActor
    var temporarySlowDownThreshold: Bool {
        unmodifiedPlaybackSpeed >= Const.temporarySpeedSwap
    }

    @MainActor
    func setTemporaryPlaybackSpeed() {
        if temporarySlowDownThreshold {
            temporaryPlaybackSpeed = 1
        } else {
            temporaryPlaybackSpeed = Const.speedMax
        }
    }

    func temporarySpeedUp() {
        temporaryPlaybackSpeed = Const.speedMax
    }

    @MainActor
    func temporarySlowDown() {
        if unmodifiedPlaybackSpeed <= 1 {
            temporaryPlaybackSpeed = Const.speedMin
        } else {
            temporaryPlaybackSpeed = 1
        }
    }

    @MainActor
    func debouncedSpeedUp() {
        let nextSpeed = Const.speeds.first(where: { $0 > debouncedPlaybackSpeed }) ?? Const.speeds.last
        if let nextSpeed {
            setPlaybackSpeedDebounced(nextSpeed)
        }
    }

    @MainActor
    func debouncedSlowDown() {
        let nextSpeed = Const.speeds.last(where: { $0 < debouncedPlaybackSpeed }) ?? Const.speeds.first
        if let nextSpeed {
            setPlaybackSpeedDebounced(nextSpeed)
        }
    }

    @MainActor
    func tempSpeedChange(faster: Bool = false) {
        if faster {
            if temporaryPlaybackSpeed == Const.speedMax {
                temporaryPlaybackSpeed = nil
            } else {
                temporarySpeedUp()
            }
        } else {
            if [1, Const.speedMin].contains(temporaryPlaybackSpeed) {
                temporaryPlaybackSpeed = nil
            } else {
                temporarySlowDown()
            }
        }
    }

    func resetTemporaryPlaybackSpeed() {
        temporaryPlaybackSpeed = nil
    }

    @MainActor
    func toggleTemporaryPlaybackSpeed() {
        if temporaryPlaybackSpeed == nil {
            setTemporaryPlaybackSpeed()
        } else {
            resetTemporaryPlaybackSpeed()
        }
    }

    @MainActor
    private func setPlaybackSpeed(_ value: Double) {
        if temporaryPlaybackSpeed != nil {
            return
        }
        if video?.subscription?.customSpeedSetting != nil {
            video?.subscription?.customSpeedSetting = value
        } else {
            defaultPlaybackSpeed = value
        }
    }

    @MainActor
    private func handleRotateOnPlay() {
        #if os(iOS)
        let isShort = video?.isYtShort ?? false
        Task {
            if !isShort && UserDefaults.standard.bool(forKey: Const.rotateOnPlay) {
                OrientationManager.changeOrientation(to: .landscapeRight)
            }
        }
        #endif
    }

    @MainActor
    private func updateVideoEnded() {
        if videoEnded {
            setVideoEnded(false)
        }
    }

    @MainActor
    var videoIsCloseToEnd: Bool {
        guard let duration = video?.duration, let time = currentTime else {
            return false
        }
        return duration - time <= Const.secondsConsideredCloseToEnd
    }

    @MainActor
    func setVideoEnded(_ value: Bool) {
        Log.info("setVideoEnded \(value)")
        if value != videoEnded {
            withAnimation {
                videoEnded = value
            }
        }
    }

    func setPip(_ value: Bool) {
        if pipEnabled != value {
            pipEnabled = value
        }
    }

    @MainActor
    func onSleepTimerEnded(_ fadeOutSeconds: Double?) {
        var seconds = currentTime ?? 0
        pause()
        if let fadeOutSeconds = fadeOutSeconds, fadeOutSeconds > seconds {
            seconds -= fadeOutSeconds
        }
        updateElapsedTime(seconds)
    }

    @MainActor
    func setAirplayHD(_ value: Bool) {
        Log.info("setAirplayHD: \(value)")
        if airplayHD != value {
            airplayHD = value
            hotReloadPlayer()
        }
    }

    @MainActor
    func handlePotentialUpdate() {
        guard !isPlaying else {
            return
        }
        let context = DataProvider.mainContext
        loadTopmostVideoFromQueue(modelContext: context, updateTime: true)
    }
}
