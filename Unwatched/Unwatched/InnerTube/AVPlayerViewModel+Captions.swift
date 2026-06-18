#if !os(macOS)
import AVKit
import OSLog
import UnwatchedShared

extension AVPlayerViewModel {

    // MARK: - Caption track selection

    @MainActor
    func handleCaptionTrackChange(_ trackId: String?) {
        captionFetchTask?.cancel()
        captionFetchTask = nil
        player.captionCues = []
        player.currentCaptionCue = nil
        stopCaptionTimeObserver()

        guard let trackId,
              let track = player.availableCaptionTracks.first(where: { $0.id == trackId }) else { return }

        let url = track.baseURL
        captionFetchTask = Task {
            do {
                let cues = try await WebVTTParser().fetchCues(from: url)
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.player.captionCues = cues
                    self.startCaptionTimeObserver()
                }
            } catch {
                Log.error("Caption fetch failed: \(error)")
            }
        }
    }

    // MARK: - Caption time observer (100 ms — fine enough to track cue boundaries)

    @MainActor
    func startCaptionTimeObserver() {
        stopCaptionTimeObserver()
        captionTimeObserverToken = avPlayer.addPeriodicTimeObserver(
            forInterval: .init(seconds: 0.1, preferredTimescale: 600), queue: .main
        ) { [weak self] cmTime in
            guard let self else { return }
            let t = cmTime.seconds
            guard !t.isNaN, !t.isInfinite else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.player.currentCaptionCue = self.player.findCaptionCue(at: t + 0.15)
            }
        }
    }

    @MainActor
    func stopCaptionTimeObserver() {
        guard let token = captionTimeObserverToken else { return }
        avPlayer.removeTimeObserver(token)
        captionTimeObserverToken = nil
    }
}
#endif
