//
//  AutoHideVM.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

@Observable class AutoHideVM {
    @MainActor
    static let shared: AutoHideVM = {
        AutoHideVM()
    }()

    @ObservationIgnored var hideControlsTask: (Task<(), Never>)?

    private var keepVisibleDict = Set<String>()
    var positionLeft = false

    init() {}

    @MainActor
    private var showControlsLocal = false

    /// Restarts the auto-hide timeout without touching observable state: repeated
    /// interactions extend the timeout without invalidating everything observing `showControls`.
    @MainActor
    private func restartHideControlsTask() {
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

    @MainActor
    var showControls: Bool {
        showControlsLocal || !keepVisibleDict.isEmpty
    }

    @MainActor
    func reset() {
        showControlsLocal = false
        keepVisibleDict.removeAll()
    }

    @MainActor
    func setShowControls() {
        if !showControlsLocal {
            showControlsLocal = true
        }
        restartHideControlsTask()
    }

    @MainActor
    func handlePlayerInteraction() {
        #if os(visionOS)
        let value = getValue("visionOSInteraction")
        setKeepVisible(!value, "visionOSInteraction")
        #else
        setShowControls()
        #endif
    }

    func setKeepVisible(_ value: Bool, _ source: String) {
        guard keepVisibleDict.contains(source) != value else {
            return
        }
        if value {
            keepVisibleDict.insert(source)
        } else {
            keepVisibleDict.remove(source)
        }
    }

    func getValue(_ source: String) -> Bool {
        keepVisibleDict.contains(source)
    }

    var keepVisible: Bool {
        get {
            !keepVisibleDict.isEmpty
        }
        set {
            setKeepVisible(newValue, "binding")
        }
    }

    var showDescription: Bool {
        get {
            getValue("description")
        }
        set {
            setKeepVisible(newValue, "description")
        }
    }
}
