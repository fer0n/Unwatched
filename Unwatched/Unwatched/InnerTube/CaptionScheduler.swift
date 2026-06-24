#if !os(macOS)
import Foundation
import UnwatchedShared

/// Schedules caption cue transitions ahead of time so the visible caption flips on the
/// exact cue boundary, independent of how coarsely playback time is sampled.
///
/// The custom (WebView) player only reports `currentTime` ~once per second, which is far
/// too coarse to flip captions on time (and would miss cues shorter than the sample
/// interval entirely). Instead of looking up the cue on every tick, we anchor to each
/// authoritative time update and schedule every upcoming flip locally, walking the cue
/// list cue-by-cue. Re-sync on any authoritative time event (periodic update, seek,
/// resume, speed change); cancel on pause.
@MainActor
final class CaptionScheduler {
    private var task: Task<Void, Never>?

    /// Tiny forward nudge so that, after sleeping to a boundary, the cue lookup lands
    /// strictly past it — avoids a zero-progress loop from floating-point equality.
    private static let epsilon: TimeInterval = 0.0001

    /// Re-anchor to an authoritative playback time and schedule all upcoming flips.
    func sync(player: PlayerManager, to playbackTime: TimeInterval) {
        task?.cancel()
        guard !player.captionCues.isEmpty else {
            Self.setCue(nil, on: player)
            return
        }
        let speed = player.playbackSpeed > 0 ? player.playbackSpeed : 1
        let lead = PlayerManager.captionLeadTime
        task = Task { [weak player] in
            var anchor = playbackTime
            while !Task.isCancelled {
                guard let player else { return }
                let displayTime = anchor + lead
                Self.setCue(player.findCaptionCue(at: displayTime), on: player)
                guard let boundary = player.nextCaptionBoundary(after: displayTime) else { return }
                // Flip when playback reaches the boundary, scaled by playback speed.
                let wait = (boundary - lead - anchor) / speed
                if wait > 0 {
                    try? await Task.sleep(for: .seconds(wait))
                }
                if Task.isCancelled { return }
                anchor = boundary - lead + Self.epsilon
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    private static func setCue(_ cue: CaptionCue?, on player: PlayerManager) {
        if cue?.startTime != player.currentCaptionCue?.startTime {
            player.currentCaptionCue = cue
        }
    }
}
#endif
