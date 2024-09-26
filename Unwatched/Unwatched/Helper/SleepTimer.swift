//
//  SleepTimer.swift
//  Unwatched
//

import SwiftUI
import MediaPlayer
import UnwatchedShared

struct SleepTimer: View {
    @Environment(PlayerManager.self) var player
    @Environment(\.colorScheme) var colorScheme
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    @State private var showPopover = false
    @State var slider: UISlider?
    @State var hapticToggle: Bool = false
    var viewModel: SleepTimerViewModel

    init(viewModel: SleepTimerViewModel, onEnded: @escaping (_ fadeOutSeconds: Double?) -> Void) {
        viewModel.onEnded = onEnded
        self.viewModel = viewModel
    }

    var accessibilityLabel: String {
        if let remainingText = viewModel.remainingText {
            return String(localized: "sleepTimer\(remainingText)")
        } else {
            return String(localized: "sleepTimer")
        }
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
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            slider = MPVolumeView().subviews.first(where: { $0 is UISlider }) as? UISlider
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
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
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
                .foregroundStyle(theme.contrastColor)
        }
    }

    var sleepControl: some View {
        ZStack {
            Color.sheetBackground
                .scaleEffect(1.5)

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
            .tint(theme.color)
        }
        .environment(\.colorScheme, colorScheme)
    }

}

#Preview {
    SleepTimer(viewModel: SleepTimerViewModel(), onEnded: { _ in })
        .environment(PlayerManager())
}
