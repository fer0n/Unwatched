//
//  PlayerManager+Playback.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog

// PlayerManager+Playback
extension PlayerManager {

    func playVideo(_ video: Video) {
        self.videoSource = .userInteraction
        self.video = video
    }

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

    var playDisabled: Bool {
        let forceYtWatchHistory = UserDefaults.standard.bool(forKey: Const.forceYtWatchHistory)
        return forceYtWatchHistory && unstarted && !embeddingDisabled
    }

    func pause() {
        if self.isPlaying {
            self.isPlaying = false
        }
        updateVideoEnded()
    }

    /// Restarts, pauses or plays the current video
    func handlePlayButton() {
        if videoEnded {
            restartVideo()
        } else if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func restartVideo() {
        seekPosition = 0
        play()
    }

    var playbackSpeed: Double {
        get {
            temporaryPlaybackSpeed ?? getPlaybackSpeed()
        }
        set {
            setPlaybackSpeed(newValue)
        }
    }

    var actualPlaybackSpeed: Double {
        getPlaybackSpeed()
    }

    private func getPlaybackSpeed() -> Double {
        video?.subscription?.customSpeedSetting ??
            UserDefaults.standard.object(forKey: Const.playbackSpeed) as? Double ?? 1
    }

    private func setPlaybackSpeed(_ value: Double) {
        if video?.subscription?.customSpeedSetting != nil {
            video?.subscription?.customSpeedSetting = value
        } else {
            UserDefaults.standard.setValue(value, forKey: Const.playbackSpeed)
        }
    }

    private func handleRotateOnPlay() {
        let isShort = video?.isYtShort ?? false
        Task {
            if !isShort && UserDefaults.standard.bool(forKey: Const.rotateOnPlay) {
                await OrientationManager.changeOrientation(to: .landscapeRight)
            }
        }
    }

    private func updateVideoEnded() {
        if videoEnded {
            setVideoEnded(false)
        }
    }

    func setVideoEnded(_ value: Bool) {
        if value != videoEnded {
            withAnimation {
                videoEnded = value
            }
        }
    }
}
