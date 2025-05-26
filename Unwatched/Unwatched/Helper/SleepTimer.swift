//
//  SleepTimer.swift
//  Unwatched
//

import SwiftUI
import MediaPlayer
import UnwatchedShared

struct SleepTimer: View {
    @Environment(PlayerManager.self) var player
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    #if os(iOS)
    @State var slider: UISlider?
    #endif
    @State var hapticToggle: Bool = false
    @Binding var viewModel: SleepTimerViewModel

    init(viewModel: Binding<SleepTimerViewModel>, onEnded: @escaping (_ fadeOutSeconds: Double?) -> Void) {
        viewModel.wrappedValue.onEnded = onEnded
        self._viewModel = viewModel
    }

    var accessibilityLabel: String {
        if let remainingText = viewModel.remainingText {
            return String(localized: "sleepTimer\(remainingText)")
        } else {
            return String(localized: "sleepTimer")
        }
    }

    var body: some View {
        Menu {
            addTimeButton(5)
            addTimeButton(30)

            Button {
                viewModel.stopTimer()
                hapticToggle.toggle()
            } label: {
                Text("sleepTimerOff")
            }
            .disabled(viewModel.remainingSeconds <= 0)
        } label: {
            HStack(alignment: .center, spacing: 2) {
                Text(viewModel.titleText)
                Image(systemName: "moon.zzz.fill")
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .accessibilityLabel(accessibilityLabel)
        #if os(iOS)
        .menuActionDismissBehavior(.disabled)
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
        #endif
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
            Label("\(minutes) min", systemImage: "plus")
                .frame(maxWidth: .infinity)
                .foregroundStyle(theme.contrastColor)
        }
    }
}

#Preview {
    SleepTimer(viewModel: .constant(SleepTimerViewModel()), onEnded: { _ in })
        .environment(PlayerManager())
}
