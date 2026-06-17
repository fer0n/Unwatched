#if !os(macOS)
import SwiftUI
import UnwatchedShared

@Observable @MainActor
final class AVPlayerScrubberVM {
    var scrubberVisible = false
    var isScrubbing = false
    @ObservationIgnored private var autoHideTask: Task<Void, Never>?

    var showScrubber: Bool {
        scrubberVisible
    }

    func handleTap() {
        setScrubberVisible(!scrubberVisible)
    }

    func handlePlayingChanged(isPlaying: Bool) {
        if isPlaying {
            setScrubberVisible(false)
        } else {
            autoHideTask?.cancel()
            autoHideTask = nil
        }
    }

    func showBriefly() {
        setScrubberVisible(true)
    }

    func handleTemporarySpeedChanged(active: Bool) {
        guard active else { return }
        autoHideTask?.cancel()
        autoHideTask = nil
        scrubberVisible = false
    }

    /// Called when a double-tap seek occurs: surface the scrubber so the new position is
    /// visible, then hide it quickly once seeking stops. Repeated seeks reset the timer, so
    /// it stays up during a burst and disappears shortly after the last one.
    func handleSeek() {
        autoHideTask?.cancel()
        autoHideTask = nil
        scrubberVisible = true
        scheduleAutoHideIfPlaying(after: Const.seekScrubberAutoHideDebounce)
    }

    func handleLandscapeChanged(isLandscape: Bool) {
        guard !isLandscape else { return }
        setScrubberVisible(false)
    }

    func handleScrubbing(_ active: Bool) {
        isScrubbing = active
        if active {
            autoHideTask?.cancel()
            autoHideTask = nil
        } else {
            scheduleAutoHideIfPlaying()
        }
    }

    private func setScrubberVisible(_ visible: Bool) {
        autoHideTask?.cancel()
        autoHideTask = nil
        scrubberVisible = visible
        if visible {
            AutoHideVM.shared.setShowControls()
            scheduleAutoHideIfPlaying()
        }
    }

    private func scheduleAutoHideIfPlaying(after seconds: Double = Const.controlsAutoHideDebounce) {
        guard PlayerManager.shared.isPlaying else { return }
        autoHideTask = Task {
            do {
                try await Task.sleep(s: seconds)
                withAnimation { scrubberVisible = false }
            } catch {}
        }
    }
}

struct AVPlayerScrubberOverlay: View {
    var vm: AVPlayerScrubberVM
    @Environment(PlayerManager.self) var player

    var body: some View {
        pillStack
            .padding(.bottom, 30)
            .opacity(vm.showScrubber ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: vm.showScrubber)
            .sensoryFeedback(Const.sensoryFeedback, trigger: player.currentChapterPreview?.startTime) { old, new in
                vm.isScrubbing && old != nil && new != nil && old != new
            }
    }

    @ViewBuilder
    private var pillStack: some View {
        GlassEffectContainer(spacing: 0) {
            pills
        }
    }

    private var pills: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let title = (player.currentChapterPreview ?? player.currentChapter)?.title {
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: Capsule())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .containerRelativeFrame(.horizontal) { width, _ in
                        (width - 60) * 0.75
                    }
                    .padding(.leading, 30)
                    .transition(.opacity.combined(with: .scale(0.95, anchor: .bottomLeading)))
            }

            PlayerScrubber(
                height: 15,
                inlineTime: true,
                translucent: true,
                glassEffect: false,
                fillColor: .primary,
                trackColor: .secondary,
                timeColor: .primary,
                onScrubbingChanged: vm.handleScrubbing
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: Capsule())
            .padding(.horizontal, 30)
        }
    }
}

#Preview {
    var vm = AVPlayerScrubberVM()
    vm.scrubberVisible = true
    
    return VStack(spacing: 0) {
        AVPlayerScrubberOverlay(vm: vm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 30)
            .background(.black)

        AVPlayerScrubberOverlay(vm: vm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(.white)
            .padding(.top, 40)
    }
    .environment(PlayerManager.getDummy())
}
#endif
