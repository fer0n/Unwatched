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

    static let videoTransitionFade: Double = 0.4
    private static let videoTransitionTimeout: Double = 5

    /// Fades to black, swaps in the next video, stays covered until it plays.
    /// Callers switch videos via `setNextVideo`, which is what triggers this.
    @MainActor
    func fadeToNextVideo(_ swap: @escaping @MainActor () -> Void) {
        transitionTask?.cancel()
        transitionCovered = true
        transitionPendingSwap = true
        transitionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.videoTransitionFade))
            guard !Task.isCancelled else { return }
            swap()
            self?.transitionPendingSwap = false
            // fallback for a video that never gets going
            try? await Task.sleep(for: .seconds(Self.videoTransitionTimeout))
            guard !Task.isCancelled else { return }
            self?.endVideoTransition()
        }
    }

    @MainActor
    func endVideoTransition() {
        // the outgoing video reporting in doesn't end a transition that's still waiting to swap
        guard !transitionPendingSwap else { return }
        transitionTask?.cancel()
        transitionTask = nil
        if transitionCovered { transitionCovered = false }
    }

    @MainActor
    func handleAutoStart(_ url: URL?) {
        Log.info("handleAutoStart")
        if let url, let videoId = UrlService.getYoutubeIdFromUrl(url: url) {
            guard video?.youtubeId == videoId else {
                Log.warning("outdated video \(videoId) != \(video?.youtubeId ?? "nil"), stopping")
                return
            }
        }
        guard let source = videoSource else {
            Log.info("no source, stopping")
            endVideoTransition()
            return
        }
        Log.info("source: \(String(describing: source))")
        var starting = false
        switch source {
        case .continuousPlay:
            let continuousPlay = UserDefaults.standard.bool(forKey: Const.continuousPlay)
            if continuousPlay {
                play()
                starting = true
            }
        case .nextUp:
            break
        case .userInteraction:
            play()
            starting = true
        case .playWhenReady:
            previousState.isPlaying = false
            play()
            starting = true
        case .hotSwap, .errorSwap:
            if previousIsPlaying {
                play()
                starting = true
            }
        @unknown default:
            break
        }
        if !starting {
            // loaded, but nothing will start it: uncovering can't wait for playback here
            endVideoTransition()
        }
        videoSource = nil
    }

    /// - Parameter immediate: skip the debounce and write through. The model is updated right away
    ///   either way; only the save is normally deferred, which is no use when the app is about to
    ///   be suspended.
    @MainActor
    func updateElapsedTime(_ time: Double? = nil, videoId: String? = nil, immediate: Bool = false) {
        if videoId != nil && videoId != video?.youtubeId {
            // avoid updating the wrong video
            Log.info("updateElapsedTime: wrong video to update")
            return
        }
        Log.info("updateElapsedTime")

        let newTime = time ?? currentTime

        guard let time = newTime,
              let modelId = video?.persistentModelID else {
            Log.info("updateElapsedTime: nothing to update")
            return
        }
        // An unchanged value can still be waiting on a debounced save, so `immediate` writes anyway
        guard video?.elapsedSeconds != time || immediate else {
            Log.info("updateElapsedTime: no change")
            return
        }

        video?.elapsedSeconds = time
        if immediate {
            VideoService.forceUpdateVideoNow(modelId, elapsedSeconds: time)
        } else {
            _ = VideoService.forceUpdateVideo(modelId, elapsedSeconds: time)
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
        currentRemaining?.formatTimeMinimal
    }

    @MainActor
    func playVideo(_ video: Video) {
        self.videoSource = .userInteraction
        if self.video?.youtubeId != video.youtubeId {
            setNextVideo(video, .userInteraction)
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
        seek(backward: false, seconds ?? userSeekSeconds)
    }

    @MainActor
    func seekBackward(_ seconds: Double? = nil) -> Bool {
        seek(backward: true, seconds ?? userSeekSeconds)
    }

    var userSeekSeconds: Double {
        UserDefaults.standard.value(forKey: Const.doubleTapSeekDuration) as? Double ?? Const.seekSeconds
    }

    @MainActor
    func seek(backward: Bool, _ seconds: Double) -> Bool {
        if video != nil {
            let offset = backward ? -seconds : seconds
            let base = currentTime ?? 0
            let target = max(0, chapterAwareSeekTarget(from: base, offset: offset))
            seekAbsolute = target
            currentTime = target
            updateVideoEnded()
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
        updateVideoEnded()
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
        Signal.log("Player.setTemporarySpeed")
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

    /// Toggle Picture-in-Picture. Logs on enter only, so `Player.PIP` counts deliberate
    /// user PIP starts for both the web and native players (auto-PIP on backgrounding is
    /// intentionally excluded — this answers "who uses the PIP button").
    @MainActor
    func togglePip() {
        pipEnabled.toggle()
        if pipEnabled {
            Signal.log("Player.PIP")
        }
    }

    /// Where the player currently is, for analytics context. Shared by `Player.setPlaybackSpeed`
    /// and `Player.NextVideo` so the "portrait vs. landscape fullscreen vs. embedded" split
    /// stays comparable across surfaces.
    @MainActor
    var fullscreenContext: String {
        SheetPositionReader.shared.landscapeFullscreen
            ? "landscape"
            : (tallFullscreenActive ? "portrait" : "off")
    }

    @MainActor
    private func setPlaybackSpeed(_ value: Double) {
        if temporaryPlaybackSpeed != nil {
            return
        }
        Signal.log("Player.setPlaybackSpeed", parameters: ["fullscreen": fullscreenContext])
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
