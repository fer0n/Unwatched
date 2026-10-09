//
//  ChapterAutomation+BackgroundTask.swift
//  Unwatched
//

#if os(iOS)
@preconcurrency import BackgroundTasks
import os
import UnwatchedShared

extension ChapterAutomation {
    private nonisolated static let backgroundTaskId = "com.pentlandFirth.Unwatched.autoTranscribe"

    static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskId, using: .main) { task in
            MainActor.assumeIsolated {
                handleBackgroundTask(task)
            }
        }
    }

    nonisolated static func submitBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: backgroundTaskId)
        request.requiresExternalPower = true
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Log.info("ChapterAutomation: couldn't request background task: \(error)")
        }
    }

    static func updateBackgroundTask() {
        if hasPendingWork {
            submitBackgroundTask()
        } else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskId)
        }
    }

    private static func handleBackgroundTask(_ task: BGTask) {
        Log.info("ChapterAutomation: background task started")
        let isCompleted = OSAllocatedUnfairLock(initialState: false)
        let complete: @Sendable (Bool) -> Void = { success in
            let isFirst = isCompleted.withLock { done in
                defer { done = true }
                return !done
            }
            if isFirst {
                task.setTaskCompleted(success: success)
            }
        }
        task.expirationHandler = {
            Log.info("ChapterAutomation: background task expired")
            submitBackgroundTask()
            complete(false)
        }
        let run = runNow(whileCharging: true)
        Task {
            await run.value
            Log.info("ChapterAutomation: background task finished, work left: \(hasPendingWork)")
            complete(true)
        }
    }
}
#endif
