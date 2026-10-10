//
//  ChapterAutomationProgress.swift
//  Unwatched
//

import Foundation
import UnwatchedShared

/// Inferred from the intents the chapter shortcut calls; the model's wait in between creeps.
@MainActor
@Observable
final class ChapterAutomationProgress: ProgressSweeping {
    static let shared = ChapterAutomationProgress()

    private(set) var youtubeId: String?
    private var stage = Stage.idle
    var sweepProgress: Double = 0
    var isFadingOutProgress = false

    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var creepTask: Task<Void, Never>?

    private enum Stage {
        case idle, notified, running
    }

    private static let pickupTimeout: Duration = .seconds(60)
    private static let runTimeout: Duration = .seconds(5 * 60)

    var isRunning: Bool { stage != .idle }

    func notified(_ youtubeId: String) {
        self.youtubeId = youtubeId
        stage = .notified
        isFadingOutProgress = false
        sweepProgress = 0.15
        creepTask?.cancel()
        scheduleTimeout(Self.pickupTimeout)
    }

    func shortcutRead(_ youtubeId: String) {
        guard stage != .idle, youtubeId == self.youtubeId else { return }
        if stage == .notified {
            stage = .running
            sweepProgress = max(sweepProgress, 0.35)
            startCreep()
        }
        scheduleTimeout(Self.runTimeout)
    }

    func chaptersSet(_ youtubeId: String) {
        guard stage != .idle, youtubeId == self.youtubeId else { return }
        reset()
        Task { await finishProgress() }
    }

    private func startCreep() {
        creepTask?.cancel()
        creepTask = Task {
            while (try? await Task.sleep(for: .seconds(1))) != nil {
                sweepProgress += (0.9 - sweepProgress) * 0.05
            }
        }
    }

    private func scheduleTimeout(_ duration: Duration) {
        timeoutTask?.cancel()
        timeoutTask = Task {
            guard (try? await Task.sleep(for: duration)) != nil else { return }
            Log.info("ChapterAutomationProgress: no word from the shortcut for \(youtubeId ?? "-")")
            reset()
            cancelProgress()
        }
    }

    private func reset() {
        stage = .idle
        timeoutTask?.cancel()
        creepTask?.cancel()
    }
}
