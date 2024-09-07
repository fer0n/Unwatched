//
//  AutoHideVM.swift
//  Unwatched
//

import SwiftUI

@Observable class AutoHideVM {
    @ObservationIgnored var hideControlsTask: (Task<(), Never>)?

    var keepVisible = false
    var positionLeft = false

    private var showControlsLocal = false {
        didSet {
            Task {
                if showControlsLocal {
                    hideControlsTask?.cancel()
                    hideControlsTask = Task {
                        do {
                            try await Task.sleep(s: 3)
                            withAnimation {
                                showControlsLocal = false
                            }
                        } catch { }
                    }
                }
            }
        }
    }

    var showControls: Bool {
        showControlsLocal || keepVisible
    }

    func setShowControls(positionLeft: Bool? = nil) {
        withAnimation(.default.speed(3)) {
            if let positionLeft = positionLeft {
                self.positionLeft = positionLeft
            }
            showControlsLocal = true
        }
    }
}
