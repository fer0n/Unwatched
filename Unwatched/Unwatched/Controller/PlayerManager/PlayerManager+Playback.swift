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
        isLoading = nil

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
        if self.isLoading != nil {
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
            temporaryPlaybackSpeed = tempSpeedUpValue
        }
        Signal.log("Player.setTemporarySpeed", throttle: .weekly)
    }

    func temporarySpeedUp() {
        temporaryPlaybackSpeed = tempSpeedUpValue
    }

    @MainActor
    func temporarySlowDown() {
        if unmodifiedPlaybackSpeed <= 1 {
            temporaryPlaybackSpeed = tempSlowDownValue
        } else {
            temporaryPlaybackSpeed = 1
        }
    }

    @MainActor
    func debouncedSpeedUp() {
        if let nextSpeed = SpeedHelper.getNextSpeed(after: debouncedPlaybackSpeed) {
            setPlaybackSpeedDebounced(nextSpeed)
        }
    }

    @MainActor
    func debouncedSlowDown() {
        if let nextSpeed = SpeedHelper.getPreviousSpeed(before: debouncedPlaybackSpeed) {
            setPlaybackSpeedDebounced(nextSpeed)
        }
    }

    var tempSpeedUpValue: Double {
        UserDefaults.standard.value(forKey: Const.temporarySpeedUp) as? Double ?? Const.speedMax
    }

    var tempSlowDownValue: Double {
        UserDefaults.standard.value(forKey: Const.temporarySlowDown) as? Double ?? Const.speedMin
    }

    @MainActor
    func tempSpeedChange(faster: Bool = false) -> Bool {
        if faster {
            if temporaryPlaybackSpeed == tempSpeedUpValue {
                temporaryPlaybackSpeed = nil
                return false
            } else {
                temporarySpeedUp()
                return true
            }
        } else {
            if [1, tempSlowDownValue].contains(temporaryPlaybackSpeed) {
                temporaryPlaybackSpeed = nil
                return false
            } else {
                temporarySlowDown()
                return true
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
        Signal.log("Player.setPlaybackSpeed", throttle: .weekly)
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
        guard let duration = video?.duration,
              let time = currentTime else {
            return false
        }
        let remainingTime = duration - time
        // live streams may have an incorrect duration, remaining time shouldn't be too far off
        return remainingTime <= Const.secondsConsideredCloseToEnd && remainingTime > -10
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
        loadTopmostVideoFromQueue(modelContext: context, updateTime: false)
    }
}
