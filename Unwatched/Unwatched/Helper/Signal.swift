//
//  Event.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct Signal {
    static func setup() {
        // Remote analytics are disabled; signals are only written to the local log.
    }

    static func signalBool(_ signalName: String, value: Bool) {
        log(signalName, parameters: ["value": value ? "On" : "Off"])
    }

    static func log(_ signalName: String, parameters: [String: String] = [:], throttle: SignalInterval? = nil) {
        #if os(iOS)
        if let throttle {
            if !UserDefaults.standard.shouldPerform(signalName, interval: throttle) {
                return
            }
        }
        if !(Const.analytics.bool ?? true) { return }
        Log.info("Signal: \(signalName) \(parameters)")
        #endif
    }

    static func error(_ id: String) {
        if !(Const.analytics.bool ?? true) { return }
        Log.error("Signal error: \(id)")
    }
}

extension View {
    func signalToggle(_ name: String, isOn: Bool) -> some View {
        self.onChange(of: isOn) {
            #if os(iOS)
            Signal.log(name, parameters: ["value": isOn ? "On" : "Off"])
            #endif
        }
    }
}
