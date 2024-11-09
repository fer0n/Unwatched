//
//  AutoHideVM.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

@Observable class AutoHideVM {
    @ObservationIgnored var hideControlsTask: (Task<(), Never>)?

    private var keepVisibleDict = Set<String>()
    var positionLeft = false

    private var showControlsLocal = false {
        didSet {
            if showControlsLocal {
                hideControlsTask?.cancel()
                hideControlsTask = Task {
                    do {
                        try await Task.sleep(s: Const.controlsAutoHideDebounce)
                        withAnimation(.bouncy(duration: 1)) {
                            showControlsLocal = false
                        }
                    } catch { }
                }
            }
        }
    }

    var showControls: Bool {
        showControlsLocal || !keepVisibleDict.isEmpty
    }

    func reset() {
        showControlsLocal = false
        keepVisibleDict.removeAll()
    }

    func setShowControls(positionLeft: Bool? = nil) {
        if let positionLeft {
            self.positionLeft = positionLeft
        } else if !keepVisible && !showControls {
            // if not already shown, default to right side
            self.positionLeft = false
        }
        showControlsLocal = true
    }

    func setKeepVisible(_ value: Bool, _ source: String) {
        if value {
            keepVisibleDict.insert(source)
        } else {
            keepVisibleDict.remove(source)
        }
    }

    var keepVisible: Bool {
        get {
            !keepVisibleDict.isEmpty
        }
        set {
            setKeepVisible(newValue, "binding")
        }
    }
}
