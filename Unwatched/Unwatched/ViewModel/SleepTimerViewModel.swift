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
    var remainingSeconds: Int = 0

    var lowerVolumeBy: Float?
    var setVolumeTo: Float?

    @ObservationIgnored var onEnded: ((_ fadeOutSeconds: Double?) -> Void)?

    deinit {
        timer?.invalidate()
    }

    var isOn: Bool {
        remainingSeconds > 0
    }

    var remainingText: String? {
        if remainingSeconds > 0 {
            return Double(remainingSeconds).formatTimeMinimal
        }
        return nil
    }

    var titleText: String {
        let time = remainingSeconds != 0 ? "(\(timeString(time: remainingSeconds)))" : ""
        return String(localized: "sleepTimer\(time)")
    }

    func timeString(time: Int) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60

        if hours > 0 {
            return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
        } else {
            return String(format: "%02i:%02i", minutes, seconds)
        }
    }

    func addTime(_ minutes: Int) {
        Log.info("addTime \(minutes)")
        remainingSeconds += minutes * 60
        Log.info("remainingSeconds \(self.remainingSeconds)")
        resetAudioFadeOut()
    }

    func startTimer() {
        self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.handleTimerUpdate()
        }
    }

    func handleTimerUpdate() {
        handleAudioFadeOut()
        if remainingSeconds == 1 {
            remainingSeconds = 0
        } else if remainingSeconds > 0 {
            remainingSeconds -= 1
        } else {
            Log.info("onEnded \(self.remainingSeconds)")
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

    func pauseTimer() {
        timer?.invalidate()
        timer = nil
    }

    func resumeTimer() {
        if remainingSeconds > 0 && timer == nil {
            startTimer()
        }
    }
}
