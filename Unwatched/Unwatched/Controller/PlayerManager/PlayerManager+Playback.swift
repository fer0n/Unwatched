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
    func updateElapsedTime(_ time: Double? = nil, videoId: String? = nil) {
        if videoId != nil && videoId != video?.youtubeId {
            // avoid updating the wrong video
            Logger.log.info("updateElapsedTime: wrong video to update")
            return
        }
        Logger.log.info("updateElapsedTime")

        let newTime = time ?? currentTime
        if let time = newTime, video?.elapsedSeconds != time {
            video?.elapsedSeconds = time
        }
    }

    var currentRemaining: Double? {
        if let end = currentEndTime, let current = currentTime {
            return max(end - current, 0)
        }
        return nil
    }

    var currentRemainingText: String? {
        if let remaining = currentRemaining,
           let rem = remaining.getFormattedSeconds(for: [.minute, .hour]) {
            return "\(rem)"
        }
        return nil
    }

    @MainActor
    func playVideo(_ video: Video) {
        self.videoSource = .userInteraction
        self.video = video
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
    }

    func pause() {
        if self.isPlaying {
            self.isPlaying = false
        }
        updateVideoEnded()
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
        seekPosition = 0
        play()
    }

    @MainActor
    var playbackSpeed: Double {
        get {
            temporaryPlaybackSpeed ?? getPlaybackSpeed()
        }
        set {
            setPlaybackSpeed(newValue)
        }
    }

    @MainActor
    var actualPlaybackSpeed: Double {
        getPlaybackSpeed()
    }

    @MainActor
    var temporarySlowDownThreshold: Bool {
        actualPlaybackSpeed >= Const.temporarySpeedSwap
    }

    @MainActor
    func setTemporaryPlaybackSpeed() {
        if temporarySlowDownThreshold {
            temporaryPlaybackSpeed = 1
        } else {
            temporaryPlaybackSpeed = 3
        }
    }

    func temporarySpeedUp() {
        temporaryPlaybackSpeed = 3
    }

    @MainActor
    func temporarySlowDown() {
        if actualPlaybackSpeed == 1 {
            temporaryPlaybackSpeed = 0.5
        } else {
            temporaryPlaybackSpeed = 1
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
    private func getPlaybackSpeed() -> Double {
        video?.subscription?.customSpeedSetting ??
            UserDefaults.standard.object(forKey: Const.playbackSpeed) as? Double ?? 1
    }

    @MainActor
    private func setPlaybackSpeed(_ value: Double) {
        if video?.subscription?.customSpeedSetting != nil {
            video?.subscription?.customSpeedSetting = value
        } else {
            UserDefaults.standard.setValue(value, forKey: Const.playbackSpeed)
        }
    }

    @MainActor
    private func handleRotateOnPlay() {
        let isShort = video?.isYtShort ?? false
        Task {
            if !isShort && UserDefaults.standard.bool(forKey: Const.rotateOnPlay) {
                OrientationManager.changeOrientation(to: .landscapeRight)
            }
        }
    }

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

    func setVideoEnded(_ value: Bool) {
        if value != videoEnded {
            withAnimation {
                videoEnded = value
            }
        }
    }

    var canSetPip: Bool {
        !unstarted
    }

    func setPip(_ value: Bool) {
        if !canSetPip {
            return
        }
        if pipEnabled != value {
            pipEnabled = value
        }
    }
}
