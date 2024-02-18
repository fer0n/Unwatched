//
//  SleepTimer.swift
//  Unwatched
//

import SwiftUI
import MediaPlayer

struct SleepTimer: View {
    @Environment(PlayerManager.self) var player

    @State private var showPopover = false
    @State var slider: UISlider?
    @State var hapticToggle: Bool = false
    @State var viewModel: SleepTimerViewModel

    init(onEnded: @escaping (_ fadeOutSeconds: Double?) -> Void) {
        viewModel = SleepTimerViewModel(onEnded: onEnded)
    }

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            HStack(alignment: .center, spacing: 2) {
                Image(systemName: viewModel.remainingSeconds <= 0 ? "moon.zzz" : "moon.zzz.fill")
                    .contentTransition(.symbolEffect(.replace))

                if let text = viewModel.remainingText {
                    Text(text)
                        .font(.system(.body).monospacedDigit())
                }
            }
        }
        .onAppear {
            slider = MPVolumeView().subviews.first(where: { $0 is UISlider }) as? UISlider
        }
        .onReceive(viewModel.timer) { _ in
            viewModel.handleTimerUpdate()
        }
        .task(id: viewModel.lowerVolumeBy) {
            if let vol = viewModel.lowerVolumeBy {
                slider?.value -= vol
                viewModel.lowerVolumeBy = nil
            }
        }
        .task(id: viewModel.setVolumeTo) {
            if let vol = viewModel.setVolumeTo {
                slider?.value = vol
                viewModel.setVolumeTo = nil
            }
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .popover(isPresented: $showPopover) {
            sleepControl
                .padding()
                .presentationCompactAdaptation(.popover)
        }
        .onChange(of: player.isPlaying) {
            handleTimerPause()
        }
    }

    func handleTimerPause() {
        if player.isPlaying {
            viewModel.resumeTimer()
        } else {
            viewModel.pauseTimer()
        }
    }

    func addTimeButton(_ minutes: Int) -> some View {
        Button {
            if viewModel.remainingSeconds == 0 {
                withAnimation {
                    viewModel.addTime(minutes)
                }
            } else {
                viewModel.addTime(minutes)
            }
            viewModel.restoreVolume()
            handleTimerPause()
            hapticToggle.toggle()
        } label: {
            Label("\(minutes)", systemImage: "plus")
                .frame(maxWidth: .infinity)
        }
    }

    var sleepControl: some View {
        VStack {
            Label(viewModel.titleText, systemImage: "moon.zzz.fill")
                .font(.system(.body).monospacedDigit())

            HStack {
                addTimeButton(5)
                addTimeButton(30)
            }
            .buttonStyle(.borderedProminent)
            Button {
                viewModel.stopTimer()
                hapticToggle.toggle()
            } label: {
                Text("sleepTimerOff")
            }
            .disabled(viewModel.remainingSeconds <= 0)
            .padding()
        }
        .tint(.teal)
    }

}

// #Preview {
//    SleepTimer(onEnded: { _ in })
// }
