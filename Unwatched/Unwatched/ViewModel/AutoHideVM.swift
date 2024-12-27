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
        showControlsLocal || !keepVisibleDict.isEmpty
    }

    func reset() {
        showControlsLocal = false
        keepVisibleDict.removeAll()
    }

    func setShowControls(positionLeft: Bool? = nil) {
        withAnimation(.default.speed(3)) {
            if let positionLeft = positionLeft {
                self.positionLeft = positionLeft
            }
            showControlsLocal = true
        }
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
