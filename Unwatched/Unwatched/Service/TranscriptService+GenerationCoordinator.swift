//
//  TranscriptService+GenerationCoordinator.swift
//  Unwatched
//

import Foundation
import Observation
import UnwatchedShared

extension TranscriptService {
    /// The one running generation, visible to any transcript UI, e.g. one started by a Shortcut.
    @MainActor @Observable final class GenerationCoordinator {
        static let shared = GenerationCoordinator()
        private init() {}

        private(set) var youtubeId: String?
        private(set) var progress: Double = 0
        private(set) var isGenerating = false {
            didSet { TranscriptionActivity.shared.youtubeId = isGenerating ? youtubeId : nil }
        }
        private(set) var error: String?
        private(set) var wasCancelled = false

        /// Bumped on finish, so an open transcript view reloads.
        private(set) var finishedYoutubeId: String?
        private(set) var finishedVersion = 0

        @ObservationIgnored
        private var activeTask: Task<[TranscriptEntry], Error>?

        @discardableResult
        func generate(for video: Video, force: Bool = false) -> Task<[TranscriptEntry], Error> {
            if isGenerating, youtubeId == video.youtubeId, let activeTask {
                return activeTask
            }

            let id = video.youtubeId
            youtubeId = id
            progress = 0
            error = nil
            wasCancelled = false
            isGenerating = true

            let task = TranscriptService.generateTranscript(for: video, force: force) { [weak self] fraction in
                Task { @MainActor in
                    guard self?.youtubeId == id else { return }
                    self?.progress = fraction
                }
            }
            activeTask = task

            Task { [weak self] in
                do {
                    _ = try await task.value
                    Signal.generationResult("transcript", "success")
                } catch is CancellationError {
                } catch {
                    Signal.generationResult("transcript", "failed")
                    if self?.youtubeId == id {
                        self?.error = error.localizedDescription
                    }
                }
                guard let self, self.youtubeId == id else { return }
                self.isGenerating = false
                self.activeTask = nil
                self.finishedYoutubeId = id
                self.finishedVersion += 1
            }

            return task
        }

        func cancel(youtubeId id: String) {
            guard isGenerating, youtubeId == id, let activeTask else { return }
            Log.info("cancelling the transcript generation for \(id)")
            wasCancelled = true
            activeTask.cancel()
        }
    }
}
