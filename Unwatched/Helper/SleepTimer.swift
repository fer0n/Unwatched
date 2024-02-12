//
//  SleepTimer.swift
//  Unwatched
//

import SwiftUI
import MediaPlayer

struct SleepTimer: View {
    @State private var remainingSeconds: Int = 0
    @State private var showPopover = false
    @State private var timer: Timer?
    @State var slider: UISlider?

    @State var volumeStep: Float?
    @State var oldVolume: Float?
    @State var startFadeOutTime: Int?
    @State var hapticToggle: Bool = false

    var onEnded: (_ fadeOutSeconds: Double?) -> Void
    var fadeOutAudio = true
    var startFadeOutAtSecond: Int = 40

    init(onEnded: @escaping (_ fadeOutSeconds: Double?) -> Void) {
        self.onEnded = onEnded
    }

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            HStack(alignment: .center, spacing: 2) {
                Image(systemName: remainingSeconds == 0 ? "moon.zzz" : "moon.zzz.fill")
                    .contentTransition(.symbolEffect(.replace))

                if remainingSeconds > 0 {
                    let remaining = Double(remainingSeconds)
                    let sec = remaining.formatTimeMinimal
                    let remainingText = sec
                    let text = remainingText ?? "\(remainingSeconds)"

                    Text(text)
                        .font(.system(.body).monospacedDigit())
                }
            }
        }
        .onAppear {
            slider = MPVolumeView().subviews.first(where: { $0 is UISlider }) as? UISlider
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .popover(isPresented: $showPopover,
                 content: {
                    sleepControl
                        .padding()
                        .presentationCompactAdaptation(.popover)
                 })
    }

    func addTimeButton(_ minutes: Int) -> some View {
        Button {
            addTime(minutes)
            restoreVolume()
            hapticToggle.toggle()
        } label: {
            Label("\(minutes)", systemImage: "plus")
                .frame(maxWidth: .infinity)
        }
    }

    var sleepControl: some View {
        VStack {
            let text = remainingSeconds != 0
                ? "\(timeString(time: remainingSeconds))"
                : String(localized: "sleepTimer")

            Label(text, systemImage: "moon.zzz.fill")
                .font(.system(.body).monospacedDigit())

            HStack {
                addTimeButton(5)
                addTimeButton(30)
            }
            .buttonStyle(.borderedProminent)
            Button {
                stopTimer()
                hapticToggle.toggle()
            } label: {
                Text("sleepTimerOff")
            }
            .disabled(remainingSeconds <= 0)
            .padding()
        }
        .tint(.teal)
    }

    func addTime(_ minutes: Int) {
        let newValue = remainingSeconds + minutes * 60 // Convert to seconds
        if remainingSeconds == 0 {
            withAnimation {
                remainingSeconds = newValue
            }
        } else {
            remainingSeconds = newValue
        }
        resetAudioFadeOut()
        startTimer()
    }

    func resetAudioFadeOut() {
        volumeStep = nil
    }

    func stopTimer(volumeDelayed: Bool = false) {
        timer?.invalidate()
        timer = nil
        withAnimation {
            remainingSeconds = 0
        }
        resetAudioFadeOut()
        restoreVolume(delayed: volumeDelayed)
        oldVolume = nil
    }

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            handleAudioFadeOut()
            if remainingSeconds == 1 {
                withAnimation {
                    remainingSeconds = 0
                }
            } else if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                onEnded(startFadeOutTime.map { Double($0) })
                stopTimer(volumeDelayed: true)
            }
        }
    }

    func handleAudioFadeOut() {
        guard fadeOutAudio else {
            return
        }
        if remainingSeconds <= startFadeOutAtSecond && volumeStep == nil {
            setupFadeOut()
        }
        if remainingSeconds <= startFadeOutAtSecond, let step = volumeStep {
            lowerVolume(by: step)
        }
    }

    func lowerVolume(by value: Float) {
        Task { @MainActor in slider?.value -= value }
    }

    func restoreVolume(delayed: Bool = false) {
        if let oldVolume = oldVolume {
            Task { @MainActor in
                do {
                    // wait some time before restoring the value
                    if delayed {
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                    slider?.value = oldVolume
                } catch { }
            }
        }
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

    func setupFadeOut() {
        startFadeOutTime = remainingSeconds
        let vol = AVAudioSession.sharedInstance().outputVolume
        oldVolume = vol
        let newValue = vol / Float(remainingSeconds)
        self.volumeStep = newValue
    }
}

#Preview {
    SleepTimer(onEnded: { _ in })
}
