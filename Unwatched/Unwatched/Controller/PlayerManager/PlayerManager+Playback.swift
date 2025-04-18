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
        Logger.log.info("handleAutoStart")
        isLoading = false

        guard let source = videoSource else {
            Logger.log.info("no source, stopping")
            return
        }
        Logger.log.info("source: \(String(describing: source))")
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
            Logger.log.info("updateElapsedTime: wrong video to update")
            return
        }
        Logger.log.info("updateElapsedTime")

        let newTime = time ?? currentTime

        guard let time = newTime,
              video?.elapsedSeconds != time,
              let modelId = video?.persistentModelID else {
            Logger.log.info("updateElapsedTime: no change")
            return
        }

        video?.elapsedSeconds = time

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            // workaround: avoid hiccups during seek, force update
            // simply setting the video doesn't save immediately
            let context = DataProvider.mainContext
            let model: Video? = context.existingModel(for: modelId)
            model?.elapsedSeconds = time
            try? context.save()
        }
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
    func seekForward() -> Bool {
        seek(backward: false)
    }

    @MainActor
    func seekBackward() -> Bool {
        seek(backward: true)
    }

    @MainActor
    func seek(backward: Bool) -> Bool {
        if video != nil && unstarted == false {
            let seek = backward ? -Const.seekSeconds : Const.seekSeconds
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
            temporaryPlaybackSpeed = Const.speedMax
        }
    }

    func temporarySpeedUp() {
        temporaryPlaybackSpeed = Const.speedMax
    }

    @MainActor
    func temporarySlowDown() {
        if actualPlaybackSpeed == 1 {
            temporaryPlaybackSpeed = Const.speedMin
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
        Logger.log.info("setVideoEnded")
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
        Logger.log.info("setAirplayHD: \(value)")
        if airplayHD != value {
            airplayHD = value
            handleHotSwap()
            PlayerManager.reloadPlayer()
        }
    }

    @MainActor
    func handlePotentialUpdate() {
        guard !isPlaying else {
            return
        }
        loadTopmostVideoFromQueue(updateTime: true)
    }
}
