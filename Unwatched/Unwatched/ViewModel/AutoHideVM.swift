//
//  AutoHideVM.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

@Observable class AutoHideVM {
    @ObservationIgnored var hideControlsTask: (Task<(), Never>)?

    private var keepVisibleCounter: Int = 0
    var positionLeft = false

    private var showControlsLocal = false {
        didSet {
            Task {
                if showControlsLocal {
                    hideControlsTask?.cancel()
                    hideControlsTask = Task {
                        do {
                            try await Task.sleep(s: Const.controlsAutoHideDebounce)
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
        showControlsLocal || keepVisibleCounter > 0
    }

    func reset() {
        showControlsLocal = false
        keepVisibleCounter = 0
    }

    func setShowControls(positionLeft: Bool? = nil) {
        withAnimation(.default.speed(3)) {
            if let positionLeft = positionLeft {
                self.positionLeft = positionLeft
            }
            showControlsLocal = true
        }
    }

    var keepVisible: Bool {
        get {
            keepVisibleCounter > 0
        }
        set {
            if newValue {
                keepVisibleCounter += 1
            } else {
                if keepVisibleCounter > 0 {
                    keepVisibleCounter -= 1
                }
            }
        }
    }
}
