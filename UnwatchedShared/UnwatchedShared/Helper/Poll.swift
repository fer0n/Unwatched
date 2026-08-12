//
//  Poll.swift
//  UnwatchedShared
//

import Foundation

public enum Poll {
    public enum Step {
        case done
        case retry
        case abort
    }

    /// Runs `check` until it reports `.done` (true), or `.abort`/cancellation/`timeout` (false).
    @MainActor
    public static func until(
        timeout: Double,
        step: Double = 0.15,
        _ check: () async -> Step
    ) async -> Bool {
        let ticks = max(1, Int((timeout / step).rounded()))
        for _ in 0..<ticks {
            if Task.isCancelled {
                return false
            }
            switch await check() {
            case .done: return true
            case .abort: return false
            case .retry: break
            }
            try? await Task.sleep(for: .seconds(step))
        }
        return false
    }
}
