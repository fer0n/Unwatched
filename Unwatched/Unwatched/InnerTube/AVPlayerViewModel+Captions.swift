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

    // MARK: - Caption boundary observer

    /// Instead of polling, register every cue boundary with the player so it fires us
    /// exactly when each one is crossed. AVPlayer handles rate and pause internally; the
    /// time-jump notification covers seeks (which a boundary observer alone would miss
    /// when landing in the middle of a cue). Boundaries are shifted earlier by the lead
    /// time so captions appear slightly ahead of speech.
    @MainActor
    func startCaptionTimeObserver() {
        stopCaptionTimeObserver()
        let cues = player.captionCues
        guard !cues.isEmpty else { return }
        let lead = PlayerManager.captionLeadTime

        let times = cues.flatMap { cue -> [NSValue] in
            [cue.startTime, cue.endTime].map {
                NSValue(time: CMTime(seconds: max(0, $0 - lead), preferredTimescale: 600))
            }
        }
        captionTimeObserverToken = avPlayer.addBoundaryTimeObserver(
            forTimes: times, queue: .main
        ) { [weak self] in
            Task { @MainActor [weak self] in self?.refreshCaptionCue() }
        }

        // object: nil so we keep catching jumps across item replacements (quality switches).
        captionSeekObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.timeJumpedNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshCaptionCue() }
        }
    }

    @MainActor
    func refreshCaptionCue() {
        let t = avPlayer.currentTime().seconds
        guard !t.isNaN, !t.isInfinite else { return }
        let cue = player.findCaptionCue(at: t + PlayerManager.captionLeadTime)
        if cue?.startTime != player.currentCaptionCue?.startTime {
            player.currentCaptionCue = cue
        }
    }

    @MainActor
    func stopCaptionTimeObserver() {
        if let token = captionTimeObserverToken {
            avPlayer.removeTimeObserver(token)
            captionTimeObserverToken = nil
        }
        if let observer = captionSeekObserver {
            NotificationCenter.default.removeObserver(observer)
            captionSeekObserver = nil
        }
    }
}
#endif
