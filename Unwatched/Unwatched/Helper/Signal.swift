//
//  Event.swift
//  Unwatched
//

import TelemetryDeck
import SwiftUI
import SwiftData
import UnwatchedShared

struct Signal {
    static var isTestFlight: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }

    static func setup() {
        #if os(iOS)
        if !isTestFlight { return }
        if !(Const.analytics.bool ?? true) { return }
        // disabled
        #endif
    }

    static func signalBool(_ signalName: String, value: Bool) {
        if !isTestFlight { return }
        #if os(iOS)
        TelemetryDeck.signal(signalName, parameters: ["value": value ? "On" : "Off"])
        #endif
    }

    static func log(_ signalName: String, parameters: [String: String] = [:], throttle: SignalInterval? = nil) {
        #if os(iOS)
        if let throttle {
            if !UserDefaults.standard.shouldPerform(signalName, interval: throttle) {
                return
            }
        }
        if !(Const.analytics.bool ?? true) { return }
        Log.info("Signal: \(signalName)")
        if !isTestFlight { return }
        TelemetryDeck.signal(signalName, parameters: parameters)
        #endif
    }

    static func error(_ id: String) {
        if !(Const.analytics.bool ?? true) { return }
        if !isTestFlight { return }
        TelemetryDeck.errorOccurred(id: id)
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
