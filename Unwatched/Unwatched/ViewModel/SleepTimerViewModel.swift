//
//  SleepTimerViewModel.swift
//  Unwatched
//

import Foundation
import SwiftUI
import MediaPlayer
import UnwatchedShared

@Observable class SleepTimerViewModel {
    @ObservationIgnored private var startFadeOutAtSecond: Int = 40
    @ObservationIgnored private var fadeOutAudio = true

    @ObservationIgnored private var startFadeOutTime: Int?
    @ObservationIgnored private var oldVolume: Float?
    @ObservationIgnored private var volumeStep: Float?

    var timer: Timer?
    /// Unobserved: ticks every second, which would rebuild an open menu and stop it scrolling.
    @ObservationIgnored var remainingSeconds: Int = 0 {
        didSet {
            let minutes = Int((Double(remainingSeconds) / 60).rounded(.up))
            if minutes != remainingMinutes {
                remainingMinutes = minutes
            }
        }
    }
    /// Rounded up, so views only update once a minute.
    private(set) var remainingMinutes: Int = 0

    var lowerVolumeBy: Float?
    var setVolumeTo: Float?

    @ObservationIgnored var onEnded: ((_ fadeOutSeconds: Double?) -> Void)?

    deinit {
        timer?.invalidate()
    }

    var isOn: Bool {
        remainingMinutes > 0
    }

    var remainingText: String? {
        if remainingMinutes > 0 {
            return Double(remainingMinutes * 60).formatTimeMinimal
        }
        return nil
    }

    var menuTitle: String {
        if let remainingText {
            return String(localized: "sleepTimer\("(\(remainingText))")")
        }
        return String(localized: "sleepTimer")
    }

    func addTime(_ minutes: Int) {
        Log.player.info("addTime \(minutes)")
        remainingSeconds += minutes * 60
        Log.player.info("remainingSeconds \(self.remainingSeconds)")
        resetAudioFadeOut()
    }

    func startTimer() {
        self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.handleTimerUpdate()
        }
    }

    func handleTimerUpdate() {
        handleAudioFadeOut()
        if remainingSeconds == 1 {
            remainingSeconds = 0
        } else if remainingSeconds > 0 {
            remainingSeconds -= 1
        } else {
            Log.player.info("onEnded \(self.remainingSeconds)")
            onEnded?(startFadeOutTime.map { Double($0) })
            stopTimer()
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        withAnimation {
            remainingSeconds = 0
        }
        resetAudioFadeOut()
        restoreVolume()
        oldVolume = nil
    }

    func setupFadeOut() {
        #if os(iOS)
        startFadeOutTime = remainingSeconds
        let vol = AVAudioSession.sharedInstance().outputVolume
        oldVolume = vol
        let newValue = vol / Float(remainingSeconds)
        self.volumeStep = newValue
        #endif
    }

    func handleAudioFadeOut() {
        guard fadeOutAudio else {
            return
        }
        if remainingSeconds <= startFadeOutAtSecond && volumeStep == nil {
            setupFadeOut()
        }
        if remainingSeconds <= startFadeOutAtSecond, let step = volumeStep {
            lowerVolumeBy = step
        }
    }

    func resetAudioFadeOut() {
        volumeStep = nil
    }

    func restoreVolume() {
        if let oldVolume = oldVolume {
            setVolumeTo = oldVolume
        }
    }

    private func pauseTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func resumeTimer() {
        if remainingSeconds > 0 && timer == nil {
            startTimer()
        }
    }

    func syncWithPlayback(isPlaying: Bool) {
        if isPlaying {
            resumeTimer()
        } else {
            pauseTimer()
        }
    }
}
