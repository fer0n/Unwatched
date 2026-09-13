//
//  ProgressSweeping.swift
//  Unwatched
//

import Foundation

/// A view model whose work fills a button's progress sweep.
@MainActor
protocol ProgressSweeping: AnyObject {
    var sweepProgress: Double { get set }
    var isFadingOutProgress: Bool { get set }
}

extension ProgressSweeping {
    /// Runs the sweep out to the end and starts fading it, so the button settling reads as one motion.
    func finishProgress() async {
        sweepProgress = 1
        try? await Task.sleep(for: .seconds(0.25))
        isFadingOutProgress = true
        try? await Task.sleep(for: .seconds(0.15))
    }

    /// Fades away a sweep that ended without finishing, so a failed run doesn't leave the button
    /// filled to wherever it got to.
    func cancelProgress() {
        guard sweepProgress > 0 else { return }
        isFadingOutProgress = true
        sweepProgress = 0
    }
}
