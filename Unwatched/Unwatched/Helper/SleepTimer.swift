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

    @State var hapticToggle: Bool = false
    @Binding var viewModel: SleepTimerViewModel

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
            .disabled(!viewModel.isOn)
        } label: {
            // whole minutes only: a per-second countdown rebuilds the open menu and stops it scrolling
            Label(viewModel.menuTitle, systemImage: "moon.zzz.fill")
        }
        #if os(iOS)
        .menuActionDismissBehavior(.disabled)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        #endif
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
            viewModel.syncWithPlayback(isPlaying: player.isPlaying)
            hapticToggle.toggle()
            Signal.interaction("Player.MoreMenu", "sleepTimer")
        } label: {
            Label("\(minutes) min", systemImage: "plus")
                .frame(maxWidth: .infinity)
                .foregroundStyle(theme.contrastColor)
        }
    }
}

/// On VideoPlayer, not in SleepTimer: menu content is only built once opened, and each player layout has its own.
struct SleepTimerPlaybackSync: ViewModifier {
    @Environment(PlayerManager.self) private var player
    let viewModel: SleepTimerViewModel

    #if os(iOS)
    @State private var slider: UISlider?
    #endif

    func body(content: Content) -> some View {
        content
            .onAppear {
                viewModel.onEnded = player.onSleepTimerEnded
            }
            .onPlayerPlayingChange { isPlaying in
                viewModel.syncWithPlayback(isPlaying: isPlaying)
            }
            #if os(iOS)
            .task(id: viewModel.lowerVolumeBy) {
                if let vol = viewModel.lowerVolumeBy {
                    volumeSlider?.value -= vol
                    viewModel.lowerVolumeBy = nil
                }
            }
            .task(id: viewModel.setVolumeTo) {
                if let vol = viewModel.setVolumeTo {
                    volumeSlider?.value = vol
                    viewModel.setVolumeTo = nil
                }
            }
        #endif
    }

    #if os(iOS)
    private var volumeSlider: UISlider? {
        if slider == nil {
            slider = MPVolumeView().subviews.first(where: { $0 is UISlider }) as? UISlider
        }
        return slider
    }
    #endif
}

#Preview {
    SleepTimer(viewModel: .constant(SleepTimerViewModel()))
        .environment(PlayerManager())
}
