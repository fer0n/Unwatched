//
//  SleepTimerViewModel.swift
//  Unwatched
//

import Foundation
import SwiftUI
import MediaPlayer

@Observable class SleepTimerViewModel {
    @ObservationIgnored private var startFadeOutAtSecond: Int = 40
    @ObservationIgnored private var fadeOutAudio = true

    @ObservationIgnored private var startFadeOutTime: Int?
    @ObservationIgnored private var oldVolume: Float?
    @ObservationIgnored private var volumeStep: Float?

    var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var remainingSeconds: Int = -1

    var lowerVolumeBy: Float?
    var setVolumeTo: Float?

    @ObservationIgnored var onEnded: ((_ fadeOutSeconds: Double?) -> Void)?

    deinit {
        timer.upstream.connect().cancel()
    }

    var remainingText: String? {
        if remainingSeconds > 0 {
            let remaining = Double(remainingSeconds)
            let sec = remaining.formatTimeMinimal
            let remainingText = sec
            let text = remainingText ?? "\(remainingSeconds)"
            return text
        }
        return nil
    }

    var titleText: String {
        return remainingSeconds != 0
            ? "\(timeString(time: remainingSeconds))"
            : String(localized: "sleepTimer")
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
        print("addTime", minutes)
        remainingSeconds += minutes * 60
        print("remainingSeconds", remainingSeconds)
        resetAudioFadeOut()
    }

    func startTimer() {
        self.timer = Timer.publish(every: 1, on: .current, in: .common).autoconnect()
    }

    func handleTimerUpdate() {
        if remainingSeconds == -1 {
            // initial value
            stopTimer()
            return
        }

        handleAudioFadeOut()
        if remainingSeconds == 1 {
            withAnimation {
                remainingSeconds = 0
            }
        } else if remainingSeconds > 0 {
            remainingSeconds -= 1
        } else {
            onEnded?(startFadeOutTime.map { Double($0) })
            stopTimer()
        }
    }

    func stopTimer() {
        timer.upstream.connect().cancel()
        withAnimation {
            remainingSeconds = 0
        }
        resetAudioFadeOut()
        restoreVolume()
        oldVolume = nil
    }

    func setupFadeOut() {
        startFadeOutTime = remainingSeconds
        let vol = AVAudioSession.sharedInstance().outputVolume
        oldVolume = vol
        let newValue = vol / Float(remainingSeconds)
        self.volumeStep = newValue
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
        timer.upstream.connect().cancel()
    }

    func resumeTimer() {
        if remainingSeconds > 0 {
            startTimer()
        }
    }
}
