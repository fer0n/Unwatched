//
//  FullscreenSpeedControl.swift
//  Unwatched
//

import SwiftUI

@Observable class FullscreenSpeedControlVM {
    var debounceTask: Task<Void, Never>?
}

struct FullscreenSpeedControl: View {
    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1.0
    @Environment(PlayerManager.self) var player
    @State var showSpeedControl = false
    @Binding var menuOpen: Bool

    @State var viewModel = FullscreenSpeedControlVM()

    @GestureState private var isDetectingLongPress = false

    var body: some View {

        Button {
            // nothing
        } label: {
            fullscreenControlLabel
        }
        .simultaneousGesture(longPress)
        .highPriorityGesture(
            TapGesture()
                .onEnded { _ in
                    if !showSpeedControl {
                        showSpeedControl = true
                        menuOpen = true
                    }
                }
        )
        .frame(width: 35)
        .fontWeight(.bold)
        .popover(isPresented: $showSpeedControl) {
            ZStack {
                Color.sheetBackground
                    .scaleEffect(1.5)

                CombinedPlaybackSpeedSetting()
                    .padding(.horizontal)
                    .frame(width: 350)
            }
            .environment(\.colorScheme, .dark)
            .presentationCompactAdaptation(.popover)
            .onDisappear {
                menuOpen = false
            }
        }
    }

    var fullscreenControlLabel: some View {
        let customSetting = player.video?.subscription?.customSpeedSetting != nil

        return HStack(spacing: 0) {
            let speedText = SpeedControlViewModel.formatSpeed(player.playbackSpeed)
            Text(verbatim: speedText)
                .font(.custom("SFCompactDisplay-Bold", size: 16))
            if speedText.count <= 1 {
                Text(verbatim: "×")
                    .font(.custom("SFCompactDisplay-Semibold", size: 14))
            }
        }
        .fixedSize()
        .modifier(PlayerControlButtonStyle(isOn: customSetting))
        .animation(.default, value: customSetting)
        .onChange(of: playbackSpeed) {
            // workaround: refresh speed
        }
        .onChange(of: player.video?.subscription) {
            // workaround: refresh speed
        }
    }

    var longPress: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isDetectingLongPress) { _, _, _ in
                startDebouncedSpeedUp()
            }
            .onEnded { _ in
                cancelSpeedUp()
            }
    }

    func startDebouncedSpeedUp() {
        viewModel.debounceTask?.cancel()
        viewModel.debounceTask = Task {
            do {
                try await Task.sleep(s: 0.2)
                changeSpeed()
            } catch {
                // canceled
            }
        }
    }

    func cancelSpeedUp() {
        viewModel.debounceTask?.cancel()
        reset()
    }

    func changeSpeed() {
        menuOpen = true
        player.setTemporaryPlaybackSpeed()
    }

    func reset() {
        player.resetTemporaryPlaybackSpeed()
        menuOpen = false
    }
}
